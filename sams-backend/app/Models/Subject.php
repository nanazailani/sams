<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Subject extends Model
{
    //field subject/course yang boleh mass assign dari controller.
    //lecturer_id simpan lecturer utama supaya dashboard lecturer boleh detect course.
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

    //subject belongs to lecturer utama yang assigned masa add/edit course.
    public function lecturer()
    {
        return $this->belongsTo(Lecturer::class);
    }
}
