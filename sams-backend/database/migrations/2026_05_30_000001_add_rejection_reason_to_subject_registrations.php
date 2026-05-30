<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subject_registrations', function (Blueprint $table) {
            if (!Schema::hasColumn('subject_registrations', 'rejection_reason')) {
                $table->text('rejection_reason')->nullable()->after('approval_status');
            }
        });
    }

    public function down(): void
    {
        Schema::table('subject_registrations', function (Blueprint $table) {
            if (Schema::hasColumn('subject_registrations', 'rejection_reason')) {
                $table->dropColumn('rejection_reason');
            }
        });
    }
};
