<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SubjectRegistration extends Model
{
    //guna table subject_registrations sebab nama model tak ikut plural default Laravel.
    protected $table = 'subject_registrations';

    //field registration yang boleh diisi masa student daftar subject.
    //approval_status/rejection_reason digunakan oleh faculty registrar approval flow.
    protected $fillable = [
        'student_id',
        'subject_id',
        'staff_id',
        'section',
        'tutorial_lab',
        'approval_status',
        'rejection_reason',
        'registrar_id',
    ];

    //link registration ni kepada student/user yang daftar subject.
    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    //link registration ni kepada subject yang dipilih student.
    public function subject()
    {
        return $this->belongsTo(Subject::class, 'subject_id');
    }
}
