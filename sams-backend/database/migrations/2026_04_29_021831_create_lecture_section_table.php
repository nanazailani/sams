<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('lecture_section')) {
            Schema::create('lecture_section', function (Blueprint $table) {
                $table->id();
                $table->string('section_name', 50);
                $table->unsignedBigInteger('subject_id');
                $table->unsignedBigInteger('lecturer_id')->nullable();
                $table->string('room', 50)->nullable();
                $table->integer('capacity')->default(0);

                // Foreign keys
                $table->foreign('subject_id')
                    ->references('id')
                    ->on('subjects')
                    ->onDelete('cascade');

                $table->foreign('lecturer_id')
                    ->references('id')
                    ->on('users')
                    ->onDelete('set null');

                $table->timestamps(); // ✅ penting
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('lecture_section');
    }
};
