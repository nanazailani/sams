<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AttendanceCode extends Model
{
    //
    protected $fillable = [
        'class_session_id',
        'code',
        'expires_at',
        'generated_at',
    ];
}
