<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Subject extends Model
{
    protected $fillable = [
        'code',
        'name',
        'credit_hour',
        'lecturer_id',  
        'examination',
        'exam_date',
        'exam_period',
        'exam_time',
        'registrar_id',
    ];

    public function lecturer()
    {
        return $this->belongsTo(Lecturer::class);
    }
}
