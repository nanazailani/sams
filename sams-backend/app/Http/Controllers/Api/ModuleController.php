<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Module;
use App\Models\ModuleAttendance;
use App\Models\ModuleRegistration;
use App\Models\ModuleSchedule;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ModuleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $studentId = $this->resolveStudentId($request->query('student_id'));

        $modules = Module::with(['lecturer.user', 'registrations.schedule'])
            ->orderBy('code')
            ->get();

        $data = $modules->map(function ($module) use ($studentId) {
            $booked = false;
            $bookedClassDate = null;

            if ($studentId) {
                $registration = $module->registrations
                    ->where('student_id', (int) $studentId)
                    ->sortByDesc('id')
                    ->first();

                if ($registration && $registration->schedule) {
                    $booked = true;

                    $date = Carbon::parse($registration->schedule->class_date)->format('d/m/Y');
                    $time = Carbon::parse($registration->schedule->start_time)->format('h:i A');

                    $bookedClassDate = $date . ', ' . $time;
                }
            }

            return [
                'id' => $module->id,
                'code' => $module->code,
                'name' => $module->name,
                'location' => $module->location,
                'lecturer' => $module->lecturer?->user?->name ?? 'N/A',
                'category' => $module->category,
                'booked' => $booked,
                'booked_class_date' => $bookedClassDate,
            ];
        });

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function schedules($id): JsonResponse
    {
        $module = Module::with(['lecturer.user', 'schedules'])->findOrFail($id);

        $data = $module->schedules->map(function ($schedule) use ($module) {
            return [
                'id' => $schedule->id,
                'module_id' => $module->id,
                'code' => $module->code,
                'name' => $module->name,
                'date' => $schedule->class_date,
                'start_time' => $schedule->start_time,
                'end_time' => $schedule->end_time,
                'venue' => $schedule->venue,
                'lecturer' => $module->lecturer?->user?->name ?? 'N/A',
                'status' => $schedule->status,
                'capacity' => $schedule->capacity,
                'booked_count' => $schedule->booked_count,
            ];
        });

        return response()->json([
            'status' => true,
            'module' => [
                'id' => $module->id,
                'code' => $module->code,
                'name' => $module->name,
                'location' => $module->location,
                'lecturer' => $module->lecturer?->user?->name ?? 'N/A',
                'category' => $module->category,
            ],
            'data' => $data,
        ]);
    }

    public function book(Request $request): JsonResponse
    {
        $request->validate([
            'student_id' => 'required|integer',
            'module_id' => 'required|integer',
            'module_schedule_id' => 'required|integer',
        ]);

        $resolvedStudentId = $this->resolveStudentId((int) $request->student_id);

        if (!$resolvedStudentId) {
            return response()->json([
                'status' => false,
                'message' => 'Student record not found.',
            ], 404);
        }

        Log::info('Module booking request received', [
            'student_id' => $resolvedStudentId,
            'incoming_student_id' => $request->student_id,
            'module_id' => $request->module_id,
            'module_schedule_id' => $request->module_schedule_id,
        ]);

        $schedule = ModuleSchedule::findOrFail($request->module_schedule_id);

        if ($schedule->status === 'full' || $schedule->booked_count >= $schedule->capacity) {
            $schedule->status = 'full';
            $schedule->save();

            return response()->json([
                'status' => false,
                'message' => 'This class is already full.',
            ], 400);
        }

        $alreadyBooked = ModuleRegistration::where('student_id', $resolvedStudentId)
            ->where('module_id', $request->module_id)
            ->where('module_schedule_id', $request->module_schedule_id)
            ->exists();

        if ($alreadyBooked) {
            return response()->json([
                'status' => false,
                'message' => 'Student already booked this class.',
            ], 400);
        }

        $registration = ModuleRegistration::create([
            'student_id' => $resolvedStudentId,
            'module_id' => $request->module_id,
            'module_schedule_id' => $request->module_schedule_id,
        ]);

        $schedule->booked_count = $schedule->booked_count + 1;

        if ($schedule->booked_count >= $schedule->capacity) {
            $schedule->status = 'full';
        }

        $schedule->save();

        return response()->json([
            'status' => true,
            'message' => 'Module booking successful.',
            'data' => $registration,
        ]);
    }

    public function myBookings(Request $request): JsonResponse
    {
        $studentId = $this->resolveStudentId($request->query('student_id'));

        if (!$studentId) {
            return response()->json([
                'status' => false,
                'message' => 'Student ID is required.',
            ], 400);
        }

        $registrations = ModuleRegistration::with(['module', 'schedule'])
            ->where('student_id', $studentId)
            ->orderByDesc('id')
            ->get();

        $data = $registrations->map(function ($registration) {
            $canCancel = false;

            if ($registration->schedule && $registration->schedule->class_date) {
                $scheduleDate = Carbon::parse($registration->schedule->class_date);
                $today = Carbon::today();
                $canCancel = $today->lt($scheduleDate);
            }

            $attendanceStatus = '--';
            $attendancePercentage = '--';

            $attendance = ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->latest()
                ->first();

            if ($attendance) {
                $attendanceStatus = $attendance->status ?? '--';

                if (strtoupper($attendanceStatus) === 'PRESENT') {
                    $attendancePercentage = '98%';
                } elseif (strtoupper($attendanceStatus) === 'LATE') {
                    $attendancePercentage = '80%';
                }
            }

            return [
                'registration_id' => $registration->id,
                'module_id' => $registration->module_id,
                'code' => $registration->module->code ?? '',
                'name' => $registration->module->name ?? '',
                'venue' => $registration->schedule->venue ?? '',
                'class_date' => $registration->schedule->class_date ?? '',
                'start_time' => $registration->schedule->start_time ?? '',
                'end_time' => $registration->schedule->end_time ?? '',
                'cats' => 2,
                'attendance_status' => $attendanceStatus,
                'attendance_percentage' => $attendancePercentage,
                'can_cancel' => $canCancel,
            ];
        });

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function cancelBooking($registrationId): JsonResponse
    {
        $registration = ModuleRegistration::with('schedule')->findOrFail($registrationId);

        if (!$registration->schedule || !$registration->schedule->class_date) {
            return response()->json([
                'status' => false,
                'message' => 'Schedule information not found.',
            ], 400);
        }

        $scheduleDate = Carbon::parse($registration->schedule->class_date);
        $today = Carbon::today();

        if (!$today->lt($scheduleDate)) {
            return response()->json([
                'status' => false,
                'message' => 'Cancellation is not allowed on the event day.',
            ], 400);
        }

        $schedule = ModuleSchedule::find($registration->module_schedule_id);

        if ($schedule && $schedule->booked_count > 0) {
            $schedule->booked_count = $schedule->booked_count - 1;

            if ($schedule->status === 'full' && $schedule->booked_count < $schedule->capacity) {
                $schedule->status = 'available';
            }

            $schedule->save();
        }

        $registration->delete();

        return response()->json([
            'status' => true,
            'message' => 'Booking cancelled successfully.',
        ]);
    }

    public function creditClaims(Request $request): JsonResponse
    {
        $studentId = $this->resolveStudentId($request->query('student_id'));

        if (!$studentId) {
            return response()->json([
                'status' => false,
                'message' => 'Student ID is required.',
            ], 400);
        }

        $registrations = ModuleRegistration::with(['module', 'schedule'])
            ->where('student_id', $studentId)
            ->orderByDesc('id')
            ->get();

        $data = $registrations->map(function ($registration) {
            $attendance = ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->latest()
                ->first();

            $attendanceStatus = strtoupper($attendance->status ?? '--');
            $progress = $attendanceStatus === 'PRESENT';

            $claim = DB::table('credit_claims')
                ->where('registration_id', $registration->id)
                ->latest('id')
                ->first();

            $claimStatus = $claim->status ?? '--';

            return [
                'registration_id' => $registration->id,
                'module_id' => $registration->module_id,
                'code' => $registration->module->code ?? '',
                'name' => $registration->module->name ?? '',
                'attendance_status' => $attendanceStatus,
                'progress_completed' => $progress,
                'claim_status' => strtoupper($claimStatus),
                'can_claim' => $progress && !$claim,
            ];
        });

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function applyCreditClaim(Request $request): JsonResponse
    {
        $request->validate([
            'registration_id' => 'required|integer',
            'student_id' => 'required|integer',
        ]);

        $resolvedStudentId = $this->resolveStudentId((int) $request->student_id);

        $registration = ModuleRegistration::with(['module', 'schedule'])
            ->where('id', $request->registration_id)
            ->where('student_id', $resolvedStudentId)
            ->first();

        if (!$registration) {
            return response()->json([
                'status' => false,
                'message' => 'Registration not found.',
            ], 404);
        }

        $attendance = ModuleAttendance::where('student_id', $registration->student_id)
            ->where('module_session_id', $registration->module_schedule_id)
            ->latest()
            ->first();

        if (!$attendance || strtoupper($attendance->status ?? '') !== 'PRESENT') {
            return response()->json([
                'status' => false,
                'message' => 'Credit claim is only allowed after successful attendance.',
            ], 400);
        }

        $existingClaim = DB::table('credit_claims')
            ->where('registration_id', $registration->id)
            ->first();

        if ($existingClaim) {
            return response()->json([
                'status' => false,
                'message' => 'Credit claim already submitted.',
            ], 400);
        }

        DB::table('credit_claims')->insert([
            'registration_id' => $registration->id,
            'student_id' => $registration->student_id,
            'module_id' => $registration->module_id,
            'status' => 'IN PROGRESS',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Credit claim submitted successfully.',
        ]);
    }

    private function resolveStudentId($incomingStudentId): ?int
    {
        if (!$incomingStudentId) {
            return null;
        }

        $incomingStudentId = (int) $incomingStudentId;

        $directStudentId = DB::table('students')
            ->where('id', $incomingStudentId)
            ->value('id');

        if ($directStudentId) {
            return (int) $directStudentId;
        }

        $studentByUserId = DB::table('students')
            ->where('user_id', $incomingStudentId)
            ->value('id');

        if ($studentByUserId) {
            return (int) $studentByUserId;
        }

        $user = DB::table('users')
            ->where('id', $incomingStudentId)
            ->first();

        if ($user && !empty($user->matric_number)) {
            $studentByMatric = DB::table('students')
                ->where('matric_number', $user->matric_number)
                ->value('id');

            if ($studentByMatric) {
                return (int) $studentByMatric;
            }
        }

        return null;
    }
}