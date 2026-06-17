<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable
{
    //field account yang boleh diisi untuk login profile semua role.
    //role bezakan student, lecturer, registrar, treasurer, and pusat_adab.
    protected $fillable = [
        'name',
        'email',
        'password',
        'updated_at',
        'created_at',
        'role',
        'matric_number',
    ];

    //satu user student akan ada satu row tambahan dalam students table.
    public function student()
    {
        return $this->hasOne(Student::class);
    }

    //satu user lecturer akan ada satu row tambahan dalam lecturers table.
    public function lecturer()
    {
        return $this->hasOne(Lecturer::class);
    }
}
