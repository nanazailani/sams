<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('module_attendances')) {
            Schema::create('module_attendances', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('student_id');
                $table->unsignedBigInteger('module_session_id');
                $table->enum('status', ['present', 'late', 'absent'])->default('present');
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->string('location_name')->nullable();
                $table->timestamps();

                $table->foreign('student_id')
                    ->references('id')->on('students')
                    ->onDelete('cascade');

                $table->foreign('module_session_id')
                    ->references('id')->on('module_sessions')
                    ->onDelete('cascade');

                $table->unique(['student_id', 'module_session_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('module_attendances');
    }
};
