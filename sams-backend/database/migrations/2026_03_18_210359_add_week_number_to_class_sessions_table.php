<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('class_sessions', function (Blueprint $table) {
            if (!Schema::hasColumn('class_sessions', 'week_number')) {
                $table->unsignedInteger('week_number')->nullable()->after('subject_id');
            }
        });
    }

    public function down(): void
    {
        Schema::table('class_sessions', function (Blueprint $table) {
            $table->dropColumn('week_number');
        });
    }
};
