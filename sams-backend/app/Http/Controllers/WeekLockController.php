<?php

namespace App\Http\Controllers;

use App\Models\WeekLock;
use App\Models\TuitionFee; 
use Illuminate\Http\Request;

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
            $matricNo = $request->query('matric_no');

            if ($matricNo) {
                // Check if student has completed payment
                // Adjust the model/column names to match YOUR database
                $paid = TuitionFee::where('matric_no', $matricNo)
                    ->where('status', 'approved')
                    ->exists();

                // Student is blocked only if locked AND not fully paid
                $studentBlocked = !$paid;
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