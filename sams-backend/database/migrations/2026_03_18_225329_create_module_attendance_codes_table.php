<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up()
    {
        if (!Schema::hasTable('module_attendance_codes')) {
            Schema::create('module_attendance_codes', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('module_session_id');
                $table->string('code');
                $table->timestamp('expires_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('module_attendance_codes');
    }
};
