<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WeekLock extends Model
{
    protected $fillable = ['is_locked', 'locked_at'];

    protected $casts = [
        'is_locked' => 'boolean',
        'locked_at' => 'datetime',
    ];
}