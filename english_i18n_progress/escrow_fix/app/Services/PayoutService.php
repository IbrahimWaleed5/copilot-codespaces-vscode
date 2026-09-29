<?php

namespace App\Services;

use App\Contracts\BankGateway;
use App\Models\EngineerEarning;
use App\Models\Office;
use App\Models\PaymentGatewayTransaction;
use App\Models\PayoutAccount;
use App\Models\ProjectEngineerEarning;
use App\Models\ProjectOfficeEarning;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class PayoutService
{
    public function __construct(
        private readonly BankGateway $gateway,
        private readonly ProductionNotificationService $notifications,
        private readonly KycService $kyc,
    ) {}

    public function requestEngineerPayout(ProjectEngineerEarning $earning, int $adminId): PaymentGatewayTransaction
    {
        return $this->requestProject($earning, 'engineer_amount', 'engineer', $adminId);
    }

    public function requestOfficePayout(ProjectOfficeEarning $earning, int $adminId): PaymentGatewayTransaction
    {
        return $this->requestProject($earning, 'office_amount', 'office', $adminId);
    }

    public function requestConsultationEngineerPayout(EngineerEarning $earning, int $adminId): PaymentGatewayTransaction
    {
        return DB::transaction(function () use ($earning, $adminId) {
            /** @var EngineerEarning $locked */
            $locked = EngineerEarning::query()->whereKey($earning->getKey())->lockForUpdate()->firstOrFail();
            $this->assertPending($locked);
            $this->assertNotHeld($locked);

            $locked->loadMissing(['payment', 'consultation', 'engineer']);
            if (! $locked->payment || $locked->payment->status !== 'completed') {
                throw new RuntimeException('دفعة الاستشارة غير مؤكدة بعد؛ لا يمكن صرف المستحق.');
            }
            if ($locked->consultation?->assigned_office_id !== null) {
                throw new RuntimeException('هذا المستحق تابع لمكتب هندسي ويجب إدارته من مالية المكتب.');
            }
            // Paid consultations use the wallet escrow: the engineer share stays held until the customer
            // approves the final file, then it is released to the engineer wallet automatically.
            // A manual bank payout here would pay before approval and then pay again on release.
            if (\Illuminate\Support\Facades\Schema::hasTable('consultation_wallet_settlements')
                && DB::table('consultation_wallet_settlements')
                    ->where('payment_id', $locked->payment_id)
                    ->whereIn('status', ['held', 'released'])
                    ->exists()) {
                throw new RuntimeException('مستحق هذه الاستشارة يُدار تلقائيًا: يبقى محجوزًا حتى اعتماد العميل ثم يُحوّل لمحفظة المهندس، ويسحبه المهندس من المحفظة.');
            }

            $beneficiary = $locked->engineer;
            if ($beneficiary instanceof User) $this->kyc->assertEngineerPayoutAllowed($beneficiary);
            $account = $this->verifiedUserAccount((int) $locked->engineer_id);

            return $this->dispatch(
                earning: $locked,
                account: $account,
                beneficiary: $beneficiary,
                amount: (float) $locked->engineer_amount,
                gross: (float) $locked->payment_amount,
                platform: (float) $locked->platform_amount,
                adminId: $adminId,
                metadata: [
                    'earning_type' => class_basename($locked),
                    'earning_id' => $locked->getKey(),
                    'consultation_id' => $locked->consultation_id,
                    'payment_id' => $locked->payment_id,
                ],
            );
        });
    }

    private function requestProject(Model $earning, string $amountColumn, string $kind, int $adminId): PaymentGatewayTransaction
    {
        return DB::transaction(function () use ($earning, $amountColumn, $kind, $adminId) {
            $locked = $earning::query()->whereKey($earning->getKey())->lockForUpdate()->firstOrFail();
            $this->assertPending($locked);
            $this->assertNotHeld($locked);
            if (! $locked->payout_ready_at) throw new RuntimeException('لم يعتمد العميل اكتمال العمل بعد؛ المستحق غير جاهز للصرف.');

            $locked->loadMissing(['installment.escrowTransaction']);
            $installment = $locked->installment;
            if (! $installment || ! in_array($installment->status, ['paid', 'escrow_funded'], true)) {
                throw new RuntimeException('دفعة العميل غير مؤكدة بعد؛ لا يمكن صرف المستحق.');
            }
            if (! $installment->gateway_verified_at && ! $installment->confirmed_at) {
                throw new RuntimeException('لم يتم التحقق من وصول دفعة العميل بعد.');
            }

            if ($kind === 'engineer') {
                $beneficiary = $locked->engineer()->first();
                if ($beneficiary instanceof User) $this->kyc->assertEngineerPayoutAllowed($beneficiary);
                $account = $this->verifiedUserAccount((int) $locked->engineer_id);
            } else {
                $beneficiary = $locked->office()->first();
                if ($beneficiary instanceof Office) $this->kyc->assertOfficePayoutAllowed($beneficiary);
                $account = $this->verifiedOfficeAccount((int) $locked->office_id);
            }

            return $this->dispatch(
                earning: $locked,
                account: $account,
                beneficiary: $beneficiary,
                amount: (float) $locked->{$amountColumn},
                gross: (float) ($locked->payment_amount ?? $locked->{$amountColumn}),
                platform: (float) ($locked->platform_amount ?? 0),
                adminId: $adminId,
                metadata: [
                    'earning_type' => class_basename($locked),
                    'earning_id' => $locked->getKey(),
                    'project_id' => $locked->project_id,
                    'installment_id' => $locked->installment_id,
                ],
            );
        });
    }

    private function dispatch(
        Model $earning,
        PayoutAccount $account,
        ?Model $beneficiary,
        float $amount,
        float $gross,
        float $platform,
        int $adminId,
        array $metadata,
    ): PaymentGatewayTransaction {
        if ($amount <= 0) throw new RuntimeException('قيمة المستحق يجب أن تكون أكبر من صفر.');

        $securityHolds = app(\App\Services\AccountSecurityHoldService::class);
        if ($beneficiary instanceof User) {
            $securityHolds->assertPayoutAllowed($beneficiary);
        } elseif ($beneficiary instanceof Office) {
            $beneficiary->loadMissing('owner');
            if ($beneficiary->owner instanceof User) $securityHolds->assertPayoutAllowed($beneficiary->owner);
        }

        $reference = 'PO-' . now()->format('YmdHis') . '-' . Str::upper(Str::random(8));

        $transaction = PaymentGatewayTransaction::create([
            'gateway' => ($account->account_type ?: 'bank'),
            'direction' => 'payout',
            'reference' => $reference,
            'payable_type' => $earning::class,
            'payable_id' => $earning->getKey(),
            'beneficiary_type' => $beneficiary?->getMorphClass(),
            'beneficiary_id' => $beneficiary?->getKey(),
            'gross_amount' => $gross,
            'platform_amount' => $platform,
            'net_amount' => $amount,
            'currency' => $account->currency ?: 'ILS',
            'status' => 'processing',
            'initiated_by' => $adminId,
        ]);

        $earning->forceFill([
            'status' => 'processing',
            'payout_reference' => $reference,
            'payout_requested_at' => now(),
            'payout_failure_reason' => null,
        ])->save();

        if (in_array($account->account_type, ['paypal','visa'], true)) {
            $transaction->update([
                'gateway' => $account->account_type,
                'provider_payload' => [
                    'account_type' => $account->account_type,
                    'paypal_email' => $account->account_type === 'paypal' ? $account->paypal_email : null,
                    'card_brand' => $account->account_type === 'visa' ? $account->card_brand : null,
                    'card_last4' => $account->account_type === 'visa' ? $account->card_last4 : null,
                    'recipient_token_present' => $account->account_type === 'visa' ? filled($account->provider_recipient_token) : null,
                    'manual_confirmation_required' => true,
                ],
            ]);
            $fresh = $transaction->fresh();
            $this->notifyBeneficiary($fresh, 'طلب صرف قيد التنفيذ', 'تم إنشاء طلب صرف مستحقاتك وهو بانتظار تأكيد التحويل.', 'payout_processing');
            return $fresh;
        }

        try {
            $result = $this->gateway->createPayout(
                $reference,
                $amount,
                $transaction->currency,
                $account,
                $metadata,
            );
        } catch (\Throwable $e) {
            $transaction->update([
                'status' => 'failed',
                'failure_reason' => $e->getMessage(),
                'processed_at' => now(),
            ]);
            $earning->forceFill([
                'status' => 'pending',
                'payout_failure_reason' => $e->getMessage(),
            ])->save();
            $this->notifyBeneficiary($transaction->fresh(), 'تعذر صرف المستحقات', 'تعذر إرسال عملية التحويل إلى مزود الدفع. بقي المستحق في قائمة الانتظار لإعادة المحاولة.', 'payout_failed');
            throw $e;
        }

        $status = $this->normalizeStatus($result['status'] ?? null);
        $providerId = $result['provider_transaction_id'] ?? null;
        $transaction->update([
            'provider_transaction_id' => $providerId ?: null,
            'status' => $status,
            'provider_payload' => $result['payload'] ?? null,
        ]);
        $earning->forceFill(['payout_provider_id' => $providerId ?: null])->save();

        if ($status === 'paid') {
            $this->confirmPaid($transaction);
        } elseif ($status === 'failed') {
            $this->restorePending($transaction);
        } else {
            $this->notifyBeneficiary($transaction->fresh(), 'طلب صرف قيد التنفيذ', 'تم إرسال طلب صرف مستحقاتك إلى مزود الدفع.', 'payout_processing');
        }
        return $transaction->fresh();
    }

    private function verifiedUserAccount(int $userId): PayoutAccount
    {
        $account = PayoutAccount::query()->where('user_id', $userId)->where('is_default', true)->first();
        return $this->assertVerifiedAccount($account);
    }

    private function verifiedOfficeAccount(int $officeId): PayoutAccount
    {
        $account = PayoutAccount::query()->where('office_id', $officeId)->where('is_default', true)->first();
        return $this->assertVerifiedAccount($account);
    }

    private function assertVerifiedAccount(?PayoutAccount $account): PayoutAccount
    {
        if (! $account) throw new RuntimeException('لا يوجد حساب استلام افتراضي للمستفيد.');
        if (! $account->is_verified || ($account->verification_status && $account->verification_status !== 'verified')) {
            throw new RuntimeException('حساب استلام المستفيد غير موثّق.');
        }
        return $account;
    }

    private function assertPending(Model $earning): void
    {
        if ($earning->status === 'paid') throw new RuntimeException('تم دفع هذا المستحق مسبقًا.');
        if ($earning->status === 'processing') throw new RuntimeException('هذا المستحق قيد التحويل البنكي بالفعل.');
        if ($earning->status !== 'pending') throw new RuntimeException('حالة المستحق لا تسمح بالصرف.');
    }

    private function assertNotHeld(Model $earning): void
    {
        if ($earning->payout_hold_at) {
            throw new RuntimeException($earning->payout_hold_reason ?: 'المستحق محجوز بسبب نزاع مالي مفتوح.');
        }
    }

    public function confirmExternalPayout(PaymentGatewayTransaction $transaction, int $adminId, string $providerReference): PaymentGatewayTransaction
    {
        return DB::transaction(function () use ($transaction, $adminId, $providerReference) {
            $locked = PaymentGatewayTransaction::query()->whereKey($transaction->id)->lockForUpdate()->firstOrFail();
            if ($locked->direction !== 'payout' || ! in_array($locked->gateway, ['paypal', 'visa'], true)) {
                throw new RuntimeException('هذه العملية ليست تحويل PayPal/Visa قابلًا للتأكيد اليدوي.');
            }
            if ($locked->status === 'paid') return $locked;
            if ($locked->status !== 'processing') throw new RuntimeException('حالة عملية الصرف لا تسمح بالتأكيد.');
            $payload = is_array($locked->provider_payload) ? $locked->provider_payload : [];
            $payload['provider_reference'] = trim($providerReference);
            $payload['confirmed_by'] = $adminId;
            $payload['confirmed_at'] = now()->toIso8601String();
            $locked->update([
                'status' => 'paid',
                'provider_transaction_id' => trim($providerReference),
                'provider_payload' => $payload,
                'verified_at' => now(),
                'processed_at' => now(),
                'failure_reason' => null,
            ]);
            $this->confirmPaid($locked);
            return $locked->fresh();
        });
    }

    public function applyProviderUpdate(PaymentGatewayTransaction $transaction, string $providerStatus, array $payload = []): PaymentGatewayTransaction
    {
        $status = $this->normalizeStatus($providerStatus);
        return DB::transaction(function () use ($transaction, $status, $payload) {
            $locked = PaymentGatewayTransaction::query()->whereKey($transaction->id)->lockForUpdate()->firstOrFail();
            if ($locked->status === 'paid') return $locked;

            $locked->update([
                'status' => $status,
                'provider_payload' => $payload ?: $locked->provider_payload,
                'verified_at' => in_array($status, ['paid', 'failed'], true) ? now() : $locked->verified_at,
                'processed_at' => in_array($status, ['paid', 'failed'], true) ? now() : $locked->processed_at,
                'failure_reason' => $status === 'failed'
                    ? (string) ($payload['failure_reason'] ?? $payload['message'] ?? 'رفض البنك عملية التحويل.')
                    : null,
            ]);

            if ($status === 'paid') $this->confirmPaid($locked);
            if ($status === 'failed') $this->restorePending($locked);
            return $locked->fresh();
        });
    }

    private function confirmPaid(PaymentGatewayTransaction $transaction): void
    {
        $earning = $transaction->payable;
        if (! $earning || $earning->status === 'paid') return;
        $earning->forceFill([
            'status' => 'paid',
            'paid_at' => now(),
            'paid_by' => $transaction->initiated_by,
            'payout_verified_at' => now(),
            'payout_failure_reason' => null,
        ])->save();
        $this->notifyBeneficiary($transaction->fresh(), 'تم صرف المستحقات', 'تم تأكيد تحويل ' . number_format((float) $transaction->net_amount, 2) . ' ' . $transaction->currency . ' إلى حساب الاستلام الخاص بك.', 'payout_paid', true);
    }

    private function restorePending(PaymentGatewayTransaction $transaction): void
    {
        $earning = $transaction->payable;
        if (! $earning || $earning->status === 'paid') return;
        $earning->forceFill([
            'status' => 'pending',
            'payout_failure_reason' => $transaction->failure_reason,
        ])->save();
        $this->notifyBeneficiary($transaction->fresh(), 'تعذر صرف المستحقات', 'فشلت عملية التحويل وتمت إعادة المستحق إلى قائمة الانتظار لإعادة المحاولة.', 'payout_failed');
    }

    private function notifyBeneficiary(PaymentGatewayTransaction $transaction, string $title, string $message, string $type, bool $mail = false): void
    {
        $beneficiary = $transaction->beneficiary;
        $user = $beneficiary instanceof User
            ? $beneficiary
            : ($beneficiary instanceof Office ? $beneficiary->owner : null);
        if (! $user instanceof User) return;

        if ($type === 'payout_paid') {
            app(\App\Services\CustomerLifecycleMailService::class)->send($user, 'finance.payout_transferred', [
                'message'=>$message,
                'action_url'=>url('/financial/payout-queue'),
                'action_label'=>'فتح المستحقات',
            ]);
            // منع البريد القديم حتى لا يصل نفس الحدث مرتين؛ يبقى إشعار قاعدة البيانات كما هو.
            $mail = false;
        }

        $this->notifications->send(
            $user,
            $title,
            $message,
            '/financial/payout-queue',
            $type,
            [
                'payout_transaction_id' => $transaction->id,
                'reference' => $transaction->reference,
                'amount' => (float) $transaction->net_amount,
                'currency' => $transaction->currency,
            ],
            $mail,
        );
    }

    private function normalizeStatus(?string $status): string
    {
        return match (strtolower((string) $status)) {
            'paid', 'completed', 'success', 'succeeded', 'settled' => 'paid',
            'failed', 'rejected', 'declined', 'cancelled', 'canceled' => 'failed',
            default => 'processing',
        };
    }
}
