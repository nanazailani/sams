<?php

namespace App\Models;


use Illuminate\Database\Eloquent\Model;

class ModuleAttendanceCode extends Model
{
    protected $fillable = [
        'module_session_id',
        'code',
        'expires_at',
        'generated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];
}
