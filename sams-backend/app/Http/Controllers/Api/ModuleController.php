<?php

namespace App\Http\Controllers\Api;

use App\Models\ModuleSchedule;
use App\Models\ModuleRegistration;
use App\Models\ModuleAttendance;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Module;
use Illuminate\Http\JsonResponse;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;


class ModuleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $studentId = $this->resolveStudentId($request->query('student_id'));
        $scope = strtolower((string) $request->query('scope', 'booking'));
        $now = Carbon::now();

        $modules = Module::with(['lecturer.user', 'registrations.schedule', 'schedules'])
            ->orderBy('code')
            ->get()
            ->unique(fn($module) => strtoupper(trim((string) $module->code)))
            ->values();

        $data = $modules->map(function ($module) use ($studentId, $scope, $now) {
            $booked = false;
            $bookedClassDate = null;
            $bookableSchedules = $module->schedules
                ->filter(function ($schedule) use ($now) {
                    $classStart = $schedule->class_date && $schedule->start_time
                        ? Carbon::parse($schedule->class_date . ' ' . $schedule->start_time)
                        : null;

                    return $schedule->class_date
                        && $classStart
                        && $classStart->greaterThanOrEqualTo($now)
                        && $schedule->status === 'available'
                        && (int) $schedule->booked_count < (int) $schedule->capacity;
                })
                ->sortBy(fn($schedule) => $schedule->class_date . ' ' . $schedule->start_time)
                ->values();

            $firstSchedule = $scope === 'all'
                ? $module->schedules->sortBy(fn($schedule) => $schedule->class_date . ' ' . $schedule->start_time)->first()
                : $bookableSchedules->first();

            if (
                $scope !== 'all'
                && $studentId
                && (
                    $this->studentCompletedModule((int) $studentId, (int) $module->id)
                    || $this->studentReachedModuleAttemptLimit((int) $studentId, (int) $module->id)
                )
            ) {
                return null;
            }

            if ($studentId) {
                $registration = $module->registrations
                    ->where('student_id', (int) $studentId)
                    ->filter(function ($registration) use ($now) {
                        $classStart = $registration->schedule
                            && $registration->schedule->class_date
                            && $registration->schedule->start_time
                            ? Carbon::parse($registration->schedule->class_date . ' ' . $registration->schedule->start_time)
                            : null;

                        return $registration->schedule
                            && $registration->schedule->class_date
                            && $classStart
                            && $classStart->greaterThanOrEqualTo($now);
                    })
                    ->sortByDesc('id')
                    ->first();

                if ($registration && $registration->schedule) {
                    $booked = true;

                    $date = \Carbon\Carbon::parse($registration->schedule->class_date)->format('d/m/Y');
                    $time = \Carbon\Carbon::parse($registration->schedule->start_time)->format('h:i A');

                    $bookedClassDate = $date . ', ' . $time;
                }
            }

            if ($scope !== 'all' && !$booked && !$firstSchedule) {
                return null;
            }

            return [
                'id' => $module->id,
                'code' => $module->code,
                'name' => $module->name,
                'location' => $module->location,
                'lecturer' => $module->lecturer?->user?->name ?? 'N/A',
                'lecturer_id' => $firstSchedule?->lecturer_id ?? $module->lecturer_id,
                'category' => $module->category,
                'class_date' => $firstSchedule?->class_date,
                'start_time' => $firstSchedule?->start_time,
                'end_time' => $firstSchedule?->end_time,
                'venue' => $firstSchedule?->venue,
                'capacity' => $firstSchedule?->capacity,
                'schedule_id' => $firstSchedule?->id,
                'booked' => $booked,
                'booked_class_date' => $bookedClassDate,
            ];
        })->filter()->values();

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function lecturers(): JsonResponse
    {
        $lecturers = DB::table('lecturers')
            ->join('users', 'lecturers.user_id', '=', 'users.id')
            ->select(
                'lecturers.id',
                'lecturers.staff_id',
                'users.name',
                'users.email'
            )
            ->orderBy('users.name')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $lecturers,
        ]);
    }

    public function schedules(Request $request, $id): JsonResponse
    {
        $scope = strtolower((string) $request->query('scope', 'booking'));
        $now = Carbon::now();
        $module = Module::with(['lecturer.user', 'schedules.lecturer.user'])
            ->findOrFail($id);

        $schedules = $module->schedules;

        if ($scope !== 'all') {
            $schedules = $schedules->filter(function ($schedule) use ($now) {
                $classStart = $schedule->class_date && $schedule->start_time
                    ? Carbon::parse($schedule->class_date . ' ' . $schedule->start_time)
                    : null;

                return $schedule->class_date
                    && $classStart
                    && $classStart->greaterThanOrEqualTo($now)
                    && $schedule->status === 'available'
                    && (int) $schedule->booked_count < (int) $schedule->capacity;
            });
        }

        $data = $schedules->sortBy(fn($schedule) => $schedule->class_date . ' ' . $schedule->start_time)->map(function ($schedule) use ($module) {
            $lecturerName = $schedule->lecturer?->user?->name
                ?? $module->lecturer?->user?->name
                ?? 'N/A';

            return [
                'id' => $schedule->id,
                'module_id' => $module->id,
                'code' => $module->code,
                'name' => $module->name,
                'date' => $schedule->class_date,
                'start_time' => $schedule->start_time,
                'end_time' => $schedule->end_time,
                'venue' => $schedule->venue,
                'lecturer_id' => $schedule->lecturer_id,
                'lecturer' => $lecturerName,
                'status' => $schedule->status,
                'capacity' => $schedule->capacity,
                'booked_count' => $schedule->booked_count,
            ];
        })->values();

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

        if ((int) $schedule->module_id !== (int) $request->module_id) {
            return response()->json([
                'status' => false,
                'message' => 'Selected class does not belong to this module.',
            ], 400);
        }

        if ($this->studentCompletedModule($resolvedStudentId, (int) $request->module_id)) {
            return response()->json([
                'status' => false,
                'message' => 'Student already completed attendance for this module.',
            ], 400);
        }

        if ($this->studentReachedModuleAttemptLimit($resolvedStudentId, (int) $request->module_id)) {
            return response()->json([
                'status' => false,
                'message' => 'Student has reached the maximum 2 attempts for this module.',
            ], 400);
        }

        $classStart = $schedule->class_date && $schedule->start_time
            ? Carbon::parse($schedule->class_date . ' ' . $schedule->start_time)
            : null;

        if ($classStart && $classStart->lt(Carbon::now())) {
            return response()->json([
                'status' => false,
                'message' => 'This class has already started or passed.',
            ], 400);
        }

        if ($schedule->status !== 'available') {
            return response()->json([
                'status' => false,
                'message' => 'This class is not available for booking.',
            ], 400);
        }

        if ($schedule->booked_count >= $schedule->capacity) {
            $schedule->status = 'full';
            $schedule->save();

            return response()->json([
                'status' => false,
                'message' => 'This class is already full.',
            ], 400);
        }

        $alreadyBooked = $this->studentHasActiveModuleBooking($resolvedStudentId, (int) $request->module_id);

        Log::info('Module booking duplicate check', [
            'student_id' => $resolvedStudentId,
            'incoming_student_id' => $request->student_id,
            'module_id' => $request->module_id,
            'module_schedule_id' => $request->module_schedule_id,
            'already_booked' => $alreadyBooked,
        ]);

        if ($alreadyBooked) {
            return response()->json([
                'status' => false,
                'message' => 'Student already booked this module.',
            ], 400);
        }

        $bookedModuleCount = ModuleRegistration::where('student_id', $resolvedStudentId)
            ->distinct('module_id')
            ->count('module_id');

        if ($bookedModuleCount >= 2) {
            return response()->json([
                'status' => false,
                'message' => 'Student can only book up to 2 modules.',
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

    public function pusatAdabStoreModule(Request $request): JsonResponse
    {
        $request->validate([
            'code' => 'required|string|max:255',
            'name' => 'required|string|max:255',
            'location' => 'nullable|string|max:255',
            'category' => 'nullable|string|max:255',
            'class_date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'venue' => 'required|string|max:255',
            'capacity' => 'required|integer|min:1',
            'lecturer_id' => 'required|integer|exists:lecturers,id',
            'week_number' => 'nullable|integer',
        ]);

        $moduleCode = strtoupper(trim($request->code));

        $moduleExists = Module::whereRaw('UPPER(code) = ?', [$moduleCode])->exists();

        if ($moduleExists) {
            return response()->json([
                'status' => false,
                'message' => 'Module code already exists. Please use a different code.',
            ], 422);
        }

        $module = new Module();

        $module->code = $moduleCode;
        $module->name = trim($request->name);
        $module->location = $request->location ?: $request->venue;
        $module->category = $request->category;

        if ($request->filled('lecturer_id')) {
            $module->lecturer_id = $request->lecturer_id;
        }

        $module->save();

        $schedule = ModuleSchedule::create([
            'module_id' => $module->id,
            'class_date' => $request->class_date,
            'start_time' => $request->start_time,
            'end_time' => $request->end_time,
            'venue' => $request->venue,
            'capacity' => $request->capacity,
            'lecturer_id' => $request->lecturer_id,
            'booked_count' => 0,
            'status' => 'available',
            'session_type' => 'Module',
            'week_number' => $request->week_number,
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Module registered successfully.',
            'data' => [
                'module' => $module,
                'schedule' => $schedule,
            ],
        ]);
    }

    public function pusatAdabUpdateModule(Request $request, int $moduleId): JsonResponse
    {
        $request->validate([
            'code' => 'required|string|max:255',
            'name' => 'required|string|max:255',
            'location' => 'nullable|string|max:255',
            'category' => 'nullable|string|max:255',
            'class_date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'venue' => 'required|string|max:255',
            'capacity' => 'required|integer|min:1',
            'lecturer_id' => 'required|integer|exists:lecturers,id',
            'week_number' => 'nullable|integer',
        ]);

        $module = Module::findOrFail($moduleId);
        $moduleCode = strtoupper(trim($request->code));

        $moduleExists = Module::whereRaw('UPPER(code) = ?', [$moduleCode])
            ->where('id', '!=', $module->id)
            ->exists();

        if ($moduleExists) {
            return response()->json([
                'status' => false,
                'message' => 'Module code already exists. Please use a different code.',
            ], 422);
        }

        $module->code = $moduleCode;
        $module->name = trim($request->name);
        $module->location = $request->location ?: $request->venue;
        $module->category = $request->category;

        if ($request->filled('lecturer_id')) {
            $module->lecturer_id = $request->lecturer_id;
        }

        $module->save();

        $schedule = ModuleSchedule::where('module_id', $module->id)
            ->orderBy('id')
            ->first();

        if (!$schedule) {
            $schedule = new ModuleSchedule();
            $schedule->module_id = $module->id;
            $schedule->booked_count = 0;
            $schedule->status = 'available';
            $schedule->session_type = 'Module';
        }

        $schedule->class_date = $request->class_date;
        $schedule->start_time = $request->start_time;
        $schedule->end_time = $request->end_time;
        $schedule->venue = $request->venue;
        $schedule->capacity = $request->capacity;
        $schedule->lecturer_id = $request->lecturer_id;
        $schedule->week_number = $request->week_number;

        if ($schedule->booked_count >= $schedule->capacity) {
            $schedule->status = 'full';
        } elseif ($schedule->status === 'full') {
            $schedule->status = 'available';
        }

        $schedule->save();

        return response()->json([
            'status' => true,
            'message' => 'Module updated successfully.',
            'data' => [
                'module' => $module,
                'schedule' => $schedule,
            ],
        ]);
    }

    public function pusatAdabDeleteModule(int $moduleId): JsonResponse
    {
        $module = Module::findOrFail($moduleId);

        DB::transaction(function () use ($module) {
            $scheduleIds = ModuleSchedule::where('module_id', $module->id)->pluck('id');
            $registrationIds = ModuleRegistration::where('module_id', $module->id)->pluck('id');

            DB::table('credit_claims')
                ->where('module_id', $module->id)
                ->orWhereIn('registration_id', $registrationIds)
                ->delete();

            ModuleAttendance::whereIn('module_session_id', $scheduleIds)->delete();
            ModuleRegistration::where('module_id', $module->id)->delete();
            ModuleSchedule::where('module_id', $module->id)->delete();

            $module->delete();
        });

        return response()->json([
            'status' => true,
            'message' => 'Module deleted successfully.',
        ]);
    }

    public function pusatAdabStoreSchedule(Request $request, int $moduleId): JsonResponse
    {
        Module::findOrFail($moduleId);

        $request->validate([
            'class_date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'venue' => 'required|string|max:255',
            'capacity' => 'required|integer|min:1',
            'lecturer_id' => 'required|integer|exists:lecturers,id',
            'week_number' => 'nullable|integer',
        ]);

        $schedule = ModuleSchedule::create([
            'module_id' => $moduleId,
            'class_date' => $request->class_date,
            'start_time' => $request->start_time,
            'end_time' => $request->end_time,
            'venue' => $request->venue,
            'capacity' => $request->capacity,
            'lecturer_id' => $request->lecturer_id,
            'booked_count' => 0,
            'status' => 'available',
            'session_type' => 'Module',
            'week_number' => $request->week_number,
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Class added successfully.',
            'data' => $schedule,
        ]);
    }

    public function pusatAdabUpdateSchedule(Request $request, int $scheduleId): JsonResponse
    {
        $schedule = ModuleSchedule::findOrFail($scheduleId);

        $request->validate([
            'class_date' => 'required|date',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'venue' => 'required|string|max:255',
            'capacity' => 'required|integer|min:1',
            'lecturer_id' => 'required|integer|exists:lecturers,id',
            'week_number' => 'nullable|integer',
        ]);

        if ((int) $request->capacity < (int) $schedule->booked_count) {
            return response()->json([
                'status' => false,
                'message' => 'Capacity cannot be lower than current booked count.',
            ], 422);
        }

        $schedule->class_date = $request->class_date;
        $schedule->start_time = $request->start_time;
        $schedule->end_time = $request->end_time;
        $schedule->venue = $request->venue;
        $schedule->capacity = $request->capacity;
        $schedule->lecturer_id = $request->lecturer_id;
        $schedule->week_number = $request->week_number;
        $schedule->status = $schedule->booked_count >= $schedule->capacity ? 'full' : 'available';
        $schedule->save();

        return response()->json([
            'status' => true,
            'message' => 'Class updated successfully.',
            'data' => $schedule,
        ]);
    }

    public function pusatAdabDeleteSchedule(int $scheduleId): JsonResponse
    {
        $schedule = ModuleSchedule::findOrFail($scheduleId);

        DB::transaction(function () use ($schedule) {
            $registrationIds = ModuleRegistration::where('module_schedule_id', $schedule->id)->pluck('id');

            DB::table('credit_claims')
                ->whereIn('registration_id', $registrationIds)
                ->delete();

            ModuleAttendance::where('module_session_id', $schedule->id)->delete();
            ModuleRegistration::where('module_schedule_id', $schedule->id)->delete();

            $schedule->delete();
        });

        return response()->json([
            'status' => true,
            'message' => 'Class deleted successfully.',
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
            ->get()
            ->unique('module_id')
            ->values();

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
                } elseif (strtoupper($attendanceStatus) === 'ABSENT') {
                    $attendancePercentage = '--';
                } elseif (strtoupper($attendanceStatus) === 'LATE') {
                    $attendancePercentage = '80%';
                }
            }

            return [
                'registration_id' => $registration->id,
                'module_id' => $registration->module_id,
                'code' => $registration->module->code ?? '',
                'name' => $registration->module->name ?? '',
                'venue' => $registration->schedule?->venue ?? '',
                'class_date' => $registration->schedule?->class_date ?? '',
                'start_time' => $registration->schedule?->start_time ?? '',
                'end_time' => $registration->schedule?->end_time ?? '',
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

    public function joinedActivities(Request $request): JsonResponse
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
            ->get()
            ->unique('module_id')
            ->values();

        $data = $registrations->map(function ($registration) {
            $attendance = ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->latest()
                ->first();

            $attendanceStatus = strtoupper($attendance->status ?? '--');

            return [
                'registration_id' => $registration->id,
                'module_id' => $registration->module_id,
                'code' => $registration->module->code ?? '',
                'name' => $registration->module->name ?? '',
                'category' => $registration->module->category ?? '',
                'venue' => $registration->schedule->venue ?? '',
                'class_date' => $registration->schedule->class_date ?? '',
                'start_time' => $registration->schedule->start_time ?? '',
                'end_time' => $registration->schedule->end_time ?? '',
                'cats' => 2,
                'attendance_status' => $attendanceStatus,
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

        // Group by module_id, pick the registration that has attendance first
        $grouped = $registrations->groupBy('module_id')->map(function ($regs) {
            $withAttendance = $regs->first(function ($registration) {
                return ModuleAttendance::where('student_id', $registration->student_id)
                    ->where('module_session_id', $registration->module_schedule_id)
                    ->exists();
            });

            return $withAttendance ?? $regs->first();
        });

        $data = $grouped->map(function ($registration) {
            $attendance = ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->latest()
                ->first();

            $attendanceStatus = strtoupper($attendance->status ?? '--');
            $attended = in_array($attendanceStatus, ['PRESENT', 'LATE'], true);

            $classEnded = $registration->schedule
                && $registration->schedule->class_date
                && $registration->schedule->end_time
                && Carbon::parse($registration->schedule->class_date . ' ' . $registration->schedule->end_time)->lte(now());

            $progress = $attended && $classEnded;

            $claim = DB::table('credit_claims')
                ->where('registration_id', $registration->id)
                ->latest('id')
                ->first();

            $claimStatus = $claim->status ?? '--';

            if (!$attended && !$claim) {
                return null;
            }

            return [
                'registration_id' => $registration->id,
                'module_id' => $registration->module_id,
                'code' => $registration->module->code ?? '',
                'name' => $registration->module->name ?? '',
                'attendance_status' => $attendanceStatus,
                'progress_completed' => $progress,
                'claim_status' => strtoupper($claimStatus),
                'class_ended' => $classEnded,
                'can_claim' => $progress && !$claim,
            ];
        })->filter()
            ->sortByDesc(function ($item) {
                if ($item['can_claim'] === true) {
                    return 2;
                }
                return $item['claim_status'] !== '--' ? 1 : 0;
            })
            ->values();

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

        if (!$resolvedStudentId) {
            return response()->json([
                'status' => false,
                'message' => 'Student record not found.',
            ], 404);
        }

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

        $attendanceStatus = strtoupper($attendance->status ?? '');

        if (!$attendance || !in_array($attendanceStatus, ['PRESENT', 'LATE'], true)) {
            return response()->json([
                'status' => false,
                'message' => 'Credit claim is only allowed after successful attendance.',
            ], 400);
        }

        $classEnded = $registration->schedule
            && $registration->schedule->class_date
            && $registration->schedule->end_time
            && Carbon::parse($registration->schedule->class_date . ' ' . $registration->schedule->end_time)->lte(now());

        if (!$classEnded) {
            return response()->json([
                'status' => false,
                'message' => 'Credit claim is only allowed after the module class has finished.',
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
            'submitted_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Credit claim submitted successfully.',
        ]);
    }

    public function pusatAdabCreditClaims(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('search', ''));
        $status = strtoupper(trim((string) $request->query('status', '')));

        $query = DB::table('credit_claims')
            ->join('module_registrations', 'credit_claims.registration_id', '=', 'module_registrations.id')
            ->join('modules', 'credit_claims.module_id', '=', 'modules.id')
            ->join('students', 'credit_claims.student_id', '=', 'students.id')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->leftJoin('module_schedules', 'module_registrations.module_schedule_id', '=', 'module_schedules.id')
            ->select(
                'credit_claims.id',
                'credit_claims.registration_id',
                'credit_claims.student_id',
                'credit_claims.module_id',
                'credit_claims.status',
                'credit_claims.claim_percentage',
                'credit_claims.priority',
                'credit_claims.submitted_at',
                'credit_claims.reviewed_at',
                'credit_claims.created_at',
                'credit_claims.updated_at',
                'module_registrations.module_schedule_id',
                'users.name as student_name',
                'students.matric_no',
                'modules.code as module_code',
                'modules.name as module_name',
                'modules.category',
                'module_schedules.class_date',
                'module_schedules.start_time',
                'module_schedules.end_time',
                'module_schedules.venue'
            );

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('users.name', 'like', "%{$search}%")
                    ->orWhere('students.matric_no', 'like', "%{$search}%")
                    ->orWhere('modules.name', 'like', "%{$search}%")
                    ->orWhere('modules.code', 'like', "%{$search}%");
            });
        }

        if ($status !== '' && $status !== 'ALL') {
            $query->whereRaw('UPPER(credit_claims.status) = ?', [$status]);
        }

        $claims = $query
            ->orderByRaw("CASE WHEN UPPER(credit_claims.status) = 'IN PROGRESS' THEN 0 ELSE 1 END")
            ->orderByDesc('credit_claims.created_at')
            ->get();

        $data = $claims->map(function ($claim) {
            $attendance = ModuleAttendance::where('student_id', $claim->student_id)
                ->where('module_session_id', $claim->module_schedule_id)
                ->latest()
                ->first();

            return [
                'id' => $claim->id,
                'registration_id' => $claim->registration_id,
                'student_id' => $claim->student_id,
                'student_name' => $claim->student_name,
                'matric_no' => $claim->matric_no,
                'module_id' => $claim->module_id,
                'module_code' => $claim->module_code,
                'module_name' => $claim->module_name,
                'category' => $claim->category,
                'class_date' => $claim->class_date,
                'start_time' => $claim->start_time,
                'end_time' => $claim->end_time,
                'venue' => $claim->venue,
                'cats' => 2,
                'attendance_status' => strtoupper($attendance->status ?? 'PRESENT'),
                'attendance_percentage' => $attendance?->attendance_percentage ?: 90,
                'status' => strtoupper($claim->status),
                'priority' => strtoupper($claim->priority ?? 'NORMAL'),
                'claim_percentage' => $claim->claim_percentage ?? 0,
                'submitted_at' => $claim->submitted_at ?? $claim->created_at,
                'reviewed_at' => $claim->reviewed_at,
            ];
        });

        return response()->json([
            'status' => true,
            'summary' => [
                'pending' => $data->where('status', 'IN PROGRESS')->count(),
                'approved_today' => $data
                    ->where('status', 'APPROVED')
                    ->filter(fn($item) => !empty($item['reviewed_at']) && Carbon::parse($item['reviewed_at'])->isToday())
                    ->count(),
                'urgent' => $data->where('priority', 'URGENT')->count(),
            ],
            'data' => $data->values(),
        ]);
    }

    public function updateCreditClaimStatus(Request $request, int $claimId): JsonResponse
    {
        $request->validate([
            'status' => 'required|string|in:APPROVED,REJECTED',
            'reviewed_by' => 'nullable|integer',
            'admin_remark' => 'nullable|string',
        ]);

        $claim = DB::table('credit_claims')->where('id', $claimId)->first();

        if (!$claim) {
            return response()->json([
                'status' => false,
                'message' => 'Credit claim not found.',
            ], 404);
        }

        DB::table('credit_claims')
            ->where('id', $claimId)
            ->update([
                'status' => strtoupper($request->status),
                'reviewed_by' => $request->reviewed_by,
                'reviewed_at' => now(),
                'admin_remark' => $request->admin_remark,
                'claim_percentage' => strtoupper($request->status) === 'APPROVED' ? 100 : 0,
                'updated_at' => now(),
            ]);

        return response()->json([
            'status' => true,
            'message' => 'Credit claim status updated successfully.',
        ]);
    }

    public function pusatAdabModuleRegistrations(Request $request): JsonResponse
    {
        $search = trim((string) $request->query('search', ''));
        $filter = strtoupper(trim((string) $request->query('filter', 'ALL')));

        $registrations = ModuleRegistration::with(['module', 'schedule'])
            ->orderByDesc('id')
            ->get();

        $data = $registrations->map(function ($registration) {
            $student = DB::table('students')
                ->join('users', 'students.user_id', '=', 'users.id')
                ->where(function ($query) use ($registration) {
                    $query->where('students.id', $registration->student_id)
                        ->orWhere('students.user_id', $registration->student_id);
                })
                ->select('students.id', 'students.matric_no', 'users.name')
                ->first();

            $attendance = ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->latest()
                ->first();

            $claim = DB::table('credit_claims')
                ->where('registration_id', $registration->id)
                ->latest('id')
                ->first();

            return [
                'registration_id' => $registration->id,
                'student_id' => $registration->student_id,
                'student_name' => $student->name ?? 'Unknown Student',
                'matric_no' => $student->matric_no ?? '--',
                'module_id' => $registration->module_id,
                'module_schedule_id' => $registration->module_schedule_id,
                'module_code' => $registration->module->code ?? '',
                'module_name' => $registration->module->name ?? '',
                'category' => $registration->module->category ?? '',
                'venue' => $registration->schedule->venue ?? '',
                'class_date' => $registration->schedule->class_date ?? '',
                'start_time' => $registration->schedule->start_time ?? '',
                'end_time' => $registration->schedule->end_time ?? '',
                'attendance_status' => strtoupper($attendance->status ?? 'REGISTERED'),
                'attendance_percentage' => $attendance?->attendance_percentage ?: 0,
                'claim_status' => strtoupper($claim->status ?? 'NOT CLAIMED'),
                'registered_at' => $registration->created_at,
            ];
        });

        if ($search !== '') {
            $needle = strtolower($search);
            $data = $data->filter(function ($item) use ($needle) {
                return str_contains(strtolower($item['student_name']), $needle)
                    || str_contains(strtolower($item['matric_no']), $needle)
                    || str_contains(strtolower($item['module_code']), $needle)
                    || str_contains(strtolower($item['module_name']), $needle);
            });
        }

        if ($filter !== '' && $filter !== 'ALL') {
            $data = $data->filter(function ($item) use ($filter) {
                if ($filter === 'CLAIMED') {
                    return $item['claim_status'] !== 'NOT CLAIMED';
                }

                if ($filter === 'NOT CLAIMED') {
                    return $item['claim_status'] === 'NOT CLAIMED';
                }

                return $item['attendance_status'] === $filter;
            });
        }

        $data = $data->values();

        $modules = $data
            ->groupBy(function ($item) {
                $code = strtoupper(trim((string) ($item['module_code'] ?? '')));

                return $code !== '' ? $code : 'MODULE-' . $item['module_id'];
            })
            ->map(function ($records) {
                $first = $records->first();

                return [
                    'module_id' => $first['module_id'],
                    'module_schedule_id' => $first['module_schedule_id'],
                    'module_code' => $first['module_code'],
                    'module_name' => $first['module_name'],
                    'category' => $first['category'],
                    'venue' => $first['venue'],
                    'class_date' => $first['class_date'],
                    'start_time' => $first['start_time'],
                    'end_time' => $first['end_time'],
                    'total_registered' => $records->count(),
                    'present' => $records->where('attendance_status', 'PRESENT')->count(),
                    'claimed' => $records->filter(fn($item) => $item['claim_status'] !== 'NOT CLAIMED')->count(),
                    'approved' => $records->where('claim_status', 'APPROVED')->count(),
                    'records' => $records->values(),
                ];
            })
            ->values();

        return response()->json([
            'status' => true,
            'summary' => [
                'total_registered' => $data->count(),
                'present' => $data->where('attendance_status', 'PRESENT')->count(),
                'claims_submitted' => $data->filter(fn($item) => $item['claim_status'] !== 'NOT CLAIMED')->count(),
                'approved_claims' => $data->where('claim_status', 'APPROVED')->count(),
            ],
            'data' => $modules,
        ]);
    }

    public function pusatAdabRemoveModuleRegistration(int $registrationId): JsonResponse
    {
        $registration = ModuleRegistration::with('schedule')->findOrFail($registrationId);

        DB::transaction(function () use ($registration) {
            DB::table('credit_claims')
                ->where('registration_id', $registration->id)
                ->delete();

            ModuleAttendance::where('student_id', $registration->student_id)
                ->where('module_session_id', $registration->module_schedule_id)
                ->delete();

            $schedule = ModuleSchedule::find($registration->module_schedule_id);

            if ($schedule && $schedule->booked_count > 0) {
                $schedule->booked_count = $schedule->booked_count - 1;

                if ($schedule->status === 'full' && $schedule->booked_count < $schedule->capacity) {
                    $schedule->status = 'available';
                }

                $schedule->save();
            }

            $registration->delete();
        });

        return response()->json([
            'status' => true,
            'message' => 'Student removed from module successfully.',
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

    private function studentCompletedModule(int $studentId, int $moduleId): bool
    {
        $scheduleIds = ModuleRegistration::where('student_id', $studentId)
            ->where('module_id', $moduleId)
            ->pluck('module_schedule_id')
            ->filter()
            ->values();

        if ($scheduleIds->isEmpty()) {
            return false;
        }

        return ModuleAttendance::where('student_id', $studentId)
            ->whereIn('module_session_id', $scheduleIds)
            ->whereRaw('UPPER(status) IN (?, ?)', ['PRESENT', 'LATE'])
            ->exists();
    }

    private function studentReachedModuleAttemptLimit(int $studentId, int $moduleId): bool
    {
        return ModuleRegistration::where('student_id', $studentId)
            ->where('module_id', $moduleId)
            ->count() >= 2;
    }

    private function studentHasActiveModuleBooking(int $studentId, int $moduleId): bool
    {
        return ModuleRegistration::with('schedule')
            ->where('student_id', $studentId)
            ->where('module_id', $moduleId)
            ->get()
            ->contains(function ($registration) {
                if (
                    !$registration->schedule
                    || !$registration->schedule->class_date
                    || !$registration->schedule->start_time
                ) {
                    return false;
                }

                return Carbon::parse(
                    $registration->schedule->class_date . ' ' . $registration->schedule->start_time
                )->greaterThanOrEqualTo(Carbon::now());
            });
    }
}
