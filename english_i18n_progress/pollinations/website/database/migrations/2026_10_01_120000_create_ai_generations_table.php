<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('ai_generations')) {
            return;
        }

        // One row per image/video generation request: processing → completed | failed.
        Schema::create('ai_generations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->index();
            $table->unsignedBigInteger('project_id')->nullable()->index();
            $table->unsignedBigInteger('support_ticket_id')->nullable()->index();
            $table->unsignedBigInteger('support_message_id')->nullable();
            $table->unsignedBigInteger('ai_usage_log_id')->nullable();
            $table->string('type', 30);            // text_to_image | image_to_image | text_to_video | image_to_video
            $table->string('kind', 30)->nullable(); // architectural | interior | exterior | landscape | enhance | redesign | general
            $table->string('provider', 40)->nullable();
            $table->string('model', 120)->nullable();
            $table->text('prompt');
            $table->string('status', 20)->default('processing')->index(); // processing | completed | failed
            $table->string('output_path', 500)->nullable(); // private platform storage (local disk)
            $table->string('output_url', 1000)->nullable();
            $table->string('output_mime', 100)->nullable();
            $table->unsignedBigInteger('output_size')->nullable();
            $table->string('error_code', 40)->nullable();
            $table->string('error_message', 500)->nullable(); // safe, user-facing reason only
            $table->json('metadata')->nullable();            // safe details only (never keys or raw provider bodies)
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_generations');
    }
};
