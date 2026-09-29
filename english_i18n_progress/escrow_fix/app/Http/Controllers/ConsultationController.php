<?php

namespace App\Http\Controllers;

use App\Models\Consultation;
use App\Models\Conversation;
use App\Models\ConsultationType;
use App\Models\User;
use App\Models\OfficeMember;
use App\Models\Office;
use App\Notifications\SystemNotification;
use App\Services\UniversalContentModerationService;
use App\Services\SaasPlanService;
use App\Services\ConsultationWalletSettlementService;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ConsultationController extends Controller
{
    public function __construct(
        private readonly UniversalContentModerationService $moderationService,
        private readonly SaasPlanService $plans
    ) {
    }

    /*
    |--------------------------------------------------------------------------
    | عرض جميع الاستشارات
    |--------------------------------------------------------------------------
    */

    public function index(Request $request)
    {
        $query = Consultation::with([
    'customer',
    'engineer',
    'consultationType',
    'assignedOffice',
    'conversation:id,consultation_id',
]);

        /*
        |--------------------------------------------------------------------------
        | البحث برقم الاستشارة أو اسم العميل
        |--------------------------------------------------------------------------
        */

        if ($request->filled('search')) {
            $search = trim((string) $request->search);

            $query->where(function ($subQuery) use ($search) {
                $subQuery
                    ->where(
                        'consultation_number',
                        'like',
                        "%{$search}%"
                    )
                    ->orWhereHas(
                        'customer',
                        function ($customerQuery) use ($search) {
                            $customerQuery->where(
                                'name',
                                'like',
                                "%{$search}%"
                            );
                        }
                    );
            });
        }

        /*
        |--------------------------------------------------------------------------
        | فلترة حسب الحالة
        |--------------------------------------------------------------------------
        */

        if ($request->filled('status')) {
            $query->where(
                'status',
                $request->status
            );
        }

        /*
        |--------------------------------------------------------------------------
        | فلترة حسب المهندس
        |--------------------------------------------------------------------------
        */

        if ($request->filled('engineer_id')) {
            $query->where(
                'engineer_id',
                $request->engineer_id
            );
        }

        /*
        |--------------------------------------------------------------------------
        | فلترة حسب المكتب الهندسي
        |--------------------------------------------------------------------------
        */

        if ($request->filled('office_id')) {
            $query->where(
                'assigned_office_id',
                $request->office_id
            );
        }

        /*
        |--------------------------------------------------------------------------
        | فلترة من تاريخ
        |--------------------------------------------------------------------------
        */

        if ($request->filled('date_from')) {
            $query->whereDate(
                'created_at',
                '>=',
                $request->date_from
            );
        }

        /*
        |--------------------------------------------------------------------------
        | فلترة إلى تاريخ
        |--------------------------------------------------------------------------
        */

        if ($request->filled('date_to')) {
            $query->whereDate(
                'created_at',
                '<=',
                $request->date_to
            );
        }

        $consultations = $query
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $engineers = $this
            ->activeEngineersQuery()
            ->orderBy('name')
            ->get();

        $offices = Office::query()
            ->whereIn(
                'status',
                [
                    'active',
                    'suspended',
                    'closed',
                ]
            )
            ->orderBy('name')
            ->get();

        return view(
            'consultations.index',
            compact(
                'consultations',
                'engineers',
                'offices'
            )
        );
    }

    /*
    |--------------------------------------------------------------------------
    | صفحة إنشاء استشارة عامة
    |--------------------------------------------------------------------------
    */

    public function create(Request $request)
    {
        $types = ConsultationType::query()
            ->orderBy('name')
            ->get();

        $engineer = null;
        $office = null;

        if ($request->filled('office')) {
            $office = Office::query()->where('slug', $request->query('office'))->first();
            if (! $office || ! $office->isOperational()) {
                $office = null;
            }
        }

        return view(
            'consultations.create',
            compact(
                'types',
                'engineer',
                'office'
            )
        );
    }

    /*
    |--------------------------------------------------------------------------
    | صفحة إنشاء استشارة لمهندس محدد
    |--------------------------------------------------------------------------
    */

    public function createForEngineer(
        Request $request,
        User $engineer
    ) {
        abort_unless(
            $engineer->hasActiveEngineerMembership(),
            404,
            'هذا المهندس غير نشط حاليًا.'
        );

        if (
            (int) $engineer->id
            === (int) $request->user()->id
        ) {
            return redirect()
                ->route('engineer.works.public')
                ->with(
                    'error',
                    'لا يمكنك طلب استشارة من نفسك.'
                );
        }

        $types = ConsultationType::query()
            ->orderBy('name')
            ->get();

        $office = null;

        return view(
            'consultations.create',
            compact(
                'types',
                'engineer',
                'office'
            )
        );
    }

    /*
    |--------------------------------------------------------------------------
    | حفظ الاستشارة
    |--------------------------------------------------------------------------
    */

    public function store(Request $request)
    {
        $validated = $request->validate([
            'consultation_type_id' => [
                'required',
                'exists:consultation_types,id',
            ],

            'engineer_id' => [
                'nullable',
                'exists:users,id',
            ],

            'office_id' => [
                'nullable',
                'exists:offices,id',
            ],

            'title' => [
                'required',
                'string',
                'max:255',
            ],

            'description' => [
                'required',
                'string',
            ],

            'customer_file' => [
                'nullable',
                'file',
                'mimes:pdf,jpg,jpeg,png,dwg',
                'max:512000',
            ],
        ]);

        /*
         * منع المستخدم من اختيار نفسه كمهندس.
         */
        if (
            ! empty($validated['engineer_id'])
            && (int) $validated['engineer_id']
                === (int) $request->user()->id
        ) {
            return back()
                ->withErrors([
                    'engineer_id' =>
                        'لا يمكنك طلب استشارة من نفسك.',
                ])
                ->withInput();
        }

        if (! empty($validated['engineer_id']) && ! empty($validated['office_id'])) {
            return back()->withErrors(['office_id' => 'اختر مهندسًا أو مكتبًا، وليس الاثنين معًا.'])->withInput();
        }

        $office = null;
        if (! empty($validated['office_id'])) {
            $office = Office::query()->find($validated['office_id']);
            if (! $office || ! $office->isOperational()) {
                return back()->withErrors(['office_id' => 'المكتب المختار غير متاح لاستقبال الاستشارات حاليًا.'])->withInput();
            }
        }

        if ($office) {
            $this->plans->assertCanAdd($office, 'consultations_per_month');
        }

        /*
        |--------------------------------------------------------------------------
        | فحص عنوان ووصف الاستشارة قبل رفع الملف أو إنشاء الطلب
        |--------------------------------------------------------------------------
        */

        $contentToModerate = trim(
            $validated['title']
            . "\n"
            . $validated['description']
        );

        $moderationResult =
            $this->moderationService->moderateText(
                user: $request->user(),
                text: $contentToModerate,
                sourceType: 'consultation',
                sourceId: null,
                context: [
                    'content_section' =>
                        'consultation_request',

                    'recipient_role' =>
                        ! empty($validated['engineer_id'])
                            ? 'engineer'
                            : (! empty($validated['office_id']) ? 'office' : 'admin'),
                ]
            );

        if (! $moderationResult['allowed']) {
            return back()
                ->withInput()
                ->with(
                    'error',
                    $moderationResult['user_message']
                );
        }

        $type = ConsultationType::findOrFail(
            $validated['consultation_type_id']
        );

        $engineer = null;

        /*
         * التأكد من أن المهندس المختار نشط
         * واشتراكه لم ينتهِ.
         */
        if (! empty($validated['engineer_id'])) {
            $engineer = $this
                ->activeEngineersQuery()
                ->where(
                    'id',
                    $validated['engineer_id']
                )
                ->where(
                    'id',
                    '!=',
                    $request->user()->id
                )
                ->first();

            if (! $engineer) {
                return back()
                    ->withErrors([
                        'engineer_id' =>
                            'المهندس المختار غير نشط أو انتهى اشتراكه.',
                    ])
                    ->withInput();
            }
        }

        $filePath = null;

        try {
            if ($request->hasFile('customer_file')) {
                $filePath = $request
                    ->file('customer_file')
                    ->store(
                        'consultations',
                        'public'
                    );
            }

            $consultation = Consultation::create([
                'consultation_number' =>
                    'CONS-' . time(),

                'customer_id' =>
                    $request->user()->id,

                'consultation_type_id' =>
                    $type->id,

                'engineer_id' =>
                    $engineer?->id,

                'assigned_office_id' =>
                    $office?->id,

                'office_assigned_at' =>
                    $office ? now() : null,

                'title' =>
                    $validated['title'],

                'description' =>
                    $validated['description'],

                'final_price' =>
                    $type->price,
                'currency' => strtoupper((string) $type->currency),

                'status' =>
                    'waiting_payment',

                'payment_status' =>
                    'unpaid',

                'customer_file' =>
                    $filePath,
            ]);
        } catch (\Throwable $exception) {
            if ($filePath) {
                Storage::disk('public')->delete(
                    $filePath
                );
            }

            throw $exception;
        }

        return redirect()
            ->route(
                'payments.create',
                $consultation
            )
            ->with(
                'success',
                $office
                    ? 'تم حفظ الطلب. أكمل الدفع لإرساله إلى المكتب.'
                    : 'تم حفظ الطلب. أكمل الدفع لإرساله إلى المهندس.'
            );
    }

    /*
    |--------------------------------------------------------------------------
    | استشارات المستخدم كعميل
    |--------------------------------------------------------------------------
    */

    public function myConsultations(
        Request $request
    ) {
        $consultations = Consultation::with([
            'consultationType',
            'engineer',
            'review',
            'invoice',
        ])
            ->where(
                'customer_id',
                $request->user()->id
            )
            ->latest()
            ->get();

        return view(
            'consultations.my-consultations',
            compact('consultations')
        );
    }

    /*
    |--------------------------------------------------------------------------
    | صفحة تعيين المهندس
    |--------------------------------------------------------------------------
    */

    /**
     * اعتماد العميل للتسليم النهائي وإكمال الاستشارة.
     * عند النجاح تُحرر حصة المهندس/المكتب من الرصيد المحجوز إلى المستحقات المتاحة.
     */
    public function confirmCompletion(
        Request $request,
        Consultation $consultation,
        ConsultationWalletSettlementService $walletSettlement
    ): RedirectResponse {
        abort_unless(
            (int) $consultation->customer_id === (int) $request->user()->id,
            403,
            'فقط العميل صاحب الاستشارة يستطيع اعتماد اكتمال العمل.'
        );

        $walletSettlement->confirmCompletion($consultation, $request->user());

        $consultation->refresh()->load(['engineer', 'assignedOffice.owner']);
        $provider = $consultation->assigned_office_id
            ? $consultation->assignedOffice?->owner
            : $consultation->engineer;

        if ($provider) {
            $provider->notify(new SystemNotification(
                title: 'تم اعتماد اكتمال الاستشارة',
                message: 'اعتمد العميل اكتمال الاستشارة رقم '
                    . $consultation->consultation_number
                    . ' وتم تحرير مستحقك إلى محفظتك في المنصة.',
                url: route('wallet.index'),
                sendMail: true,
                buttonText: 'فتح المحفظة'
            ));
        }

        return back()->with('success', 'تم اعتماد اكتمال العمل وتحويل مستحق مقدم الخدمة إلى محفظته.');
    }

    public function assignForm(
        Consultation $consultation
    ) {
        if (
            $consultation->payment_status
            !== 'paid'
        ) {
            return redirect()
                ->route('payments.index')
                ->with(
                    'error',
                    'لا يمكن تعيين مهندس قبل تأكيد الدفع.'
                );
        }

        $engineers = $this
            ->activeEngineersQuery()
            ->orderBy('name')
            ->get();

        return view(
            'consultations.assign',
            compact(
                'consultation',
                'engineers'
            )
        );
    }

    /*
    |--------------------------------------------------------------------------
    | تعيين المهندس وتحديث حالة الاستشارة
    |--------------------------------------------------------------------------
    */

    public function assignEngineer(
        Request $request,
        Consultation $consultation
    ) {
        if (
            $consultation->payment_status
            !== 'paid'
        ) {
            abort(
                403,
                'لا يمكن تعيين مهندس لاستشارة غير مدفوعة.'
            );
        }

        abort_if(
            $consultation->status === 'completed',
            422,
            'الاستشارة مكتملة ومستحقها مُحرر؛ لا يمكن إعادة تعيينها.'
        );

        $validated = $request->validate([
            'engineer_id' => [
                'nullable',
                'exists:users,id',
            ],

            'office_id' => [
                'nullable',
                'exists:offices,id',
            ],

            // "completed" is never set here: only the customer's approval of the final file
            // completes a consultation, because that is what releases the held provider share.
            'status' => [
                'required',
                'in:pending,in_progress,cancelled',
            ],

            'started_at' => [
                'required',
                'date',
            ],

            'expected_delivery_at' => [
                'required',
                'date',
                'after:started_at',
            ],
        ]);

        $engineer = null;

        if (! empty($validated['engineer_id'])) {
            $engineer = $this
                ->activeEngineersQuery()
                ->where(
                    'id',
                    $validated['engineer_id']
                )
                ->first();

            if (! $engineer) {
                return back()
                    ->withErrors([
                        'engineer_id' =>
                            'المهندس المختار غير نشط أو انتهى اشتراكه.',
                    ])
                    ->withInput();
            }
        }

        $previousEngineerId =
            $consultation->engineer_id;

        DB::transaction(
            function () use (
                $consultation,
                $engineer,
                $validated,
                $previousEngineerId
            ): void {
                $consultation->update([
                    'engineer_id' =>
                        $engineer?->id,

                    'status' =>
                        $validated['status'],

                    'started_at' =>
                        $validated['started_at'],

                    'expected_delivery_at' =>
                        $validated['expected_delivery_at'],

                    'delivered_at' =>
                        null,
                ]);

                $this->syncConsultationConversation(
                    $consultation->fresh(),
                    $previousEngineerId
                );
            }
        );

        if ($engineer) {
            $engineer->notify(
                new SystemNotification(
                    'تم تعيين استشارة لك',
                    'تم تعيين الاستشارة رقم '
                        . $consultation->consultation_number
                        . ' لك.',
                    '/engineer/consultations'
                )
            );
        }

        return redirect()
            ->route('consultations.index')
            ->with(
                'success',
                'تم تعيين المهندس وتحديث حالة الاستشارة.'
            );
    }

    /*
    |--------------------------------------------------------------------------
    | الاستشارات المسندة للمهندس
    |--------------------------------------------------------------------------
    */

    public function engineerConsultations(
        Request $request
    ) {
        abort_unless(
            $request
                ->user()
                ->hasActiveEngineerMembership(),
            403,
            'حساب المهندس غير نشط. يجب تجديد الاشتراك.'
        );

        $consultations = Consultation::with([
            'customer',
            'consultationType',
        ])
            ->where(
                'engineer_id',
                $request->user()->id
            )
            ->where(
                'payment_status',
                'paid'
            )
            ->latest()
            ->get();

        return view(
            'consultations.engineer',
            compact('consultations')
        );
    }

    /*
    |--------------------------------------------------------------------------
    | رفع الملف النهائي
    |--------------------------------------------------------------------------
    */

    public function uploadEngineerFile(
        Request $request,
        Consultation $consultation
    ): RedirectResponse {
        $user = $request->user();

        abort_unless(
            $user !== null,
            401,
            'يجب تسجيل الدخول.'
        );

        $isAdmin = $user->role === 'admin';

        $isAssignedEngineer =
            $user->role === 'engineer'
            && (int) $consultation->engineer_id
                === (int) $user->id;

        abort_unless(
            $isAdmin || $isAssignedEngineer,
            403,
            'ليس لديك صلاحية رفع الملف النهائي لهذه الاستشارة.'
        );

        abort_if(
            $consultation->status === 'cancelled',
            422,
            'لا يمكن رفع ملف نهائي لاستشارة ملغاة.'
        );

        abort_if(
            $consultation->status === 'completed',
            422,
            'تم اعتماد اكتمال الاستشارة ولا يمكن استبدال التسليم النهائي بعدها.'
        );

        if ($consultation->payment_status !== 'paid') {
            return back()->withErrors([
                'engineer_file' =>
                    'لا يمكن رفع الملف النهائي قبل تأكيد الدفع.',
            ]);
        }

        /*
        |--------------------------------------------------------------------------
        | التحقق من حالة المهندس
        |--------------------------------------------------------------------------
        */

        if (
            ! $isAdmin
            && ! $user->hasActiveEngineerMembership()
        ) {
            return back()->withErrors([
                'engineer_file' =>
                    'حساب المهندس غير نشط. يجب تجديد الاشتراك أولًا.',
            ]);
        }

        /*
        |--------------------------------------------------------------------------
        | إذا كانت الاستشارة محولة إلى مكتب هندسي
        |--------------------------------------------------------------------------
        */

        if (
            ! $isAdmin
            && $consultation->assigned_office_id !== null
        ) {
            $officeMember = OfficeMember::query()
                ->where(
                    'office_id',
                    $consultation->assigned_office_id
                )
                ->where(
                    'user_id',
                    $user->id
                )
                ->where(
                    'office_role',
                    'engineer'
                )
                ->where(
                    'status',
                    'active'
                )
                ->first();

            abort_unless(
                $officeMember !== null,
                403,
                'أنت لست عضوًا فعالًا في المكتب المسؤول عن هذه الاستشارة.'
            );

            $office = $consultation
                ->assignedOffice()
                ->first();

            abort_unless(
                $office !== null,
                404,
                'المكتب المسؤول عن الاستشارة غير موجود.'
            );

            abort_unless(
                $office->isOperational(),
                403,
                'المكتب المسؤول عن الاستشارة غير فعال أو اشتراكه منتهي.'
            );
        }

        /*
        |--------------------------------------------------------------------------
        | التحقق من الملف
        |--------------------------------------------------------------------------
        */

        $validated = $request->validate(
            [
                'engineer_file' => [
                    'required',
                    'file',
                    'mimes:pdf,jpg,jpeg,png,dwg',
                    'max:512000',
                ],
            ],
            [
                'engineer_file.required' =>
                    'يجب اختيار ملف التسليم النهائي.',

                'engineer_file.file' =>
                    'الملف المرفوع غير صالح.',

                'engineer_file.mimes' =>
                    'الملف يجب أن يكون PDF أو صورة أو DWG.',

                'engineer_file.max' =>
                    'حجم الملف يجب ألا يتجاوز 500 ميجابايت.',
            ]
        );

        /*
        |--------------------------------------------------------------------------
        | حفظ الملف الجديد
        |--------------------------------------------------------------------------
        */

        $newFilePath = $validated['engineer_file']->store(
            'consultations/'
            . $consultation->id
            . '/engineer-deliveries',
            'public'
        );

        $oldFilePath = $consultation->engineer_file;

        try {
            DB::transaction(
                function () use (
                    $consultation,
                    $newFilePath
                ): void {
                    $consultation->update([
                        'engineer_file' => $newFilePath,
                        'status' => 'delivered',
                        'delivered_at' => now(),
                    ]);
                }
            );
        } catch (\Throwable $exception) {
            Storage::disk('public')->delete(
                $newFilePath
            );

            throw $exception;
        }

        /*
        |--------------------------------------------------------------------------
        | حذف الملف السابق بعد نجاح تحديث قاعدة البيانات
        |--------------------------------------------------------------------------
        */

        if (
            $oldFilePath
            && $oldFilePath !== $newFilePath
        ) {
            Storage::disk('public')->delete(
                $oldFilePath
            );
        }

        /*
        |--------------------------------------------------------------------------
        | إشعار العميل
        |--------------------------------------------------------------------------
        */

        $consultation->load('customer');

        if ($consultation->customer) {
            $consultation->customer->notify(
                new SystemNotification(
                    'الملف النهائي جاهز',
                    'تم رفع الملف النهائي للاستشارة رقم '
                        . $consultation->consultation_number
                        . '. يرجى مراجعة الملف ثم تأكيد اكتمال العمل لتحرير مستحق مقدم الخدمة.',
                    '/my-consultations'
                )
            );
        }

        return back()->with(
            'success',
            'تم رفع الملف النهائي وباتت الاستشارة بانتظار اعتماد العميل.'
        );
    }

    /*
    |--------------------------------------------------------------------------
    | محادثة الاستشارة
    |--------------------------------------------------------------------------
    */

    public function chat(
        Request $request,
        Consultation $consultation
    ) {
        abort_unless(
            (int) $request->user()->id
                === (int) $consultation->customer_id

            || (int) $request->user()->id
                === (int) $consultation->engineer_id

            || $request->user()->role
                === 'admin',
            403
        );

        $consultation->load([
            'customer',
            'engineer',
            'consultationType',
            'messages.sender',
        ]);

        return view(
            'consultations.chat',
            compact('consultation')
        );
    }

    /*
    |--------------------------------------------------------------------------
    | إنشاء أو تحديث محادثة الاستشارة
    |--------------------------------------------------------------------------
    */

    private function syncConsultationConversation(
        Consultation $consultation,
        ?int $previousEngineerId = null
    ): Conversation {
        $conversation = Conversation::firstOrCreate(
            [
                'type' => 'consultation',
                'consultation_id' =>
                    $consultation->id,
            ],
            [
                'created_by' => auth()->id(),
                'last_message_at' => null,
            ]
        );

        /*
         * إزالة المهندس السابق عند تغيير التعيين،
         * حتى لا يبقى قادرًا على دخول المحادثة.
         */
        if (
            $previousEngineerId
            && (int) $previousEngineerId
                !== (int) $consultation->engineer_id
            && (int) $previousEngineerId
                !== (int) $consultation->customer_id
        ) {
            $conversation
                ->participants()
                ->detach($previousEngineerId);
        }

        $participantIds = array_values(
            array_unique(
                array_filter([
                    $consultation->customer_id,
                    $consultation->engineer_id,
                ])
            )
        );

        foreach ($participantIds as $participantId) {
            $conversation
                ->participants()
                ->syncWithoutDetaching([
                    $participantId => [
                        'last_read_at' => null,
                        'is_muted' => false,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ],
                ]);
        }

        return $conversation;
    }

    /*
    |--------------------------------------------------------------------------
    | استعلام المهندسين النشطين
    |--------------------------------------------------------------------------
    */

    private function activeEngineersQuery()
    {
        return User::query()
            ->where(
                'role',
                'engineer'
            )
            ->where(
                'status',
                'active'
            )
            ->where(
                'engineer_membership_status',
                'active'
            )
            ->whereNotNull(
                'engineer_active_until'
            )
            ->where(
                'engineer_active_until',
                '>',
                now()
            );
    }
}
