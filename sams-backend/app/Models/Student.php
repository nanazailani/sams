<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Student extends Model
{
    //field yang boleh diisi masa create/update student profile.
    //user_id link student record ni dengan account dalam users table.
    protected $fillable = [
        'user_id',
        'matric_no',
        'programme',
        'year',
    ];

    //relation balik ke User, sebab nama/email/login detail simpan dekat users table.
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
