<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('support_messages', 'ai_thinking')) {
            Schema::table('support_messages', function (Blueprint $table) {
                // Thought summary returned by the model with the answer (shown as "thinking").
                $table->text('ai_thinking')->nullable();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('support_messages', 'ai_thinking')) {
            Schema::table('support_messages', function (Blueprint $table) {
                $table->dropColumn('ai_thinking');
            });
        }
    }
};
