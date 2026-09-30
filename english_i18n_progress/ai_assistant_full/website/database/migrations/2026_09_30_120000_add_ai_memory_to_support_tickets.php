<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_tickets', function (Blueprint $table) {
            // Running summary of the part of a long AI conversation the model no longer sees word for word.
            if (! Schema::hasColumn('support_tickets', 'ai_memory_summary')) {
                $table->longText('ai_memory_summary')->nullable();
            }
            if (! Schema::hasColumn('support_tickets', 'ai_memory_upto_id')) {
                $table->unsignedBigInteger('ai_memory_upto_id')->nullable();
            }
            // A very long conversation continues in a new one that points back to it.
            if (! Schema::hasColumn('support_tickets', 'continued_from_ticket_id')) {
                $table->unsignedBigInteger('continued_from_ticket_id')->nullable()->index();
            }
        });
    }

    public function down(): void
    {
        Schema::table('support_tickets', function (Blueprint $table) {
            foreach (['ai_memory_summary', 'ai_memory_upto_id', 'continued_from_ticket_id'] as $column) {
                if (Schema::hasColumn('support_tickets', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
