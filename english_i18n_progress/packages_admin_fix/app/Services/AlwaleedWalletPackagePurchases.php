<?php
namespace App\Services;

use App\Models\{AiOrder,AiPlan,EngineerCloudPlan,EngineerCloudPlanOrder,Office,OfficeSubscription,SaasPlan,User};
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** No parallel subscription: existing plan activation/services remain authoritative. */
class AlwaleedWalletPackagePurchases
{
    public function __construct(private readonly AlwaleedWalletService $wallet,
        private readonly KycService $kyc) {}

    private function plan(User $user, string $type, int $id, string $cycle, ?string $coupon): array
    {
        abort_unless($user->status==='active' && in_array($type,['engineer','office','ai'],true),403);
        if ($type==='engineer') {
            abort_unless($user->role==='engineer',422,'أكمل طلب توثيق المهندس من مسار المتطلبات قبل شراء الباقة.');
            abort_unless($cycle==='monthly',422,'هذه باقة مهندس شهرية.');
            abort_unless($this->kyc->isVerified($user),422,'أكمل KYC والتحقق المهني قبل شراء باقة المهندس.');
            $plan=EngineerCloudPlan::query()->where('is_active',true)->findOrFail($id);
            $office=null;
            $amount=(float)$plan->monthly_price;
            $offer=filled($coupon) ? app(UniversalPackageCouponService::class)->quote($coupon,$user,'engineer',$plan->slug,$amount,$plan->currency) : null;
        } elseif ($type==='office') {
            abort_unless($user->role==='office_owner',422,'أكمل متطلبات تأسيس/توثيق المكتب أولًا.');
            abort_unless(in_array($cycle,['monthly','yearly'],true),422);
            $office=Office::query()->where('owner_user_id',$user->id)->where('status','active')->firstOrFail();
            abort_unless($this->kyc->isVerified($user) && $this->kyc->isVerified($office),422,'يجب اعتماد توثيق صاحب المكتب والمكتب.');
            $plan=SaasPlan::query()->where('is_active',true)->findOrFail($id);
            abort_unless(!$plan->is_custom && $plan->monthly_price!==null,422,'الباقة المخصصة تحتاج عرض سعر معتمدًا من الإدارة.');
            abort_unless(!$office->subscriptions()->where('status','under_review')->exists(),409,'هناك طلب اشتراك قيد المراجعة.');
            $amount=(float)$plan->priceForCycle($cycle);
            $offer=filled($coupon) ? app(SaasCommercialService::class)->quoteCoupon($coupon,$user,$office,$plan,$amount,$plan->currency) : null;
        } else {
            // Same rule as the packages page: the admin already has unlimited AI.
            abort_unless($user->role!=='admin',422,'حساب المدير لديه صلاحية AI غير محدودة بحسب إعدادات المنصة الحالية؛ لا يلزم شراء هذه الباقة من محفظتك الشخصية.');
            abort_unless($cycle==='monthly',422,'باقة AI شهرية.');
            $office=null;
            $plan=AiPlan::query()->where('is_active',true)->where('scope','user')->findOrFail($id);
            abort_unless($plan->slug!=='free',422,'باقة AI Free لا تتطلب شراءً؛ استخدم الاشتراك المجاني الحالي.');
            $amount=(float)$plan->monthly_price;
            $offer=filled($coupon) ? app(UniversalPackageCouponService::class)->quote($coupon,$user,'ai',$plan->slug,$amount,$plan->currency) : null;
        }
        abort_unless(!app(CurrentPackageStatus::class)->isCurrent($user, $type, $id),
            409, 'أنت داخل الخطة بالفعل؛ يمكنك اختيار باقة أخرى للترقية.');
        $amount = $offer ? (float)$offer['final_amount'] : $amount;
        $currency=strtoupper((string)$plan->currency);
        abort_unless(isset(AlwaleedWalletService::CURRENCIES[$currency]),422,'عملة الباقة غير مدعومة في المحفظة.');
        abort_unless($amount>0,422,'الباقة مجانية؛ استخدم مسار الاشتراك المجاني الحالي دون سحب من المحفظة.');
        $this->kyc->assertPaymentAllowed($user,$amount,$currency,'wallet_'.$type.'_plan');
        $minor=$this->wallet->decimalToMinor(number_format($amount,AlwaleedWalletService::CURRENCIES[$currency],'.',''),$currency);
        return compact('plan','office','offer','amount','currency','minor','cycle','type');
    }

    public function quote(User $user,string $type,int $id,string $cycle,?string $coupon): array
    {
        $p=$this->plan($user,$type,$id,$cycle,$coupon);
        $autoFx = app(WalletPackageAutoFx::class)->preview($user, $p['currency'], $p['minor']);
        return ['type'=>$type,'plan_id'=>$p['plan']->id,'plan_name'=>$p['plan']->name,
            'cycle'=>$cycle,'amount'=>$this->wallet->money($p['minor'],$p['currency']),
            'currency'=>$p['currency'],'coupon_code'=>$coupon,
            'wallet_available'=>$this->wallet->balances($user->id)[$p['currency']]['available'],
            'wallet_sufficient'=>$autoFx['available'],'auto_fx'=>$autoFx];
    }

    public function purchase(User $user,string $type,int $id,string $cycle,?string $coupon,
        string $expectedAmount,string $expectedCurrency,string $requestKey,
        bool $autoFxConfirmed = false, ?string $expectedFxDigest = null): array
    {
        $this->wallet->assertLive();
        abort_unless((bool)preg_match('/^[a-zA-Z0-9_-]{16,80}$/D',$requestKey),422,'رقم عملية الشراء غير صالح.');
        return DB::transaction(function()use($user,$type,$id,$cycle,$coupon,$expectedAmount,$expectedCurrency,$requestKey,$autoFxConfirmed,$expectedFxDigest){
            // Serialize checkout for this user; ledger move() additionally locks per-currency accounts.
            DB::table('users')->where('id', $user->id)->lockForUpdate()->first();
            $old=DB::table('wallet_package_purchases')->where('user_id',$user->id)->where('request_key',$requestKey)
                ->lockForUpdate()->first();
            if($old){
                abort_unless($old->status==='completed' && $old->type===$type && (int)$old->plan_id===$id,409,'تعارض مفتاح الطلب.');
                return ['id'=>$old->id,'status'=>'completed','already_completed'=>true];
            }
            $p=$this->plan($user,$type,$id,$cycle,$coupon);
            abort_unless($expectedCurrency===$p['currency'] && $this->wallet->decimalToMinor($expectedAmount,$p['currency'])===$p['minor'],409,
                'تغير سعر الباقة؛ راجع السعر الحالي ثم أكد الطلب مجددًا.');
            $autoFx = app(WalletPackageAutoFx::class)->preview($user, $p['currency'], $p['minor']);
            if (!$autoFx['available']) {
                abort_unless($autoFxConfirmed && $autoFx['enabled'] && $autoFx['possible'] &&
                    $expectedFxDigest !== null && hash_equals((string)$autoFx['digest'], $expectedFxDigest),
                    409, 'رصيد عملة الباقة غير كافٍ أو تغير سعر الصرف/الرصيد؛ أعد عرض السعر وأكّد التحويل من جديد.');
            }
            $idPurchase=DB::table('wallet_package_purchases')->insertGetId([
                'user_id'=>$user->id,'request_key'=>$requestKey,'type'=>$type,'plan_id'=>$id,
                'office_id'=>$p['office']?->id,'cycle'=>$cycle,'currency'=>$p['currency'],'amount_minor'=>$p['minor'],
                'status'=>'pending','created_at'=>now(),'updated_at'=>now(),
            ]);
            if (!$autoFx['available']) {
                app(WalletPackageAutoFx::class)->apply($user, $idPurchase, $p['currency'], $autoFx);
            }
            $journal=$this->wallet->move('wallet-plan:'.$idPurchase,'package_payment',$user->id,'available',
                0,'service_clearing',$p['currency'],$p['minor'],$user->id,'wallet_package_purchase',$idPurchase);
            $plan=$p['plan'];$offer=$p['offer'];
            if($type==='engineer'){
                $order=EngineerCloudPlanOrder::query()->create([
                    'order_number'=>'WPL-'.$idPurchase,'user_id'=>$user->id,'engineer_cloud_plan_id'=>$plan->id,
                    'amount'=>$p['amount'],'currency'=>$p['currency'],'payment_reference'=>'WALLET-'.$journal->id,
                    'status'=>'approved','reviewed_by'=>$user->id,'reviewed_at'=>now(),
                    'coupon_code'=>$offer?($offer['coupon']->code):null,
                    'original_amount'=>$offer?($offer['original_amount']):$plan->monthly_price,
                    'discount_amount'=>$offer?($offer['discount_amount']):0,
                ]);
                if($offer) app(UniversalPackageCouponService::class)->redeem($offer,$user,$order->order_number);
                app(EngineerCloudPlanService::class)->activate($user,$plan,null);
                $subscriptionId=$order->id;
            }elseif($type==='office'){
                $office=$p['office'];
                $subscription=OfficeSubscription::query()->create([
                    'office_id'=>$office->id,'saas_plan_id'=>$plan->id,
                    'saas_coupon_id'=>$offer?($offer['coupon']->id):null,'amount'=>$p['amount'],
                    'original_amount'=>$offer?($offer['original_amount']):$plan->priceForCycle($cycle),
                    'discount_amount'=>$offer?($offer['discount_amount']):0,
                    'currency'=>$p['currency'],'billing_cycle'=>$cycle,'duration_value'=>1,
                    'duration_unit'=>$cycle==='yearly'?'year':'month','status'=>'under_review',
                    'payment_method'=>'wallet','payment_reference'=>'WALLET-'.$journal->id,
                    'paid_at'=>now(),'requested_at'=>now(),
                ]);
                if($offer)app(SaasCommercialService::class)->redeem($offer['coupon'],$user,$office,
                    (string)$subscription->payment_reference,(float)$offer['discount_amount'],$p['currency']);
                app(SaasSubscriptionService::class)->approvePayment($subscription,1,$cycle==='yearly'?'year':'month',null,
                    'دفعت قيمة الاشتراك من محفظة الوليد برقم القيد '.$journal->id);
                $subscriptionId=$subscription->id;
            }else{
                // Reuse the platform's AI subscription and AI wallet models, not a new AI balance.
                // An internal wallet transfer is NOT a second incoming bank/gateway payment.
                $order=AiOrder::query()->create([
                    'reference_number'=>'WAI-'.$idPurchase, 'user_id'=>$user->id,
                    'purchase_type'=>'plan','ai_plan_id'=>$plan->id,'status'=>'paid',
                    'amount'=>$p['amount'],'currency'=>$p['currency'],
                    'payment_method'=>'wallet','gateway'=>'internal_wallet',
                    'payment_reference'=>'WALLET-'.$journal->id,'paid_at'=>now(),
                    'approved_at'=>now(),'metadata'=>['wallet_journal_id'=>$journal->id],
                    'coupon_code'=>$offer?($offer['coupon']->code):null,
                    'original_amount'=>$offer?($offer['original_amount']):$plan->monthly_price,
                    'discount_amount'=>$offer?($offer['discount_amount']):0,
                ]);
                $credits=app(AiCreditService::class);
                $credits->activatePlan($credits->syncUserWallet($user),$plan,$user);
                if($offer)app(UniversalPackageCouponService::class)->redeem($offer,$user,$order->reference_number);
                $subscriptionId=$order->id;
            }
            DB::table('wallet_package_purchases')->where('id',$idPurchase)->update([
                'journal_id'=>$journal->id,'subscription_id'=>$subscriptionId,'status'=>'completed','updated_at'=>now(),
            ]);
            return ['id'=>$idPurchase,'status'=>'completed','subscription_id'=>$subscriptionId,
                'auto_fx_used'=>!$autoFx['available']];
        });
    }
}
