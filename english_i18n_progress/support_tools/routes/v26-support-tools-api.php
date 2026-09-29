<?php

use App\Http\Controllers\Api\SupportToolsApiController;
use Illuminate\Support\Facades\Route;

// أدوات الدعم: التوزيع التلقائي، قنوات Email + WhatsApp، فحص المرفقات.
Route::middleware(['auth:sanctum', 'support.2fa'])->prefix('support-tools')->group(function () {
    Route::get('/assignment', [SupportToolsApiController::class, 'assignment']);
    Route::patch('/assignment/staff/{profile}', [SupportToolsApiController::class, 'updateStaff']);
    Route::post('/assignment/run', [SupportToolsApiController::class, 'runAssignment']);

    Route::get('/channels', [SupportToolsApiController::class, 'channels']);
    Route::post('/channels/inbound/{inbound}/retry', [SupportToolsApiController::class, 'retryInbound']);

    Route::get('/attachments', [SupportToolsApiController::class, 'attachments']);
    Route::post('/attachments/{message}/rescan', [SupportToolsApiController::class, 'rescan']);
});
