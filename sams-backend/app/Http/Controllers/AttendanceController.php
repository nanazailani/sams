<?php

namespace App\Http\Controllers;

use App\Models\AttendanceCode;
use App\Models\ClassSession;
use App\Models\ModuleSchedule;
use App\Models\ModuleAttendanceCode;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;

class AttendanceController extends Controller
{
    /**
     * Generate and save attendance code for a class session.
     */
    public function generateCode(Request $request)
    {
        $request->validate([
            'attendance_type' => 'nullable|in:course,module',
            'class_session_id' => 'nullable|exists:class_sessions,id',
            'module_session_id' => 'nullable|exists:module_schedules,id',
        ]);

        $attendanceType = $request->input('attendance_type', 'course');
        $isModule = $attendanceType === 'module';
        $sessionIdField = $isModule ? 'module_session_id' : 'class_session_id';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;
        $sessionModel = $isModule ? ModuleSchedule::class : ClassSession::class;

        $sessionId = $request->input($sessionIdField);

        if (!$sessionId) {
            return response()->json([
                'message' => $isModule
                    ? 'module_session_id is required for module attendance.'
                    : 'class_session_id is required for course attendance.',
            ], 422);
        }

        $classSession = $sessionModel::findOrFail($sessionId);

        $now = Carbon::now();
        $classStart = Carbon::parse($classSession->class_date . ' ' . $classSession->start_time);
        $classEnd = Carbon::parse($classSession->class_date . ' ' . $classSession->end_time);

        if ($now->lt($classStart) || $now->gt($classEnd)) {
            return response()->json([
                'message' => 'Attendance code can only be generated during class time.',
                'class_date' => $classSession->class_date,
                'start_time' => $classSession->start_time,
                'end_time' => $classSession->end_time,
            ], 422);
        }

        $code = Str::upper(Str::random(6));

        $attendanceCode = $codeModel::create([
            $sessionIdField => $sessionId,
            'code' => $code,
            'expires_at' => $classEnd,
        ]);

        return response()->json([
            'message' => 'Attendance code generated successfully',
            'attendance_type' => $attendanceType,
            'attendance_code' => $attendanceCode->code,
            $sessionIdField => $attendanceCode->{$sessionIdField},
            'expires_at' => $attendanceCode->expires_at,
        ]);
    }

    /**
     * Get attendance submissions for a class session.
     */
    public function getSubmissions(Request $request, $classSessionId)
    {
        $attendanceType = $request->query('type', 'course');
        $isModule = $attendanceType === 'module';
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';

        $submissions = DB::table($attendanceTable)
            ->leftJoin('students', $attendanceTable . '.student_id', '=', 'students.id')
            ->leftJoin('users', 'students.user_id', '=', 'users.id')
            ->where($attendanceTable . '.' . $sessionForeignKey, $classSessionId)
            ->select(
                $attendanceTable . '.id',
                $attendanceTable . '.status',
                $attendanceTable . '.verification_status',
                $attendanceTable . '.location_name',
                $attendanceTable . '.created_at as submitted_at',
                DB::raw("COALESCE(users.name, 'Unknown Student') as student_name"),
                DB::raw("COALESCE(students.matric_no, '-') as matric_no")
            )
            ->orderBy($attendanceTable . '.created_at')
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'name' => $item->student_name,
                    'matric' => $item->matric_no,
                    'time' => $item->submitted_at
                        ? Carbon::parse($item->submitted_at)->format('g:i a')
                        : '-',
                    'status' => $item->status ?? 'Pending',
                    'verification_status' => $item->verification_status ?? 'Pending',
                    'location_name' => $item->location_name ?? '-',
                ];
            });

        return response()->json($submissions);
    }

    /**
     * Get attendance dashboard data for a student and subject.
     */
    public function getStudentAttendance(Request $request, $studentId, $subjectId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([
                'message' => 'Student record not found',
            ], 404);
        }
        $attendanceType = $request->query('type', 'course');
        $isModule = $attendanceType === 'module';
        $sessionTable = $isModule ? 'module_schedules' : 'class_sessions';
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';
        $sessionColumn = $isModule ? 'module_id' : 'subject_id';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;

        $student = DB::table('students')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('students.id', $studentId)
            ->select(
                'users.name as student_name',
                'students.matric_no as matric_number',
                'students.programme'
            )
            ->first();

        $sessions = DB::table($sessionTable)
            ->where($sessionColumn, $subjectId)
            ->pluck('id');

        $records = DB::table($attendanceTable)
            ->where('student_id', $studentId)
            ->whereIn($sessionForeignKey, $sessions)
            ->get();

        $present = $records
            ->filter(fn($record) => $record->status === 'Present' && ($record->verification_status ?? 'Pending') !== 'Rejected')
            ->count();

        $late = $records
            ->filter(fn($record) => $record->status === 'Late' && ($record->verification_status ?? 'Pending') !== 'Rejected')
            ->count();

        $absent = $records
            ->filter(fn($record) => $record->status === 'Absent' || (($record->verification_status ?? 'Pending') === 'Rejected'))
            ->count();

        $totalClasses = $sessions->count();
        $attended = $present + $late;

        $attendanceRate = $totalClasses > 0
            ? round(($attended / $totalClasses) * 100) . '%'
            : '0%';

        $recentRecords = DB::table($attendanceTable)
            ->join($sessionTable, $attendanceTable . '.' . $sessionForeignKey, '=', $sessionTable . '.id')
            ->where($attendanceTable . '.student_id', $studentId)
            ->where($sessionTable . '.' . $sessionColumn, $subjectId)
            ->select(
                $sessionTable . '.id',
                $sessionTable . '.class_date',
                $sessionTable . '.start_time',
                $sessionTable . '.session_type',
                $sessionTable . '.week_number',
                $attendanceTable . '.status',
                $attendanceTable . '.verification_status',
                $attendanceTable . '.created_at'
            )
            ->orderByDesc($sessionTable . '.class_date')
            ->limit(10)
            ->get()
            ->map(function ($item) {
                $displayStatus = ($item->verification_status ?? 'Pending') === 'Rejected'
                    ? 'Absent'
                    : $item->status;

                $sessionType = ucfirst(strtolower($item->session_type ?? 'Lecture'));
                $label = $sessionType;

                $weekNumber = $item->week_number ?? $item->id;

                return [
                    'session' => $label . ' Week ' . $weekNumber,
                    'date' => Carbon::parse($item->class_date)->format('j F Y'),
                    'time' => $item->created_at
                        ? Carbon::parse($item->created_at)->format('g:i a')
                        : '-',
                    'status' => $displayStatus,
                ];
            });

        $now = Carbon::now();

        $currentSession = DB::table($sessionTable)
            ->where($sessionColumn, $subjectId)
            ->orderBy('class_date')
            ->orderBy('start_time')
            ->get()
            ->first(function ($session) use ($now) {
                $sessionEnd = Carbon::parse($session->class_date . ' ' . $session->end_time);
                return $sessionEnd->gte($now);
            });

        if (!$currentSession) {
            $currentSession = DB::table($sessionTable)
                ->where($sessionColumn, $subjectId)
                ->orderByDesc('class_date')
                ->orderByDesc('start_time')
                ->first();
        }

        $activeCode = null;
        $codeTableExists = !$isModule || Schema::hasTable('module_attendance_codes');

        if ($currentSession && $codeTableExists) {
            $activeCode = $codeModel::where($sessionForeignKey, $currentSession->id)
                ->where('expires_at', '>', $now)
                ->latest()
                ->first();
        }

        return response()->json([
            'student_name' => $student?->student_name ?? '-',
            'matric_number' => $student?->matric_number ?? '-',
            'programme' => $student?->programme ?? '-',
            'present_count' => $present,
            'late_count' => $late,
            'absent_count' => $absent,
            'classes_attend' => $attended,
            'total_classes' => $totalClasses,
            'attendance_rate' => $attendanceRate,
            'current_session_title' => $currentSession
                ? ucfirst(strtolower($currentSession->session_type ?? 'Lecture')) . ' Session - ' . Carbon::parse($currentSession->class_date)->format('l, j F Y')
                : '-',
            'current_session_date' => $currentSession
                ? Carbon::parse($currentSession->class_date)->format('j F Y')
                : '-',
            'current_session_time' => $currentSession
                ? Carbon::parse($currentSession->start_time)->format('g:i a') . ' - ' . Carbon::parse($currentSession->end_time)->format('g:i a')
                : '-',
            'active_code' => $activeCode->code ?? '-',
            'recent_records' => $recentRecords,
        ]);
    }

    /**
     * Student submits attendance code.
     */
    public function submitAttendance(Request $request)
    {
        $request->validate([
            'student_id' => 'required|exists:students,id',
            'subject_id' => 'required|integer',
            'attendance_type' => 'required|in:course,module',
            'code' => 'required',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $resolvedStudentId = $this->resolveStudentId($request->student_id);

        if (!$resolvedStudentId) {
            return response()->json([
                'message' => 'Student record not found',
            ], 404);
        }

        $isModule = $request->attendance_type === 'module';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;
        $sessionModel = $isModule ? ModuleSchedule::class : ClassSession::class;
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';
        $sessionColumn = $isModule ? 'module_id' : 'subject_id';

        $attendanceCode = $codeModel::where('code', Str::upper($request->code))
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (!$attendanceCode) {
            return response()->json([
                'message' => 'Invalid or expired attendance code',
            ], 422);
        }

        $session = $sessionModel::find($attendanceCode->{$sessionForeignKey});

        if (!$session || $session->{$sessionColumn} != $request->subject_id) {
            return response()->json([
                'message' => 'Attendance code does not match the selected class',
            ], 422);
        }

        $alreadySubmitted = DB::table($attendanceTable)
            ->where('student_id', $resolvedStudentId)
            ->where($sessionForeignKey, $attendanceCode->{$sessionForeignKey})
            ->exists();

        if ($alreadySubmitted) {
            return response()->json([
                'message' => 'Attendance has already been submitted for this class',
            ], 422);
        }

        $now = Carbon::now();
        $classStart = Carbon::parse($session->class_date . ' ' . $session->start_time);
        $lateThreshold = (clone $classStart)->addMinutes(15);

        $status = $now->gt($lateThreshold) ? 'Late' : 'Present';

        $latitude = $request->latitude;
        $longitude = $request->longitude;
        $locationName = null;

        if (!is_null($latitude) && !is_null($longitude)) {
            $locationName = $this->getLocationName($latitude, $longitude);
        }

        $attendanceData = [
            'student_id' => $resolvedStudentId,
            $sessionForeignKey => $attendanceCode->{$sessionForeignKey},
            'status' => $status,
            'created_at' => Carbon::now(),
            'updated_at' => Carbon::now(),
        ];

        if (Schema::hasColumn($attendanceTable, 'latitude')) {
            $attendanceData['latitude'] = $latitude;
        }

        if (Schema::hasColumn($attendanceTable, 'longitude')) {
            $attendanceData['longitude'] = $longitude;
        }

        if (Schema::hasColumn($attendanceTable, 'location_name')) {
            $attendanceData['location_name'] = $locationName;
        }

        DB::table($attendanceTable)->insert($attendanceData);

        return response()->json([
            'message' => 'Attendance submitted successfully',
            'status' => $status,
            'attendance_type' => $request->attendance_type,
            'subject_id' => $request->subject_id,
            'location_name' => $locationName ?? 'Location verified successfully',
        ]);
    }

    /**
     * Lecturer approves or rejects a student's attendance submission.
     */
    public function updateAttendanceStatus(Request $request, $attendanceId)
    {
        $request->validate([
            'status' => 'required|in:Approved,Rejected',
            'attendance_type' => 'nullable|in:course,module',
        ]);

        $attendanceType = $request->input('attendance_type', 'course');
        $attendanceTable = $attendanceType === 'module' ? 'module_attendances' : 'attendances';

        $attendance = DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'Attendance record not found'
            ], 404);
        }

        DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->update([
                'verification_status' => $request->status,
                'updated_at' => Carbon::now()
            ]);

        return response()->json([
            'message' => 'Attendance status updated successfully',
            'attendance_id' => $attendanceId,
            'new_status' => $request->status
        ]);
    }

    /**
     * Lecturer updates a student's attendance record from the history page.
     */
    public function updateAttendanceRecord(Request $request, $attendanceId)
    {
        $request->validate([
            'status' => 'required|in:Present,Late,Absent',
            'attendance_type' => 'nullable|in:course,module',
        ]);

        $attendanceType = $request->input('attendance_type', 'course');
        $attendanceTable = $attendanceType === 'module' ? 'module_attendances' : 'attendances';

        $attendance = DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'Attendance record not found'
            ], 404);
        }

        $verificationStatus = $request->status === 'Absent'
            ? 'Rejected'
            : 'Approved';

        DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->update([
                'status' => $request->status,
                'verification_status' => $verificationStatus,
                'updated_at' => Carbon::now()
            ]);

        return response()->json([
            'message' => 'Attendance record updated successfully',
            'attendance_id' => $attendanceId,
            'status' => $request->status,
            'verification_status' => $verificationStatus
        ]);
    }

    /**
     * Lecturer deletes a student's attendance record from the history page.
     */
    public function deleteAttendanceRecord(Request $request, $attendanceId)
    {
        $attendanceType = $request->input('attendance_type', $request->query('attendance_type', 'course'));
        $attendanceTable = $attendanceType === 'module' ? 'module_attendances' : 'attendances';

        $attendance = DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'Attendance record not found'
            ], 404);
        }

        DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->delete();

        return response()->json([
            'message' => 'Attendance record deleted successfully',
            'attendance_id' => $attendanceId
        ]);
    }

    private function getLocationName($lat, $lon)
    {
        $response = Http::withHeaders([
            'User-Agent' => 'SAMS Attendance System'
        ])->get('https://nominatim.openstreetmap.org/reverse', [
            'lat' => $lat,
            'lon' => $lon,
            'format' => 'json'
        ]);

        if (!$response->ok()) {
            return 'Location unavailable';
        }

        $data = $response->json();

        if (!isset($data['display_name'])) {
            return 'Unknown location';
        }

        $location = explode(',', $data['display_name'])[0];

        return $location;
    }

    /**
     * Get classes (course + module) assigned to a lecturer
     */
    public function getLecturerClasses($lecturerId)
    {
        $lecturer = DB::table('lecturers')->where('id', $lecturerId)->first();
        $userIdForSessions = $lecturer?->user_id ?? $lecturerId;

        // Ambil subjects yang lecturer ni assigned to
        $subjects = DB::table('subjects')
            ->where('lecturer_id', $lecturerId)  // subjects.lecturer_id = lecturers.id
            ->get()
            ->map(function ($subject) use ($userIdForSessions) {
                // Ambil sessions untuk subject ni
                $sessions = DB::table('class_sessions')
                    ->where('subject_id', $subject->id)
                    ->where('lecturer_id', $userIdForSessions)
                    ->orderBy('class_date')
                    ->orderBy('start_time')
                    ->get()
                    ->map(function ($class) use ($subject) {
                        return [
                            'id'              => $class->id,
                            'subject_id'      => $subject->id,
                            'subject_code'    => $subject->code,
                            'subject_name'    => $subject->name,
                            'class_date'      => $class->class_date,
                            'start_time'      => $class->start_time,
                            'end_time'        => $class->end_time,
                            'session_type'    => $class->session_type ?? '',
                            'week_number'     => $class->week_number ?? '',
                            'attendance_type' => 'course',
                        ];
                    });

                // Kalau takde session pun, still return subject dengan placeholder
                if ($sessions->isEmpty()) {
                    return [[
                        'id'              => null,
                        'subject_id'      => $subject->id,
                        'subject_code'    => $subject->code,
                        'subject_name'    => $subject->name,
                        'class_date'      => null,
                        'start_time'      => null,
                        'end_time'        => null,
                        'session_type'    => '',
                        'week_number'     => '',
                        'attendance_type' => 'course',
                    ]];
                }

                return $sessions->toArray();
            })
            ->flatten(1);

        // Modules — sama macam sebelum
        $moduleClasses = DB::table('module_schedules')
            ->join('modules', 'module_schedules.module_id', '=', 'modules.id')
            ->where('module_schedules.lecturer_id', $lecturerId)
            ->orderBy('module_schedules.class_date')
            ->orderBy('module_schedules.start_time')
            ->select(
                'module_schedules.id',
                'module_schedules.module_id',
                'module_schedules.class_date',
                'module_schedules.start_time',
                'module_schedules.end_time',
                'module_schedules.session_type',
                'module_schedules.week_number',
                'modules.code as module_code',
                'modules.name as module_name'
            )
            ->get()
            ->map(function ($class) {
                return [
                    'id'              => $class->id,
                    'module_id'       => $class->module_id,
                    'module_code'     => $class->module_code,
                    'module_name'     => $class->module_name,
                    'class_date'      => $class->class_date,
                    'start_time'      => $class->start_time,
                    'end_time'        => $class->end_time,
                    'session_type'    => $class->session_type ?? '',
                    'week_number'     => $class->week_number ?? '',
                    'attendance_type' => 'module',
                ];
            });

        return response()->json(
            $subjects->concat($moduleClasses)->values()
        );
    }

    /**
     * Get subjects registered by a student
     */
    public function getRegisteredSubjects($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([]);
        }

        $registrations = DB::table('subject_registrations')
            ->join('subjects', 'subject_registrations.subject_id', '=', 'subjects.id')
            ->where('subject_registrations.student_id', $studentId)
            ->where('subject_registrations.approval_status', 'Approved')
            ->select(
                'subject_registrations.id',
                'subject_registrations.student_id',
                'subject_registrations.subject_id',
                'subjects.code',
                'subjects.name'
            )
            ->orderBy('subjects.code')
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'subject_id' => $item->subject_id,
                    'code' => $item->code,
                    'name' => $item->name,
                ];
            });

        return response()->json($registrations);
    }

    /**
     * Get modules registered by a student
     */
    public function getRegisteredModules($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([]);
        }

        $modules = DB::table('module_registrations')
            ->join('modules', 'module_registrations.module_id', '=', 'modules.id')
            ->where('module_registrations.student_id', $studentId)
            ->select(
                'module_registrations.id',
                'module_registrations.student_id',
                'module_registrations.module_id',
                'modules.code',
                'modules.name'
            )
            ->orderBy('modules.code')
            ->orderByDesc('module_registrations.id')
            ->get()
            ->unique('module_id')
            ->values()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'module_id' => $item->module_id,
                    'code' => $item->code,
                    'name' => $item->name,
                ];
            });

        return response()->json($modules);
    }

    /**
     * View course/module details
     */
    public function viewCourse($moduleId)
    {
        $course = DB::table('modules')
            ->where('id', $moduleId)
            ->select('id', 'code', 'name')
            ->first();

        if (!$course) {
            return response()->json([
                'message' => 'Course not found'
            ], 404);
        }

        return response()->json($course);
    }

    /**
     * Get student profile
     */
    public function getStudentInfo($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([
                'message' => 'Student not found'
            ], 404);
        }

        $query = DB::table('students')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('students.id', $studentId);

        $selects = [
            'users.name',
            'students.matric_no as matric',
            'students.programme as program',
        ];

        if (Schema::hasColumn('students', 'advisor')) {
            $selects[] = 'students.advisor';
        }

        $student = $query->select($selects)->first();

        if (!$student) {
            return response()->json([
                'message' => 'Student not found'
            ], 404);
        }

        return response()->json($student);
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
                ->where('matric_no', $user->matric_number)
                ->value('id');

            if ($studentByMatric) {
                return (int) $studentByMatric;
            }
        }

        return null;
    }

    public function createClassSession(Request $request)
    {
        $request->validate([
            'subject_id'   => 'required|exists:subjects,id',
            'lecturer_id'  => 'required|integer',
            'section'      => 'required|string',
            'class_date'   => 'required|date',
            'start_time'   => 'required',
            'end_time'     => 'required',
            'venue'        => 'required|string',
            'session_type' => 'nullable|string',
            'week_number'  => 'nullable|integer',
        ]);

        $lecturer = DB::table('lecturers')->where('id', $request->lecturer_id)->first();
        $userIdForSessions = $lecturer?->user_id ?? $request->lecturer_id;

        $id = DB::table('class_sessions')->insertGetId([
            'subject_id'   => $request->subject_id,
            'lecturer_id'  => $userIdForSessions,
            'section'      => $request->section,
            'class_date'   => $request->class_date,
            'start_time'   => $request->start_time,
            'end_time'     => $request->end_time,
            'venue'        => $request->venue,
            'session_type' => $request->session_type ?? 'Lecture',
            'week_number'  => $request->week_number,
            'created_at'   => now(),
            'updated_at'   => now(),
        ]);

        return response()->json([
            'message' => 'Class session created successfully',
            'id'      => $id,
        ], 201);
    }
}
