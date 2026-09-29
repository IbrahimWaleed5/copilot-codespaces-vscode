<?php

use App\Http\Controllers\BankGatewayWebhookController;
use App\Http\Controllers\CheckoutGatewayWebhookController;

use App\Http\Controllers\Api\CrmApiController;
use App\Http\Controllers\Api\FinancialReportApiController;
use App\Http\Controllers\Api\ExpenseApiController;
use App\Http\Controllers\Api\OfficeFinanceApiController;
use App\Http\Controllers\Api\AccountRecoveryApiController;
use App\Http\Controllers\Api\BiometricApiController;
use App\Http\Controllers\Api\AdminPaymentApiController;
use App\Http\Controllers\Api\AdminActionCenterApiController;
use App\Http\Controllers\Api\AdminOfficeApiController;
use App\Http\Controllers\Api\OfficeApiController;
use App\Http\Controllers\Api\OfficeTenantApiController;
use App\Http\Controllers\Api\SaasPlanApiController;
use App\Http\Controllers\Api\AdminSaasPlanApiController;
use App\Http\Controllers\Api\EngineerWorkspaceApiController;
use App\Http\Controllers\Api\OfficePublicContentApiController;
use App\Http\Controllers\ProjectMeetingLiveController;
use App\Http\Controllers\Api\RealtimeConfigApiController;
use App\Http\Controllers\Api\AccountSecurityApiController;
use App\Http\Controllers\Api\AdminEngineeringApiController;
use App\Http\Controllers\Api\ConversationApiController;
use App\Http\Controllers\Api\EmployeeApiController;
use App\Http\Controllers\Api\EngineerEarningApiController;
use App\Http\Controllers\Api\EngineerSpecialtyApiController;
use App\Http\Controllers\Api\SupportApiController;
use App\Http\Controllers\Api\PublicSupportApiController;
use App\Http\Controllers\Api\SupportCustomerApiController;
use App\Http\Controllers\ConversationFileController;
use App\Http\Controllers\ConversationMessageController;
use App\Http\Controllers\SupportBotController;
use App\Http\Controllers\AiWorkspaceController;
use App\Http\Controllers\AssistantSettingsController;
use App\Http\Controllers\ProjectTeamChatController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Auth\SocialAuthController;
use App\Http\Controllers\Api\ConsultationApiController;
use App\Http\Controllers\Api\ConsultationMessageApiController;
use App\Http\Controllers\Api\DashboardApiController;
use App\Http\Controllers\Api\DeviceTokenApiController;
use App\Http\Controllers\Api\EmailVerificationApiController;
use App\Http\Controllers\Api\EngineerApplicationApiController;
use App\Http\Controllers\Api\AdminEngineerCloudPlanApiController;
use App\Http\Controllers\Api\EngineerCloudPlanApiController;
use App\Http\Controllers\Api\EngineerDirectoryApiController;
use App\Http\Controllers\Api\AdminProfessionalVerificationApiController;
use App\Http\Controllers\Api\EngineerLibraryApiController;
use App\Http\Controllers\Api\EngineerProfileApiController;
use App\Http\Controllers\Api\EngineerReviewApiController;
use App\Http\Controllers\Api\EngineerWorkStoreApiController;
use App\Http\Controllers\Api\HomeApiController;
use App\Http\Controllers\Api\InvoiceApiController;
use App\Http\Controllers\Api\NotificationApiController;
use App\Http\Controllers\Api\PaymentApiController;
use App\Http\Controllers\Api\PaymentInformationApiController;
use App\Http\Controllers\Api\ProfileApiController;
use App\Http\Controllers\Api\ProjectApiController;
use App\Http\Controllers\Api\ProjectBoqApiController;
use App\Http\Controllers\Api\ProjectContractApiController;
use App\Http\Controllers\Api\ProjectDetailApiController;
use App\Http\Controllers\Api\ProjectFileApiController;
use App\Http\Controllers\Api\ProjectGanttApiController;
use App\Http\Controllers\Api\ProjectMilestoneApiController;
use App\Http\Controllers\Api\ProjectWorkflowApiController;
use App\Http\Controllers\Api\ProjectExecutionApiController;
use App\Http\Controllers\Api\ProjectEngineerAllocationApiController;
use App\Http\Controllers\Api\ProjectAdvancedApiController;
use App\Http\Controllers\Api\ProjectFieldApiController;
use App\Http\Controllers\Api\ProjectDrawingMarkupApiController;
use App\Http\Controllers\Api\ProjectBimApiController;
use App\Http\Controllers\Api\AccountMenuApiController;
use App\Http\Controllers\Api\PayoutAccountApiController;
use App\Http\Controllers\Api\FinalizationApiController;
use App\Http\Controllers\ProjectMeetingMinutesPdfController;
use App\Http\Controllers\ProjectCalendarIcsController;
use App\Http\Controllers\ProjectBoqExportController;
use App\Http\Controllers\Api\RegisterApiController;
use App\Http\Controllers\Api\SecureFileApiController;
use App\Http\Controllers\Api\MarketplaceApiController;
use App\Http\Controllers\Api\ProfessionalVerificationApiController;
use App\Http\Controllers\Api\WorkLibraryApiController;
use App\Http\Controllers\Api\Enterprise\EnterpriseManagementApiController;
use App\Http\Controllers\Api\Enterprise\ExternalApiController;
use App\Http\Controllers\Api\PlatformPaymentMethodApiController;
use App\Http\Controllers\Api\PayoutQueueApiController;
use App\Http\Controllers\Api\ProjectHandoverApiController;
use App\Http\Controllers\Api\ConversationReviewApiController;
use App\Http\Controllers\Api\DisputeCaseApiController;
use App\Http\Controllers\Api\AdminRefundApiController;
use App\Http\Controllers\Api\FinancialControlApiController;
use App\Http\Controllers\Api\SlaCenterApiController;
use App\Http\Controllers\Api\AiPremiumApiController;
use App\Http\Controllers\Api\KycApiController;
use App\Http\Controllers\Api\AdminKycApiController;
use App\Http\Controllers\Api\AdminPermissionApiController;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — تُستخدم من تطبيق Flutter (وأي عميل خارجي آخر)
|--------------------------------------------------------------------------
*/

// عام — بدون تسجيل دخول (لكن بيقرأ التوكن لو موجود، عشان صلاحيات إضافية)
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:auth-login');
Route::get('/payment-methods', [PlatformPaymentMethodApiController::class, 'publicIndex']);
Route::post('/login/temporary-password/change', [AuthController::class, 'completeTemporaryPasswordChange'])->middleware('throttle:auth-recovery');
Route::post('/login/email-two-factor', [AuthController::class, 'completeEmailTwoFactor'])->middleware('throttle:auth-2fa');
Route::post('/login/email-two-factor/resend', [AuthController::class, 'resendLoginEmailTwoFactor'])->middleware('throttle:auth-2fa');
Route::post('/login/two-factor/methods', [AccountRecoveryApiController::class, 'alternativeMethods'])->middleware('throttle:20,1');
Route::post('/login/two-factor/authenticator', [AccountRecoveryApiController::class, 'verifyAuthenticator'])->middleware('throttle:8,1');
Route::post('/login/two-factor/recovery-code', [AccountRecoveryApiController::class, 'verifyRecoveryCode'])->middleware('throttle:8,1');
Route::post('/login/account-recovery', [AccountRecoveryApiController::class, 'requestRecovery'])->middleware('throttle:5,1');
Route::post('/account-recovery/manual', [AccountRecoveryApiController::class, 'requestManualRecovery'])->middleware('throttle:3,10');
Route::post('/account-recovery/manual/status', [AccountRecoveryApiController::class, 'manualRecoveryStatus'])->middleware('throttle:20,1');
Route::post('/support/public/lookup', [PublicSupportApiController::class, 'lookup'])->middleware('throttle:10,1');
Route::post('/support/public/ticket', [PublicSupportApiController::class, 'show'])->middleware('throttle:30,1');
Route::post('/support/public/reply', [PublicSupportApiController::class, 'reply'])->middleware('throttle:20,1');

Route::post('/login/account-recovery/status', [AccountRecoveryApiController::class, 'recoveryStatus'])->middleware('throttle:20,1');
Route::post('/login/account-recovery/continue', [AccountRecoveryApiController::class, 'continueRecovery'])->middleware('throttle:10,1');
Route::post('/biometric/webhook', [BiometricApiController::class, 'webhook'])->middleware('throttle:120,1');
Route::post('/register', [RegisterApiController::class, 'store'])->middleware('throttle:auth-register');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:auth-recovery');
Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:auth-recovery');
Route::post('/auth/social/exchange', [SocialAuthController::class, 'exchange'])->middleware('throttle:auth-social');
Route::get('/home', [HomeApiController::class, 'index']);
Route::get('/engineer-library', [EngineerLibraryApiController::class, 'index']);
Route::get('/work-library', [WorkLibraryApiController::class, 'index']);
Route::get('/engineer-library/{engineerWork}', [EngineerLibraryApiController::class, 'show']);
Route::get('/engineers', [EngineerDirectoryApiController::class, 'index']);
Route::get('/engineers/{user}', [EngineerProfileApiController::class, 'show']);
Route::get('/consultation-types', [ConsultationApiController::class, 'types']);
Route::get('/offices', [OfficeApiController::class, 'directory']);
Route::get('/offices/{office}', [OfficeApiController::class, 'show']);
Route::get('/payment-information', [PaymentInformationApiController::class, 'index']);
Route::post('/smart-assistant/guest/ask', [SupportBotController::class, 'guestAsk'])->middleware('throttle:ai-heavy');

// مصادقة قنوات Reverb الخاصة/Presence لتطبيق Flutter عبر Bearer Token.
Broadcast::routes(['middleware' => ['auth:sanctum']]);

// يتطلب توكن Sanctum صالح

Route::post('/webhooks/bank', [BankGatewayWebhookController::class, 'handle'])
    ->name('api.webhooks.bank');

Route::post('/webhooks/payments/{provider}', [CheckoutGatewayWebhookController::class, 'handle'])
    ->middleware('throttle:webhooks')
    ->name('api.webhooks.checkout');


// Enterprise External API v1 — tenant isolated by enterprise.api token.
Route::prefix('v1')->middleware(['enterprise.api','throttle:120,1'])->group(function () {
    Route::get('/tenant', [ExternalApiController::class, 'tenant']);
    Route::get('/projects', [ExternalApiController::class, 'projects']);
    Route::get('/projects/{project}', [ExternalApiController::class, 'project'])->whereNumber('project');
    Route::get('/consultations', [ExternalApiController::class, 'consultations']);
    Route::get('/files', [ExternalApiController::class, 'files']);
    Route::get('/payments', [ExternalApiController::class, 'payments']);
});

Route::get('/saas/plans', [SaasPlanApiController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/admin/permissions', [AdminPermissionApiController::class, 'index']);
    Route::patch('/admin/permissions/job-titles', [AdminPermissionApiController::class, 'updateJobTitle'])->middleware('throttle:sensitive');
    Route::patch('/admin/permissions/users/{user}/extras', [AdminPermissionApiController::class, 'updateUserExtras'])->middleware('throttle:sensitive');
    Route::patch('/admin/permissions/users/{user}', [AdminPermissionApiController::class, 'update'])->middleware('throttle:sensitive');
    Route::get('/me', [AuthController::class, 'me']);

    // SaaS tenant context — office is the tenant boundary.
    Route::get('/office/context', [OfficeTenantApiController::class, 'index']);
    Route::post('/office/context', [OfficeTenantApiController::class, 'select']);
    Route::get('/office/saas-plan', [SaasPlanApiController::class, 'current'])->middleware('office.owner');
    Route::get('/realtime/config', RealtimeConfigApiController::class);
    Route::post('/logout', [AuthController::class, 'logout']);


    // Enterprise / Multi-tenant management (office owner/manager only).
    Route::get('/enterprise', [EnterpriseManagementApiController::class, 'index']);
    Route::patch('/enterprise/tenant', [EnterpriseManagementApiController::class, 'updateTenant']);
    Route::post('/enterprise/api-tokens', [EnterpriseManagementApiController::class, 'createToken']);
    Route::delete('/enterprise/api-tokens/{apiToken}', [EnterpriseManagementApiController::class, 'revokeToken']);
    Route::post('/enterprise/webhooks', [EnterpriseManagementApiController::class, 'createWebhook']);
    Route::patch('/enterprise/webhooks/{webhook}', [EnterpriseManagementApiController::class, 'updateWebhook']);
    Route::delete('/enterprise/webhooks/{webhook}', [EnterpriseManagementApiController::class, 'deleteWebhook']);
    Route::post('/enterprise/webhooks/{webhook}/test', [EnterpriseManagementApiController::class, 'testWebhook']);
    Route::post('/enterprise/invitations', [EnterpriseManagementApiController::class, 'createInvitation']);
    Route::post('/enterprise/invitations/accept', [EnterpriseManagementApiController::class, 'acceptInvitation']);

    Route::get('/email/verification-status', [EmailVerificationApiController::class, 'status']);
    Route::post('/email/verification-notification', [EmailVerificationApiController::class, 'resend'])
        ->middleware('throttle:6,1');
    Route::get('/dashboard', [DashboardApiController::class, 'index']);
    Route::get('/financial/reports', [FinancialReportApiController::class, 'index']);
    Route::get('/financial/reports/csv', [FinancialReportApiController::class, 'csv']);
    Route::get('/crm', [CrmApiController::class, 'index']);
    Route::post('/crm/leads', [CrmApiController::class, 'storeLead']);
    Route::get('/crm/leads/{lead}', [CrmApiController::class, 'show']);
    Route::patch('/crm/leads/{lead}', [CrmApiController::class, 'updateLead']);
    Route::post('/crm/leads/{lead}/activities', [CrmApiController::class, 'storeActivity']);
    Route::post('/crm/leads/{lead}/follow-ups', [CrmApiController::class, 'storeFollowUp']);
    Route::patch('/crm/follow-ups/{followUp}', [CrmApiController::class, 'updateFollowUp']);
    Route::patch('/crm/follow-ups/{followUp}/{action}', [CrmApiController::class, 'followUpAction'])->whereIn('action', ['complete', 'cancel']);
    Route::post('/crm/leads/{lead}/opportunities', [CrmApiController::class, 'storeOpportunity']);
    Route::patch('/crm/opportunities/{opportunity}', [CrmApiController::class, 'updateOpportunity']);
    Route::post('/crm/leads/{lead}/convert', [CrmApiController::class, 'convert']);

    Route::get('/consultations', [ConsultationApiController::class, 'index']);
    Route::post('/consultations', [ConsultationApiController::class, 'store']);
    Route::get('/consultations/{consultation}', [ConsultationApiController::class, 'show']);

    Route::get('/consultations/{consultation}/messages', [ConsultationMessageApiController::class, 'index']);
    Route::post('/consultations/{consultation}/messages', [ConsultationMessageApiController::class, 'store']);

    Route::post('/consultations/{consultation}/engineer-file', [ConsultationApiController::class, 'uploadEngineerFile']);
    Route::post('/consultations/{consultation}/confirm-completion', [ConsultationApiController::class, 'confirmCompletion']);

    Route::get('/consultations/{consultation}/payment', [PaymentApiController::class, 'create']);
    Route::post('/consultations/{consultation}/payment', [PaymentApiController::class, 'store']);

    Route::get('/consultations/{consultation}/review', [EngineerReviewApiController::class, 'create']);
    Route::post('/consultations/{consultation}/review', [EngineerReviewApiController::class, 'store']);

    Route::post('/device-tokens', [DeviceTokenApiController::class, 'store']);
    Route::delete('/device-tokens', [DeviceTokenApiController::class, 'destroy']);

    Route::get('/notifications', [NotificationApiController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationApiController::class, 'unreadCount']);
    Route::post('/notifications/read-all', [NotificationApiController::class, 'markAllAsRead']);
    Route::post('/notifications/{notification}/read', [NotificationApiController::class, 'markAsRead']);
    Route::delete('/notifications/{notification}', [NotificationApiController::class, 'destroy']);

    Route::get('/admin/action-center', [AdminActionCenterApiController::class, 'index'])
        ->middleware('role:admin');

    // إدارة الإشعارات العامة — مدير النظام فقط.
    Route::middleware('role:admin')->group(function () {
        Route::get('/notifications/push-status', [NotificationApiController::class, 'pushStatus']);
        Route::post('/notifications/test-push', [NotificationApiController::class, 'testPush'])
            ->middleware('throttle:10,1');
        Route::post('/notifications/broadcast', [NotificationApiController::class, 'broadcast'])
            ->middleware('throttle:6,1');
    });

    Route::get('/projects', [ProjectApiController::class, 'index']);
    Route::get('/projects/{project}', [ProjectDetailApiController::class, 'show']);
    Route::get('/projects/{project}/boqs', [ProjectBoqApiController::class, 'index']);
    Route::get('/projects/{project}/boqs/{boq}', [ProjectBoqApiController::class, 'show']);
    Route::get('/projects/{project}/gantt', [ProjectGanttApiController::class, 'index']);

    Route::get('/projects/{project}/files', [ProjectFileApiController::class, 'index']);
    Route::post('/projects/{project}/files', [ProjectFileApiController::class, 'store']);
    Route::get('/projects/{project}/files/{projectFile}', [ProjectFileApiController::class, 'show']);
    Route::get('/projects/{project}/files/{projectFile}/download', [ProjectFileApiController::class, 'download']);

    Route::get('/projects/{project}/contract', [ProjectContractApiController::class, 'show']);
    Route::get('/projects/{project}/contract/download', [ProjectContractApiController::class, 'download']);
    Route::post('/projects/{project}/contract/sign', [ProjectContractApiController::class, 'sign']);
    Route::patch('/projects/{project}/contract/decline', [ProjectContractApiController::class, 'decline']);

    Route::get('/projects/{project}/milestones', [ProjectMilestoneApiController::class, 'index']);
    Route::post('/projects/{project}/milestones', [ProjectMilestoneApiController::class, 'storeMilestone']);
    Route::put('/projects/{project}/milestones/{milestone}', [ProjectMilestoneApiController::class, 'updateMilestone']);
    Route::delete('/projects/{project}/milestones/{milestone}', [ProjectMilestoneApiController::class, 'destroyMilestone']);
    Route::post('/projects/{project}/milestones/{milestone}/tasks', [ProjectMilestoneApiController::class, 'storeTask']);
    Route::put('/projects/{project}/tasks/{task}', [ProjectMilestoneApiController::class, 'updateTask']);
    Route::delete('/projects/{project}/tasks/{task}', [ProjectMilestoneApiController::class, 'destroyTask']);
    Route::put('/projects/{project}/tasks/{task}/status', [ProjectMilestoneApiController::class, 'updateTaskStatus']);

    Route::get('/my-engineer-works', [EngineerWorkStoreApiController::class, 'myWorks']);
    Route::post('/engineer-works', [EngineerWorkStoreApiController::class, 'store']);
    Route::delete('/engineer-works/{engineerWork}', [EngineerWorkStoreApiController::class, 'destroy']);

    Route::get('/engineer/cloud-plan', [EngineerCloudPlanApiController::class, 'index']);
    Route::post('/engineer/cloud-plan/request', [EngineerCloudPlanApiController::class, 'requestPlan'])->middleware('throttle:sensitive');

    Route::get('/engineer-application/create', [EngineerApplicationApiController::class, 'create']);
    Route::post('/engineer-application', [EngineerApplicationApiController::class, 'store']);
    Route::get('/engineer-application/mine', [EngineerApplicationApiController::class, 'mine']);

    Route::get('/consultations/{consultation}/files/customer', [SecureFileApiController::class, 'consultationCustomerFile']);
    Route::get('/consultations/{consultation}/files/engineer', [SecureFileApiController::class, 'consultationEngineerFile']);
    Route::get('/consultations/{consultation}/messages/{message}/attachment', [SecureFileApiController::class, 'messageAttachment']);
    Route::get('/payments/{payment}/receipt', [SecureFileApiController::class, 'paymentReceipt']);

    Route::put('/profile', [ProfileApiController::class, 'update']);
    Route::put('/profile/password', [ProfileApiController::class, 'updatePassword']);

    Route::get('/admin/payments', [AdminPaymentApiController::class, 'index']);
    Route::post('/admin/payments/{payment}/confirm', [AdminPaymentApiController::class, 'confirm']);
    Route::post('/admin/payments/{payment}/reject', [AdminPaymentApiController::class, 'reject']);

    Route::get('/invoices', [InvoiceApiController::class, 'index']);
    Route::get('/invoices/{invoice}/download', [InvoiceApiController::class, 'download']);

    // المرحلة 10 — الحساب والأمان
    Route::get('/profile/security', [AccountSecurityApiController::class, 'status']);
    Route::post('/profile/security/passkeys/mobile-bridge', [AccountSecurityApiController::class, 'mobilePasskeyBridge'])->middleware('throttle:5,1');
    Route::post('/profile/security/email-two-factor/enable', [AccountSecurityApiController::class, 'enableEmailTwoFactor'])->middleware('throttle:3,1');
    Route::post('/profile/security/email-two-factor/confirm', [AccountSecurityApiController::class, 'confirmEmailTwoFactor'])->middleware('throttle:5,1');
    Route::post('/profile/security/email-two-factor/resend', [AccountSecurityApiController::class, 'resendEmailTwoFactor'])->middleware('throttle:3,1');
    Route::delete('/profile/security/email-two-factor', [AccountSecurityApiController::class, 'disableEmailTwoFactor'])->middleware('throttle:5,1');
    Route::get('/profile/account-status', [AccountSecurityApiController::class, 'accountStatus']);
    Route::post('/profile/account/delete-otp', [AccountSecurityApiController::class, 'requestAccountDeletionOtp'])->middleware('throttle:6,1');
    Route::delete('/profile/account', [AccountSecurityApiController::class, 'destroyAccount']);

    // إدارة الموظفين
    Route::get('/admin/employees', [EmployeeApiController::class, 'index']);
    Route::post('/admin/employees', [EmployeeApiController::class, 'store']);
    Route::get('/admin/employees/{user}', [EmployeeApiController::class, 'show']);
    Route::patch('/admin/employees/{user}', [EmployeeApiController::class, 'update']);
    Route::delete('/admin/employees/{user}', [EmployeeApiController::class, 'destroy']);

    // تخصص المهندس
    Route::get('/engineer/specialty', [EngineerSpecialtyApiController::class, 'show']);
    Route::put('/engineer/specialty', [EngineerSpecialtyApiController::class, 'update']);

    // مستحقات المهندسين المباشرين
    Route::get('/engineer-earnings', [EngineerEarningApiController::class, 'index']);
    Route::patch('/engineer-earnings/{engineerEarning}/percentage', [EngineerEarningApiController::class, 'updatePercentage']);
    Route::patch('/engineer-earnings/{engineerEarning}/mark-paid', [EngineerEarningApiController::class, 'markPaid']);

    // المحادثات المباشرة ومحادثات الاستشارات
    Route::get('/conversations', [ConversationApiController::class, 'index']);
    Route::get('/conversations/{conversation}', [ConversationApiController::class, 'show']);
    Route::post('/admin/conversations/direct/{user}', [ConversationApiController::class, 'startDirect']);
    Route::post('/conversations/{conversation}/messages', [ConversationMessageController::class, 'store']);
    Route::post('/conversations/{conversation}/read', [ConversationMessageController::class, 'read']);
    Route::delete('/conversations/{conversation}/messages/{message}', [ConversationMessageController::class, 'destroy'])->scopeBindings();
    Route::get('/conversations/{conversation}/messages/{message}/download', [ConversationFileController::class, 'download'])->scopeBindings();

    // الدعم الفني
    Route::get('/support', [SupportApiController::class, 'index']);
    Route::post('/support', [SupportApiController::class, 'store'])->middleware('support.abuse');
    Route::get('/support/customers/search', [SupportCustomerApiController::class, 'search'])->middleware(['support.2fa','throttle:support-customer-search']);
    Route::get('/support/customers/{user}', [SupportCustomerApiController::class, 'show'])->whereNumber('user');
    Route::get('/support/{supportTicket}', [SupportApiController::class, 'show'])->whereNumber('supportTicket');
    Route::post('/support/{supportTicket}/messages', [SupportApiController::class, 'sendMessage'])->whereNumber('supportTicket');
    Route::patch('/support/{supportTicket}/status', [SupportApiController::class, 'updateStatus'])->whereNumber('supportTicket');
    Route::post('/support/{supportTicket}/escalate', [SupportApiController::class, 'escalate'])->whereNumber('supportTicket');
    Route::get('/support-settings', [SupportApiController::class, 'settings']);
    Route::patch('/support-settings', [SupportApiController::class, 'updateSettings']);
    Route::get('/support/messages/{supportMessage}/attachment', [SupportApiController::class, 'attachment']);

    // المساعد الذكي — نفس AI في الموقع والتطبيق مع سجل محادثات مستقل لكل حساب
    Route::post('/support-bot/start', [SupportBotController::class, 'start']);
    Route::get('/support-bot/conversations', [SupportBotController::class, 'history']);
    Route::get('/support-bot/workspace', [AiWorkspaceController::class, 'index']);
    Route::post('/support-bot/workspace/libraries', [AiWorkspaceController::class, 'createLibrary']);
    Route::get('/support-bot/workspace/conversations', [AiWorkspaceController::class, 'conversations']);
    Route::patch('/support-bot/conversations/{ticket}', [SupportBotController::class, 'rename'])->whereNumber('ticket');
    Route::delete('/support-bot/conversations/{ticket}', [SupportBotController::class, 'archive'])->whereNumber('ticket');
    Route::post('/support-bot/send', [SupportBotController::class, 'send'])->middleware('throttle:ai-heavy');
    Route::post('/support-bot/analyze-file', [SupportBotController::class, 'analyzeFile'])->middleware('throttle:ai-heavy');
    Route::get('/support-bot/tickets/{ticket}/messages', [SupportBotController::class, 'messages']);
    Route::post('/support-bot/tickets/{ticket}/resolve', [SupportBotController::class, 'resolve']);
    Route::post('/support-bot/tickets/{ticket}/transfer', [SupportBotController::class, 'transfer']);

    // مراجعات الإدارة الهندسية
    Route::get('/admin/engineer-applications', [AdminEngineeringApiController::class, 'applications']);
    Route::get('/admin/engineer-subscriptions', [AdminEngineeringApiController::class, 'subscriptions']);
    Route::get('/admin/engineer-cloud-plan-orders', [AdminEngineerCloudPlanApiController::class, 'index']);
    Route::patch('/admin/engineer-cloud-plan-orders/{order}', [AdminEngineerCloudPlanApiController::class, 'review'])->middleware('throttle:sensitive');
    Route::get('/admin/engineer-cloud-plan-orders/{order}/receipt', [AdminEngineerCloudPlanApiController::class, 'receipt']);
    Route::patch('/admin/engineer-applications/{engineerApplication}/approve', [AdminEngineeringApiController::class, 'approveApplication']);
    Route::patch('/admin/engineer-applications/{engineerApplication}/reject', [AdminEngineeringApiController::class, 'rejectApplication']);
    Route::get('/admin/engineer-works', [AdminEngineeringApiController::class, 'works']);
    Route::patch('/admin/engineer-works/{engineerWork}/approve', [AdminEngineeringApiController::class, 'approveWork']);
    Route::patch('/admin/engineer-works/{engineerWork}/reject', [AdminEngineeringApiController::class, 'rejectWork']);
    Route::delete('/admin/engineer-works/{engineerWork}', [AdminEngineeringApiController::class, 'destroyWork']);
    Route::get('/admin/reviews', [AdminEngineeringApiController::class, 'reviews']);
    Route::patch('/admin/reviews/{review}/approve', [AdminEngineeringApiController::class, 'approveReview']);
    Route::patch('/admin/reviews/{review}/reject', [AdminEngineeringApiController::class, 'rejectReview']);
    Route::patch('/admin/reviews/{review}/featured', [AdminEngineeringApiController::class, 'toggleFeaturedReview']);
    Route::delete('/admin/reviews/{review}', [AdminEngineeringApiController::class, 'destroyReview']);

    // المرحلة 12 — دورة المشروع والمالية والفريق والضمان
    Route::get('/project-requests', [ProjectWorkflowApiController::class, 'requests']);
    Route::post('/consultations/{consultation}/request-project', [ProjectWorkflowApiController::class, 'requestProject']);
    Route::get('/project-requests/{projectRequest}', [ProjectWorkflowApiController::class, 'showRequest']);
    Route::post('/project-requests/{projectRequest}/proposals', [ProjectWorkflowApiController::class, 'submitProposal']);
    Route::patch('/project-requests/{projectRequest}/proposals/{projectProposal}/approve', [ProjectWorkflowApiController::class, 'approveProposal']);

    Route::post('/projects/{project}/installments', [ProjectWorkflowApiController::class, 'addInstallment']);
    Route::get('/projects/{project}/installments/{installment}/payment', [ProjectWorkflowApiController::class, 'installmentPaymentInfo']);
    Route::post('/projects/{project}/installments/{installment}/payment', [ProjectWorkflowApiController::class, 'initiateInstallmentPayment']);
    Route::post('/projects/{project}/installments/{installment}/receipt', [ProjectWorkflowApiController::class, 'uploadReceipt']);
    Route::get('/projects/{project}/installments/{installment}/receipt', [ProjectWorkflowApiController::class, 'receipt']);
    Route::patch('/projects/{project}/installments/{installment}/confirm', [ProjectWorkflowApiController::class, 'confirmInstallment']);
    Route::patch('/projects/{project}/installments/{installment}/reject', [ProjectWorkflowApiController::class, 'rejectInstallment']);

    Route::get('/projects/{project}/escrow', [ProjectWorkflowApiController::class, 'escrowIndex']);
    Route::post('/projects/{project}/escrow/fund', [ProjectWorkflowApiController::class, 'fundEscrow']);
    Route::post('/projects/{project}/escrow/{escrow}/release', [ProjectWorkflowApiController::class, 'releaseEscrow']);

    Route::get('/projects/{project}/team', [ProjectWorkflowApiController::class, 'team']);
    Route::post('/projects/{project}/team', [ProjectWorkflowApiController::class, 'addTeamMember']);
    Route::delete('/projects/{project}/team/{teamMember}', [ProjectWorkflowApiController::class, 'removeTeamMember']);

    Route::get('/projects/{project}/engineer-allocations', [ProjectEngineerAllocationApiController::class, 'index']);
    Route::post('/projects/{project}/engineer-allocations', [ProjectEngineerAllocationApiController::class, 'store']);
    Route::delete('/projects/{project}/engineer-allocations/{allocation}', [ProjectEngineerAllocationApiController::class, 'destroy']);

    Route::get('/financial/project-engineer-earnings', [ProjectWorkflowApiController::class, 'engineerEarnings']);
    Route::patch('/financial/project-engineer-earnings/{earning}/paid', [ProjectWorkflowApiController::class, 'markEngineerEarningPaid']);
    Route::get('/financial/project-office-earnings', [ProjectWorkflowApiController::class, 'officeEarnings']);
    Route::post('/projects/{project}/office-percentage', [ProjectWorkflowApiController::class, 'setOfficePercentage']);
    Route::patch('/financial/project-office-earnings/{earning}/paid', [ProjectWorkflowApiController::class, 'markOfficeEarningPaid']);

    Route::get('/financial/project-closing', [ProjectWorkflowApiController::class, 'financialClosing']);
    Route::patch('/financial/project-closing/{project}/close', [ProjectWorkflowApiController::class, 'closeFinancial']);
    Route::patch('/financial/project-closing/{project}/reopen', [ProjectWorkflowApiController::class, 'reopenFinancial']);
    Route::get('/admin/audit-logs', [ProjectWorkflowApiController::class, 'auditLogs']);


    // المرحلة 13 — التنفيذ المتقدم للمشروع
    Route::get('/projects/{project}/execution-dashboard', [ProjectExecutionApiController::class, 'dashboard']);

    Route::get('/projects/{project}/milestones/{milestone}/submissions', [ProjectExecutionApiController::class, 'milestoneSubmissions']);
    Route::post('/projects/{project}/milestones/{milestone}/submissions', [ProjectExecutionApiController::class, 'storeMilestoneSubmission']);
    Route::patch('/projects/{project}/milestones/{milestone}/submissions/{submission}/approve', [ProjectExecutionApiController::class, 'approveMilestoneSubmission']);
    Route::patch('/projects/{project}/milestones/{milestone}/submissions/{submission}/reject', [ProjectExecutionApiController::class, 'rejectMilestoneSubmission']);
    Route::get('/projects/{project}/milestones/{milestone}/submissions/{submission}/download', [ProjectExecutionApiController::class, 'downloadMilestoneSubmission']);

    Route::get('/projects/{project}/files/{projectFile}/versions', [ProjectExecutionApiController::class, 'fileVersions']);
    Route::post('/projects/{project}/files/{projectFile}/versions', [ProjectExecutionApiController::class, 'storeFileVersion']);
    Route::patch('/projects/{project}/files/{projectFile}/versions/{version}/approve', [ProjectExecutionApiController::class, 'approveFileVersion']);
    Route::patch('/projects/{project}/files/{projectFile}/versions/{version}/reject', [ProjectExecutionApiController::class, 'rejectFileVersion']);
    Route::get('/projects/{project}/files/{projectFile}/versions/{version}/download', [ProjectExecutionApiController::class, 'downloadFileVersion']);
    Route::patch('/projects/{project}/files/{projectFile}/revoke-customer', [ProjectExecutionApiController::class, 'revokeFileCustomerAccess']);
    Route::delete('/projects/{project}/files/{projectFile}', [ProjectExecutionApiController::class, 'deleteProjectFile']);

    // Phase 3 — Drawing Markup + Visual Version Compare data
    Route::get('/projects/{project}/files/{projectFile}/versions/{version}/markups', [ProjectDrawingMarkupApiController::class, 'index']);
    Route::post('/projects/{project}/files/{projectFile}/versions/{version}/markups', [ProjectDrawingMarkupApiController::class, 'store']);
    Route::patch('/projects/{project}/files/{projectFile}/versions/{version}/markups/{markup}', [ProjectDrawingMarkupApiController::class, 'update']);
    Route::patch('/projects/{project}/files/{projectFile}/versions/{version}/markups/{markup}/resolve', [ProjectDrawingMarkupApiController::class, 'resolve']);
    Route::delete('/projects/{project}/files/{projectFile}/versions/{version}/markups/{markup}', [ProjectDrawingMarkupApiController::class, 'destroy']);
    Route::get('/projects/{project}/files/{projectFile}/versions/{version}/preview', [ProjectDrawingMarkupApiController::class, 'preview']);


    // Phase 4 — BIM Viewer + Clash Detection
    Route::get('/projects/{project}/bim', [ProjectBimApiController::class, 'index'])->middleware('saas.feature:bim_advanced');
    Route::post('/projects/{project}/bim/models', [ProjectBimApiController::class, 'storeModel'])->middleware('saas.feature:bim_advanced');
    Route::post('/projects/{project}/bim/models/{bimModel}/versions', [ProjectBimApiController::class, 'storeVersion'])->middleware('saas.feature:bim_advanced');
    Route::post('/projects/{project}/bim/clash-runs', [ProjectBimApiController::class, 'runClash'])->middleware('saas.feature:bim_advanced');
    Route::post('/projects/{project}/bim/clash-runs/import', [ProjectBimApiController::class, 'importClashes'])->middleware('saas.feature:bim_advanced');
    Route::get('/projects/{project}/bim/clash-runs/{run}', [ProjectBimApiController::class, 'run'])->middleware('saas.feature:bim_advanced');
    Route::patch('/projects/{project}/bim/clash-runs/{run}/clashes/{clash}', [ProjectBimApiController::class, 'updateClash'])->middleware('saas.feature:bim_advanced');
    Route::get('/projects/{project}/bim/versions/{version}/viewer-link', [ProjectBimApiController::class, 'viewerLink'])->middleware('saas.feature:bim_advanced');
    Route::get('/projects/{project}/bim/versions/{version}/download', [ProjectBimApiController::class, 'download'])->middleware('saas.feature:bim_advanced');

    Route::get('/projects/{project}/rfis', [ProjectExecutionApiController::class, 'rfis']);
    Route::post('/projects/{project}/rfis', [ProjectExecutionApiController::class, 'storeRfi']);
    Route::get('/projects/{project}/rfis/{rfi}', [ProjectExecutionApiController::class, 'showRfi']);
    Route::patch('/projects/{project}/rfis/{rfi}/answer', [ProjectExecutionApiController::class, 'answerRfi']);
    Route::post('/projects/{project}/rfis/{rfi}/comments', [ProjectExecutionApiController::class, 'commentRfi']);
    Route::patch('/projects/{project}/rfis/{rfi}/close', [ProjectExecutionApiController::class, 'closeRfi']);
    Route::patch('/projects/{project}/rfis/{rfi}/reopen', [ProjectExecutionApiController::class, 'reopenRfi']);
    Route::patch('/projects/{project}/rfis/{rfi}/cancel', [ProjectExecutionApiController::class, 'cancelRfi']);
    Route::get('/projects/{project}/rfis/{rfi}/attachments/{attachment}/download', [ProjectExecutionApiController::class, 'downloadRfiAttachment']);

    Route::get('/projects/{project}/change-orders', [ProjectExecutionApiController::class, 'changeOrders']);
    Route::post('/projects/{project}/change-orders', [ProjectExecutionApiController::class, 'storeChangeOrder']);
    Route::patch('/projects/{project}/change-orders/{changeOrder}/approve', [ProjectExecutionApiController::class, 'approveChangeOrder']);
    Route::patch('/projects/{project}/change-orders/{changeOrder}/reject', [ProjectExecutionApiController::class, 'rejectChangeOrder']);

    Route::get('/projects/{project}/lifecycle', [ProjectExecutionApiController::class, 'lifecycle']);
    Route::patch('/projects/{project}/lifecycle/start', [ProjectExecutionApiController::class, 'lifecycleStart']);
    Route::patch('/projects/{project}/lifecycle/pause', [ProjectExecutionApiController::class, 'lifecyclePause']);
    Route::patch('/projects/{project}/lifecycle/resume', [ProjectExecutionApiController::class, 'lifecycleResume']);
    Route::patch('/projects/{project}/lifecycle/request-completion', [ProjectExecutionApiController::class, 'lifecycleRequestCompletion']);
    Route::patch('/projects/{project}/lifecycle/approve-completion', [ProjectExecutionApiController::class, 'lifecycleApproveCompletion']);
    Route::patch('/projects/{project}/lifecycle/reject-completion', [ProjectExecutionApiController::class, 'lifecycleRejectCompletion']);
    Route::get('/projects/{project}/final-report', [ProjectExecutionApiController::class, 'finalReport']);

    // محادثة فريق المشروع — نفس محرك الموقع وإرفاقاته
    Route::get('/projects/{project}/team-chat/messages', [ProjectTeamChatController::class, 'messages']);
    Route::post('/projects/{project}/team-chat/messages', [ProjectTeamChatController::class, 'store']);
    Route::post('/projects/{project}/team-chat/read', [ProjectTeamChatController::class, 'read']);
    Route::get('/projects/{project}/team-chat/attachments/{attachment}/download', [ProjectTeamChatController::class, 'downloadAttachment']);
    Route::get('/projects/{project}/team-chat/attachments/{attachment}/stream', [ProjectTeamChatController::class, 'streamAttachment']);


    // المرحلة 14 — الإدارة الهندسية المتقدمة + إعدادات الحساب المطابقة للموقع
    Route::get('/profile/professional-verification', [ProfessionalVerificationApiController::class, 'show']);
    Route::post('/profile/professional-verification/apply', [ProfessionalVerificationApiController::class, 'apply']);
    Route::post('/profile/professional-verification/subscribe', [ProfessionalVerificationApiController::class, 'subscribe']);

    // إدارة التوثيق الاحترافي — مطابقة لوحة الموقع للمدير.
    Route::get('/admin/professional-verification', [AdminProfessionalVerificationApiController::class, 'index']);
    Route::patch('/admin/professional-verification/settings', [AdminProfessionalVerificationApiController::class, 'updateSettings']);
    Route::patch('/admin/professional-verification/applications/{verificationApplication}', [AdminProfessionalVerificationApiController::class, 'reviewApplication']);
    Route::patch('/admin/professional-verification/subscriptions/{verificationSubscription}', [AdminProfessionalVerificationApiController::class, 'reviewSubscription']);
    Route::get('/admin/professional-verification/applications/{verificationApplication}/file/{type}', [AdminProfessionalVerificationApiController::class, 'applicationFile']);
    Route::get('/admin/professional-verification/subscriptions/{verificationSubscription}/receipt', [AdminProfessionalVerificationApiController::class, 'subscriptionReceipt']);

    Route::get('/projects/{project}/submittals', [ProjectAdvancedApiController::class, 'submittals']);
    Route::post('/projects/{project}/submittals', [ProjectAdvancedApiController::class, 'storeSubmittal']);
    Route::get('/projects/{project}/submittals/{submittal}', [ProjectAdvancedApiController::class, 'showSubmittal']);
    Route::patch('/projects/{project}/submittals/{submittal}/review', [ProjectAdvancedApiController::class, 'reviewSubmittal']);
    Route::post('/projects/{project}/submittals/{submittal}/revisions', [ProjectAdvancedApiController::class, 'addSubmittalRevision']);
    Route::patch('/projects/{project}/submittals/{submittal}/{action}', [ProjectAdvancedApiController::class, 'submittalAction'])->whereIn('action', ['close','reopen','cancel']);
    Route::get('/projects/{project}/submittals/{submittal}/attachments/{attachment}/download', [ProjectAdvancedApiController::class, 'downloadSubmittalAttachment']);

    Route::get('/projects/{project}/meetings', [ProjectAdvancedApiController::class, 'meetings']);
    Route::post('/projects/{project}/meetings', [ProjectAdvancedApiController::class, 'storeMeeting']);
    Route::get('/projects/{project}/meetings/{meeting}', [ProjectAdvancedApiController::class, 'showMeeting']);
    Route::patch('/projects/{project}/meetings/{meeting}/minutes', [ProjectAdvancedApiController::class, 'saveMeetingMinutes']);
    Route::patch('/projects/{project}/meetings/{meeting}/minutes/publish', [ProjectAdvancedApiController::class, 'publishMeetingMinutes']);
    Route::get('/projects/{project}/meetings/{meeting}/minutes/pdf', ProjectMeetingMinutesPdfController::class);
    Route::patch('/projects/{project}/meetings/{meeting}/cancel', [ProjectAdvancedApiController::class, 'cancelMeeting']);
    Route::post('/projects/{project}/meetings/{meeting}/actions', [ProjectAdvancedApiController::class, 'addMeetingAction']);
    Route::patch('/projects/{project}/meetings/{meeting}/actions/{actionItem}', [ProjectAdvancedApiController::class, 'updateMeetingAction']);
    Route::get('/projects/{project}/meetings/{meeting}/attachments/{attachment}/download', [ProjectAdvancedApiController::class, 'downloadMeetingAttachment']);


    // LiveKit — نفس غرفة الاجتماع المستخدمة في الموقع، لكن بمصادقة Sanctum للتطبيق.
    Route::prefix('/projects/{project}/meetings/{meeting}/live')
        ->whereNumber('project')
        ->whereNumber('meeting')
        ->scopeBindings()
        ->group(function (): void {
            Route::post('/token', [ProjectMeetingLiveController::class, 'token']);
            Route::post('/start', [ProjectMeetingLiveController::class, 'start']);
            Route::post('/end', [ProjectMeetingLiveController::class, 'end']);
            Route::post('/join', [ProjectMeetingLiveController::class, 'join']);
            Route::post('/leave', [ProjectMeetingLiveController::class, 'leave']);
            Route::get('/messages', [ProjectMeetingLiveController::class, 'messages']);
            Route::post('/messages', [ProjectMeetingLiveController::class, 'sendMessage']);
            Route::get('/invitees', [ProjectMeetingLiveController::class, 'invitees']);
            Route::post('/invite', [ProjectMeetingLiveController::class, 'invite']);
            Route::delete('/participants/{user}', [ProjectMeetingLiveController::class, 'kick'])->whereNumber('user');
            Route::patch('/participants/{user}/track', [ProjectMeetingLiveController::class, 'muteTrack'])->whereNumber('user');
        });

    Route::get('/projects/{project}/gantt-advanced', [ProjectAdvancedApiController::class, 'gantt']);
    Route::post('/projects/{project}/gantt-advanced', [ProjectAdvancedApiController::class, 'storeGantt']);
    Route::patch('/projects/{project}/gantt-advanced/{item}', [ProjectAdvancedApiController::class, 'updateGantt']);
    Route::patch('/projects/{project}/gantt-advanced/{item}/progress', [ProjectAdvancedApiController::class, 'progressGantt']);
    Route::delete('/projects/{project}/gantt-advanced/{item}', [ProjectAdvancedApiController::class, 'destroyGantt']);
    Route::post('/projects/{project}/gantt-advanced/baseline', [ProjectAdvancedApiController::class, 'baselineGantt']);
    Route::post('/projects/{project}/gantt-advanced/dependencies', [ProjectAdvancedApiController::class, 'storeGanttDependency']);
    Route::delete('/projects/{project}/gantt-advanced/dependencies/{dependency}', [ProjectAdvancedApiController::class, 'destroyGanttDependency']);

    Route::get('/projects/{project}/calendar', [ProjectAdvancedApiController::class, 'calendar']);
    Route::post('/projects/{project}/calendar', [ProjectAdvancedApiController::class, 'storeCalendar']);
    Route::patch('/projects/{project}/calendar/{event}', [ProjectAdvancedApiController::class, 'updateCalendar']);
    Route::patch('/projects/{project}/calendar/{event}/{action}', [ProjectAdvancedApiController::class, 'calendarAction'])->whereIn('action', ['complete','cancel']);
    Route::delete('/projects/{project}/calendar/{event}', [ProjectAdvancedApiController::class, 'destroyCalendar']);
    Route::get('/projects/{project}/calendar/export/ics', ProjectCalendarIcsController::class);

    Route::get('/projects/{project}/boqs-advanced', [ProjectAdvancedApiController::class, 'boqs']);
    Route::post('/projects/{project}/boqs-advanced', [ProjectAdvancedApiController::class, 'storeBoq']);
    Route::get('/projects/{project}/boqs-advanced/{boq}', [ProjectAdvancedApiController::class, 'showBoq']);
    Route::patch('/projects/{project}/boqs-advanced/{boq}/{action}', [ProjectAdvancedApiController::class, 'boqAction'])->whereIn('action', ['submit-review','return-draft','approve','lock','revision']);
    Route::delete('/projects/{project}/boqs-advanced/{boq}', [ProjectAdvancedApiController::class, 'destroyBoq']);
    Route::post('/projects/{project}/boqs-advanced/{boq}/sections', [ProjectAdvancedApiController::class, 'storeBoqSection']);
    Route::patch('/projects/{project}/boqs-advanced/{boq}/sections/{section}', [ProjectAdvancedApiController::class, 'updateBoqSection']);
    Route::delete('/projects/{project}/boqs-advanced/{boq}/sections/{section}', [ProjectAdvancedApiController::class, 'destroyBoqSection']);
    Route::post('/projects/{project}/boqs-advanced/{boq}/items', [ProjectAdvancedApiController::class, 'storeBoqItem']);
    Route::patch('/projects/{project}/boqs-advanced/{boq}/items/{item}', [ProjectAdvancedApiController::class, 'updateBoqItem']);
    Route::delete('/projects/{project}/boqs-advanced/{boq}/items/{item}', [ProjectAdvancedApiController::class, 'destroyBoqItem']);
    Route::post('/projects/{project}/boqs-advanced/{boq}/items/{item}/progress', [ProjectAdvancedApiController::class, 'progressBoqItem']);
    Route::get('/projects/{project}/boqs-advanced/import/template', [ProjectBoqExportController::class, 'template']);
    Route::get('/projects/{project}/boqs-advanced/{boq}/pdf', [ProjectBoqExportController::class, 'pdf']);
    Route::get('/projects/{project}/boqs-advanced/{boq}/csv', [ProjectBoqExportController::class, 'csv']);
    Route::post('/projects/{project}/boqs-advanced/{boq}/import/csv', [ProjectAdvancedApiController::class, 'importBoqCsv']);


    // المطابقة النهائية — المصروفات والموردون والميزانيات
    Route::get('/finance/expenses/dashboard', [ExpenseApiController::class, 'dashboard']);
    Route::get('/finance/expenses', [ExpenseApiController::class, 'index']);
    Route::get('/finance/expenses/options', [ExpenseApiController::class, 'formOptions']);
    Route::post('/finance/expenses', [ExpenseApiController::class, 'store']);
    Route::get('/finance/expenses/{expense}', [ExpenseApiController::class, 'show']);
    Route::post('/finance/expenses/{expense}', [ExpenseApiController::class, 'update']);
    Route::patch('/finance/expenses/{expense}/{action}', [ExpenseApiController::class, 'action'])->whereIn('action', ['submit','cancel','approve','reject','return','paid']);
    Route::get('/finance/expense-attachments/{attachment}/download', [ExpenseApiController::class, 'downloadAttachment']);
    Route::get('/finance/expense-categories', [ExpenseApiController::class, 'categories']);
    Route::post('/finance/expense-categories', [ExpenseApiController::class, 'storeCategory']);
    Route::patch('/finance/expense-categories/{category}', [ExpenseApiController::class, 'updateCategory']);
    Route::get('/finance/vendors', [ExpenseApiController::class, 'vendors']);
    Route::post('/finance/vendors', [ExpenseApiController::class, 'storeVendor']);
    Route::patch('/finance/vendors/{vendor}', [ExpenseApiController::class, 'updateVendor']);

    // Field / Site Management — Phase 2 (offline-first compatible)
    Route::get('/projects/{project}/field', [ProjectFieldApiController::class, 'index']);
    Route::post('/projects/{project}/field', [ProjectFieldApiController::class, 'store']);
    Route::post('/projects/{project}/field/sync', [ProjectFieldApiController::class, 'sync']);
    Route::get('/projects/{project}/field/{fieldRecord}', [ProjectFieldApiController::class, 'show']);
    Route::patch('/projects/{project}/field/{fieldRecord}', [ProjectFieldApiController::class, 'update']);
    Route::patch('/projects/{project}/field/{fieldRecord}/status', [ProjectFieldApiController::class, 'status']);
    Route::post('/projects/{project}/field/{fieldRecord}/attachments', [ProjectFieldApiController::class, 'attachment']);
    Route::get('/projects/{project}/field/{fieldRecord}/attachments/{attachment}', [ProjectFieldApiController::class, 'download']);

    Route::get('/finance/projects/{project}/budget', [ExpenseApiController::class, 'budget']);
    Route::post('/finance/projects/{project}/budget', [ExpenseApiController::class, 'saveBudget']);
    Route::post('/finance/projects/{project}/budget/items', [ExpenseApiController::class, 'storeBudgetItem']);
    Route::patch('/finance/projects/{project}/budget/items/{item}', [ExpenseApiController::class, 'updateBudgetItem']);
    Route::delete('/finance/projects/{project}/budget/items/{item}', [ExpenseApiController::class, 'destroyBudgetItem']);

    // مالية المكتب — نفس منطق الموقع
    Route::get('/office/finance', [OfficeFinanceApiController::class, 'office'])->middleware('office.owner');
    Route::patch('/office/finance/consultations/{consultation}/engineer-percentage', [OfficeFinanceApiController::class, 'setConsultationEngineerPercentage'])->middleware('office.owner');
    Route::patch('/office/finance/consultation-engineer-earnings/{earning}/paid', [OfficeFinanceApiController::class, 'markConsultationEngineerPaid'])->middleware('office.owner');
    Route::patch('/office/finance/project-engineer-earnings/{earning}/paid', [OfficeFinanceApiController::class, 'markProjectEngineerPaid'])->middleware('office.owner');
    Route::get('/admin/office-finance', [OfficeFinanceApiController::class, 'admin']);
    Route::patch('/admin/office-finance/consultations/{consultation}/percentage', [OfficeFinanceApiController::class, 'setAdminConsultationPercentage']);
    Route::patch('/admin/office-finance/consultation-financials/{financial}/paid', [OfficeFinanceApiController::class, 'markAdminConsultationOfficePaid']);
    Route::patch('/admin/office-finance/projects/{project}/percentage', [OfficeFinanceApiController::class, 'setAdminProjectPercentage']);

    // استرداد الحساب — موظف الدعم المصرح له + المدير
    Route::get('/account-recovery/support', [AccountRecoveryApiController::class, 'supportIndex'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::get('/account-recovery/support/{recovery}', [AccountRecoveryApiController::class, 'supportShow'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/claim', [AccountRecoveryApiController::class, 'claim'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/verify-identity', [AccountRecoveryApiController::class, 'verifyIdentity'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/face-verification/start', [AccountRecoveryApiController::class, 'startFaceVerification'])->middleware('throttle:biometric-start')->middleware(['support.recovery.bridge','support.2fa']);
    Route::get('/account-recovery/support/{recovery}/face-verification/status', [AccountRecoveryApiController::class, 'faceVerificationStatus'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/restore', [AccountRecoveryApiController::class, 'restore'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/issue-temporary-password', [AccountRecoveryApiController::class, 'issueTemporaryPassword'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::get('/account-recovery/support/{recovery}/evidence/{evidence}', [AccountRecoveryApiController::class, 'evidence'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::post('/account-recovery/support/{recovery}/reject', [AccountRecoveryApiController::class, 'reject'])->middleware(['support.recovery.bridge','support.2fa']);
    Route::patch('/account-recovery/agents/{user}', [AccountRecoveryApiController::class, 'agentPermission']);

    // المرحلة 11 — المكاتب الهندسية
    Route::post('/offices/{office}/reviews', [OfficePublicContentApiController::class, 'storeReview']);

    Route::get('/office/portfolio', [OfficePublicContentApiController::class, 'myWorks'])->middleware('office.manager');
    Route::post('/office/portfolio', [OfficePublicContentApiController::class, 'storeWork'])->middleware('office.manager');
    Route::post('/office/portfolio/{officeWork}', [OfficePublicContentApiController::class, 'updateWork'])->middleware('office.manager');
    Route::delete('/office/portfolio/{officeWork}', [OfficePublicContentApiController::class, 'destroyWork'])->middleware('office.manager');

    Route::get('/office-application/status', [OfficeApiController::class, 'applicationStatus']);
    Route::post('/office-application', [OfficeApiController::class, 'storeApplication']);

    Route::get('/office-membership-applications/mine', [OfficeApiController::class, 'myMembershipApplications']);
    Route::get('/office-membership-applications/{officeMembershipApplication}/file/{type}', [OfficeApiController::class, 'membershipApplicationFile'])
        ->whereIn('type', ['cv', 'certificate']);
    Route::post('/offices/{office}/membership-applications', [OfficeApiController::class, 'joinOffice']);

    Route::get('/office/dashboard', [OfficeApiController::class, 'dashboard'])->middleware('office.manager');
    Route::get('/office/field-management', [OfficeApiController::class, 'fieldManagement'])->middleware('office.manager');
    Route::get('/office/drawing-reviews', [OfficeApiController::class, 'drawingReviews'])->middleware('office.manager');
    Route::get('/engineer/field-management', [EngineerWorkspaceApiController::class, 'fieldManagement']);
    Route::get('/engineer/drawing-reviews', [EngineerWorkspaceApiController::class, 'drawingReviews']);
    Route::post('/office/profile', [OfficeApiController::class, 'updateProfile'])->middleware('office.manager');
    Route::patch('/office/members/{officeMember}', [OfficeApiController::class, 'updateMember'])->middleware('office.manager');
    Route::delete('/office/members/{officeMember}', [OfficeApiController::class, 'removeMember'])->middleware('office.manager');
    Route::patch('/office/membership-applications/{officeMembershipApplication}/review', [OfficeApiController::class, 'reviewMembership'])->middleware('office.manager');
    Route::get('/office/subscription', [OfficeApiController::class, 'subscription'])->middleware('office.owner');
    Route::post('/office/subscription', [OfficeApiController::class, 'storeSubscription'])->middleware('office.owner');
    Route::post('/office/subscription/cancel', [OfficeApiController::class, 'cancelSubscription'])->middleware('office.owner');
    Route::post('/office/subscription/resume', [OfficeApiController::class, 'resumeSubscription'])->middleware('office.owner');
    Route::patch('/office/consultations/{consultation}/assign-engineer', [OfficeApiController::class, 'assignEngineer'])->middleware('office.operational');

    Route::get('/payout-account/mine', [PayoutAccountApiController::class, 'mine']);
    Route::post('/payout-account/mine', [PayoutAccountApiController::class, 'storeMine']);
    Route::get('/office/payout-account', [PayoutAccountApiController::class, 'office'])->middleware('office.owner');
    Route::post('/office/payout-account', [PayoutAccountApiController::class, 'storeOffice'])->middleware('office.owner');
    Route::get('/admin/payout-accounts', [PayoutAccountApiController::class, 'adminIndex']);
    Route::patch('/admin/payout-accounts/{account}/verify', [PayoutAccountApiController::class, 'verify']);
    Route::patch('/admin/payout-accounts/{account}/reject', [PayoutAccountApiController::class, 'reject']);

    Route::get('/admin/office-applications', [AdminOfficeApiController::class, 'applications']);
    Route::patch('/admin/office-applications/{officeApplication}/review', [AdminOfficeApiController::class, 'reviewApplication']);
    Route::get('/admin/office-subscriptions', [AdminOfficeApiController::class, 'subscriptions']);
    Route::patch('/admin/office-subscriptions/{officeSubscription}/review', [AdminOfficeApiController::class, 'reviewSubscription']);
    Route::get('/admin/office-subscriptions/{officeSubscription}/receipt', [AdminOfficeApiController::class, 'subscriptionReceipt']);
    Route::get('/admin/offices', [AdminOfficeApiController::class, 'offices']);
    Route::patch('/admin/offices/{office}/status', [AdminOfficeApiController::class, 'updateOfficeStatus']);
    Route::get('/admin/saas/plans', [AdminSaasPlanApiController::class, 'index']);
    Route::patch('/admin/saas/plans/{saasPlan}', [AdminSaasPlanApiController::class, 'update']);
    Route::put('/admin/offices/{office:slug}/saas-plan', [AdminSaasPlanApiController::class, 'assignOffice']);
    Route::get('/admin/consultation-office-assignments', [AdminOfficeApiController::class, 'consultationAssignments']);
    Route::patch('/admin/consultations/{consultation}/assign-office', [AdminOfficeApiController::class, 'assignConsultation']);
    Route::delete('/admin/consultations/{consultation}/assign-office', [AdminOfficeApiController::class, 'unassignConsultation']);


    // المرحلة 16 — سوق المشاريع (Native parity)
    Route::get('/marketplace/projects', [MarketplaceApiController::class, 'index']);
    Route::post('/marketplace/projects', [MarketplaceApiController::class, 'store']);
    Route::get('/marketplace/projects/{marketplaceProjectRequest}', [MarketplaceApiController::class, 'show']);
    Route::patch('/marketplace/projects/{marketplaceProjectRequest}/close', [MarketplaceApiController::class, 'close']);
    Route::patch('/marketplace/projects/{marketplaceProjectRequest}/cancel', [MarketplaceApiController::class, 'cancel']);
    Route::post('/marketplace/projects/{marketplaceProjectRequest}/quotations', [MarketplaceApiController::class, 'submitQuotation']);
    Route::patch('/marketplace/projects/{marketplaceProjectRequest}/quotations/{quotation}', [MarketplaceApiController::class, 'updateQuotation']);
    Route::patch('/marketplace/projects/{marketplaceProjectRequest}/quotations/{quotation}/withdraw', [MarketplaceApiController::class, 'withdrawQuotation']);
    Route::patch('/marketplace/projects/{marketplaceProjectRequest}/quotations/{quotation}/accept', [MarketplaceApiController::class, 'acceptQuotation']);
    Route::get('/marketplace/projects/{marketplaceProjectRequest}/files/{file}/download', [MarketplaceApiController::class, 'downloadRequestFile']);
    Route::get('/marketplace/projects/{marketplaceProjectRequest}/quotations/{quotation}/attachment', [MarketplaceApiController::class, 'downloadQuotationAttachment']);

    // المرحلة 15 — المطابقة النهائية: الآراء والملاحظات + الإشراف + الطعون
    Route::get('/feedback/mine', [FinalizationApiController::class, 'myFeedback']);
    Route::post('/feedback', [FinalizationApiController::class, 'storeFeedback']);

    Route::get('/moderation/appeal', [FinalizationApiController::class, 'myAppeal']);
    Route::post('/moderation/appeal', [FinalizationApiController::class, 'storeAppeal']);
    Route::delete('/moderation/appeal/{appeal}', [FinalizationApiController::class, 'cancelAppeal']);
    Route::get('/moderation/appeal/{appeal}/attachment', [FinalizationApiController::class, 'appealAttachment']);

    Route::get('/admin/feedback', [FinalizationApiController::class, 'adminFeedback']);
    Route::patch('/admin/feedback/{platformFeedback}/{action}', [FinalizationApiController::class, 'adminFeedbackAction'])
        ->whereIn('action', ['approve','reject','archive','featured']);
    Route::patch('/admin/feedback/{platformFeedback}/reply', [FinalizationApiController::class, 'adminFeedbackReply']);

    Route::get('/admin/moderation', [FinalizationApiController::class, 'moderation']);
    Route::patch('/admin/moderation/warnings/{warning}/{action}', [FinalizationApiController::class, 'warningAction'])
        ->whereIn('action', ['confirm','cancel']);
    Route::patch('/admin/moderation/users/{user}/{action}', [FinalizationApiController::class, 'suspendedUserAction'])
        ->whereIn('action', ['reactivate','keep-suspended']);
    Route::patch('/admin/moderation-appeals/{appeal}/{action}', [FinalizationApiController::class, 'adminAppealAction'])
        ->whereIn('action', ['start-review','approve','reject']);

    // SaaS Phase 4 — payment orchestration / payouts / dispute review
    Route::get('/admin/platform-payment-methods', [PlatformPaymentMethodApiController::class, 'adminIndex']);
    Route::post('/admin/platform-payment-methods', [PlatformPaymentMethodApiController::class, 'store']);
    Route::put('/admin/platform-payment-methods/{platformPaymentMethod}', [PlatformPaymentMethodApiController::class, 'update']);
    Route::delete('/admin/platform-payment-methods/{platformPaymentMethod}', [PlatformPaymentMethodApiController::class, 'destroy']);
    Route::get('/admin/payout-queue', [PayoutQueueApiController::class, 'index']);
    Route::post('/admin/payout-queue/engineers/{earning}', [PayoutQueueApiController::class, 'engineer']);
    Route::post('/admin/payout-queue/offices/{earning}', [PayoutQueueApiController::class, 'office']);
    Route::post('/admin/payout-queue/transactions/{transaction}/confirm', [PayoutQueueApiController::class, 'confirmExternal']);
    Route::get('/admin/conversation-reviews', [ConversationReviewApiController::class, 'index']);
    Route::get('/admin/conversation-reviews/{kind}/{id}', [ConversationReviewApiController::class, 'show'])->whereIn('kind', ['conversation','project']);


    // SaaS Phase 5 — disputes, refund control and financial center
    Route::get('/disputes', [DisputeCaseApiController::class, 'index']);
    Route::post('/disputes', [DisputeCaseApiController::class, 'store']);
    Route::get('/disputes/{disputeCase}', [DisputeCaseApiController::class, 'show']);
    Route::post('/disputes/{disputeCase}/messages', [DisputeCaseApiController::class, 'message']);
    Route::patch('/admin/disputes/{disputeCase}/review', [DisputeCaseApiController::class, 'review']);
    Route::get('/admin/refunds', [AdminRefundApiController::class, 'index']);
    Route::patch('/admin/refunds/{refund}/processing', [AdminRefundApiController::class, 'processing']);
    Route::patch('/admin/refunds/{refund}/complete', [AdminRefundApiController::class, 'complete']);
    Route::patch('/admin/refunds/{refund}/reject', [AdminRefundApiController::class, 'reject']);
    Route::get('/admin/financial-control', [FinancialControlApiController::class, 'index']);

    // SaaS Phase 6 — SLA automation and escalations
    Route::get('/sla-center', [SlaCenterApiController::class, 'index']);
    Route::patch('/sla-center/items/{item}/acknowledge', [SlaCenterApiController::class, 'acknowledge']);
    Route::patch('/admin/sla-rules/{rule}', [SlaCenterApiController::class, 'updateRule']);

    // Phase 9.5 — Assistant Settings / Personalization
    Route::get('/assistant-settings', [AssistantSettingsController::class, 'show']);
    Route::patch('/assistant-settings', [AssistantSettingsController::class, 'update']);

    // SaaS Phase 8 — AI Premium, Credits & Billing
    Route::get('/ai-premium', [AiPremiumApiController::class, 'index']);
    Route::post('/ai-premium/analyze', [AiPremiumApiController::class, 'analyzeFile']);
    Route::post('/ai-premium/plans/purchase', [AiPremiumApiController::class, 'purchasePlan']);
    Route::post('/ai-premium/credits/purchase', [AiPremiumApiController::class, 'purchaseCredits']);
    Route::patch('/ai-premium/orders/{order}/cancel', [AiPremiumApiController::class, 'cancel']);
    Route::get('/admin/ai-premium', [AiPremiumApiController::class, 'adminIndex']);
    Route::patch('/admin/ai-premium/settings', [AiPremiumApiController::class, 'updateSettings']);
    Route::patch('/admin/ai-premium/orders/{order}/approve', [AiPremiumApiController::class, 'approve']);
    Route::patch('/admin/ai-premium/orders/{order}/reject', [AiPremiumApiController::class, 'reject']);
    Route::patch('/admin/ai-premium/wallets/{wallet}/adjust', [AiPremiumApiController::class, 'adjustWallet']);
    Route::patch('/admin/ai-premium/plans/{plan}', [AiPremiumApiController::class, 'updatePlan']);
    Route::patch('/admin/ai-premium/credit-packages/{package}', [AiPremiumApiController::class, 'updatePackage']);

    // SaaS Phase 7 — Project Handover & Acceptance
    Route::get('/projects/{project}/handover', [ProjectHandoverApiController::class, 'index']);
    Route::post('/projects/{project}/handover', [ProjectHandoverApiController::class, 'store']);
    Route::patch('/projects/{project}/handover/{handover}/items/{item}', [ProjectHandoverApiController::class, 'updateItem']);
    Route::post('/projects/{project}/handover/{handover}/attachments', [ProjectHandoverApiController::class, 'upload']);
    Route::get('/projects/{project}/handover/{handover}/attachments/{attachment}', [ProjectHandoverApiController::class, 'download']);
    Route::delete('/projects/{project}/handover/{handover}/attachments/{attachment}', [ProjectHandoverApiController::class, 'destroyAttachment']);
    Route::patch('/projects/{project}/handover/{handover}/cancel', [ProjectHandoverApiController::class, 'cancel']);
    Route::post('/projects/{project}/handover/{handover}/submit', [ProjectHandoverApiController::class, 'submit']);
    Route::patch('/projects/{project}/handover/{handover}/accept', [ProjectHandoverApiController::class, 'accept']);
    Route::patch('/projects/{project}/handover/{handover}/request-changes', [ProjectHandoverApiController::class, 'requestChanges']);
    Route::get('/projects/{project}/handover/{handover}/certificate', [ProjectHandoverApiController::class, 'certificate']);


});

// Production hardening / commercial SaaS routes (Phases 8–15).
require __DIR__ . '/production.php';


/* KYC / Identity Verification */
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/kyc', [KycApiController::class, 'index']);
    Route::post('/kyc/face-verification/prepare', [KycApiController::class, 'prepareFaceVerification'])->middleware('throttle:biometric-start');
    Route::post('/kyc/face-verification/start', [KycApiController::class, 'startFaceVerification'])->middleware('throttle:biometric-start');
    Route::get('/kyc/face-verification/status', [KycApiController::class, 'faceVerificationStatus']);
    Route::post('/kyc/face-verification/local-check-step', [KycApiController::class, 'checkLocalFaceStep'])->middleware('throttle:biometric-step');
    Route::post('/kyc/face-verification/local-submit', [KycApiController::class, 'submitLocalFaceVerification'])->middleware('throttle:biometric-submit');
    Route::post('/kyc/user', [KycApiController::class, 'submitUser']);
    Route::post('/kyc/offices/{office:id}', [KycApiController::class, 'submitOffice']);
    Route::get('/kyc/documents/{document}', [KycApiController::class, 'document']);

    Route::get('/admin/kyc', [AdminKycApiController::class, 'index']);
    Route::get('/admin/kyc/documents/{document}', [AdminKycApiController::class, 'document']);
    Route::patch('/admin/kyc/documents/{document}/review', [AdminKycApiController::class, 'reviewDocument']);
    Route::get('/admin/kyc/{profile}', [AdminKycApiController::class, 'show']);
    Route::patch('/admin/kyc/{profile}/review', [AdminKycApiController::class, 'review']);
});

// AlWaleed V23
require __DIR__.'/v23-api.php';

// AlWaleed V24 Support Enterprise Suite
require __DIR__.'/v24-support-api.php';

require __DIR__.'/v25-support-api.php';

require_once __DIR__.'/v25-4-ai-mail-api.php';


// V25.6 — Financial Manager Center (NO DB)
require __DIR__ . '/v25-financial-manager-api.php';

require_once __DIR__.'/v25-11-platform-commission-api.php';

require __DIR__ . '/v25-13-report-center-api.php';

// AlWaleed Wallet: isolated routes; no changes to existing payment endpoints.
require_once __DIR__.'/alwaleed-wallet-api.php';

// Didit KYC (hosted identity verification)
require_once __DIR__.'/didit-api.php';

// v30: Account archive restore endpoints: guest access, strict throttling.
\Illuminate\Support\Facades\Route::post('/account-archive/restore-otp', [\App\Http\Controllers\Api\AccountArchiveApiController::class,'requestRestore'])->middleware('throttle:3,15');
\Illuminate\Support\Facades\Route::post('/account-archive/restore', [\App\Http\Controllers\Api\AccountArchiveApiController::class,'restore'])->middleware('throttle:5,15');
\Illuminate\Support\Facades\Route::get('/admin/account-archive', [\App\Http\Controllers\Api\AccountArchiveApiController::class,'archiveIndex'])->middleware('auth:sanctum');

// v26: Support tools (auto assignment, Email + WhatsApp channels, attachment scanning)
require_once __DIR__.'/v26-support-tools-api.php';
