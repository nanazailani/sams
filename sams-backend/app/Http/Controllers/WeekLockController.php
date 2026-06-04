<?php

namespace App\Http\Controllers;

use App\Models\WeekLock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WeekLockController extends Controller
{
    // GET /api/week-lock/status
    // Returns the global lock status + whether this specific student is blocked
    public function status(Request $request)
    {
        $lock = WeekLock::first();
        $isLocked = $lock ? $lock->is_locked : false;

        $studentBlocked = false;

        if ($isLocked) {
            $studentId = $request->query('student_id');

            if ($studentId) {
                // Get tuition_fee_id from this student's payments
                $payment = DB::table('payments')
                    ->where('student_id', $studentId)
                    ->first();

                $totalFee = 0;
                if ($payment) {
                    $tuitionFee = DB::table('tuition_fees')
                        ->where('id', $payment->tuition_fee_id)
                        ->first();
                    if ($tuitionFee) {
                        $totalFee = $tuitionFee->tuition_fee + $tuitionFee->hostel_fee;
                    }
                }

                // Sum all approved payments for this student
                $totalPaid = DB::table('payments')
                    ->where('student_id', $studentId)
                    ->where('status', 'Approved')
                    ->sum('amount');

                // Block if not fully paid
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