<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subject_registrations', function (Blueprint $table) {

            if (!Schema::hasColumn('subject_registrations', 'approval_status')) {
                $table->enum('approval_status', ['Pending', 'Approved', 'Rejected'])
                    ->default('Pending');
            }

            if (!Schema::hasColumn('subject_registrations', 'registrar_id')) {
                $table->unsignedBigInteger('registrar_id')->nullable();

                // Foreign key
                $table->foreign('registrar_id')
                    ->references('id')
                    ->on('faculty_registrar')
                    ->onDelete('set null');
            }
        });
    }

    public function down(): void
    {
        Schema::table('subject_registrations', function (Blueprint $table) {
            $table->dropForeign(['registrar_id']);
            $table->dropColumn(['approval_status', 'registrar_id']);
        });
    }
};
