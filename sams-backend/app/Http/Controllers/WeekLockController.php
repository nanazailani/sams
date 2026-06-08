<?php

namespace App\Http\Controllers;

use App\Models\WeekLock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WeekLockController extends Controller
{
    // GET /api/week-lock/status
    public function status(Request $request)
{
    $lock = WeekLock::first();
    $isLocked = $lock ? $lock->is_locked : false;

    $studentBlocked = false;

    if ($isLocked) {
        $studentId = $request->query('student_id');

        if ($studentId) {
            $student = DB::table('students')
                ->where('id', $studentId)
                ->first();

            $totalFee = 0;
            if ($student) {
                $tuitionFee = DB::table('tuition_fees')
                    ->where('programme', $student->programme)
                    ->first();

                if ($tuitionFee) {
                    $hostelFee = $student->hostel ? $tuitionFee->hostel_fee : 0;
                    $totalFee = $tuitionFee->tuition_fee + $hostelFee;
                }
            }

            $totalPaid = DB::table('payments')
                ->where('student_id', $studentId)
                ->where('status', 'Approved')
                ->sum('amount');

            $studentBlocked = $totalPaid < $totalFee;

        }
    }

    return response()->json([
        'is_locked'       => $isLocked,
        'student_blocked' => $studentBlocked,
        'locked_at'       => $lock?->locked_at,
    ]);
}

    // POST /api/week-lock/lock  (Treasurer locks access)
    public function lock()
    {
        $lock = WeekLock::first();

        if (!$lock) {
            $lock = new WeekLock();
        }

        $lock->is_locked = true;
        $lock->locked_at = now();
        $lock->save();

        return response()->json([
            'message'   => 'Access locked successfully.',
            'is_locked' => true,
            'locked_at' => $lock->locked_at,
        ]);
    }

    // POST /api/week-lock/unlock  (Treasurer unlocks access)
    public function unlock()
    {
        $lock = WeekLock::first();

        if (!$lock) {
            $lock = new WeekLock();
        }

        $lock->is_locked = false;
        $lock->locked_at = null;
        $lock->save();

        return response()->json([
            'message'   => 'Access unlocked successfully.',
            'is_locked' => false,
        ]);
    }
}