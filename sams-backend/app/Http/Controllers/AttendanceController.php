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
    // Generate and save attendance code for a class session.
     
    public function generateCode(Request $request)
    {
        // Validate input — pastikan jenis attendance dan session ID betul
        $request->validate([
            'attendance_type' => 'nullable|in:course,module',
            'class_session_id' => 'nullable|exists:class_sessions,id',
            'module_session_id' => 'nullable|exists:module_schedules,id',
        ]);

        // Tentukan sama ada ini untuk module atau course biasa
        $attendanceType = $request->input('attendance_type', 'course');
        $isModule = $attendanceType === 'module';
        $sessionIdField = $isModule ? 'module_session_id' : 'class_session_id';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;
        $sessionModel = $isModule ? ModuleSchedule::class : ClassSession::class;

        $sessionId = $request->input($sessionIdField);

        // Kalau session ID takde, return error
        if (!$sessionId) {
            return response()->json([
                'message' => $isModule
                    ? 'module_session_id is required for module attendance.'
                    : 'class_session_id is required for course attendance.',
            ], 422);
        }

        // Ambil data sesi kelas berdasarkan ID
        $classSession = $sessionModel::findOrFail($sessionId);

        $now = Carbon::now();
        $classStart = Carbon::parse($classSession->class_date . ' ' . $classSession->start_time);
        $classEnd = Carbon::parse($classSession->class_date . ' ' . $classSession->end_time);

        // Kod hanya boleh dijana semasa kelas sedang berlangsung
        if ($now->lt($classStart) || $now->gt($classEnd)) {
            return response()->json([
                'message' => 'Attendance code can only be generated during class time.',
                'class_date' => $classSession->class_date,
                'start_time' => $classSession->start_time,
                'end_time' => $classSession->end_time,
            ], 422);
        }

        // Jana kod rawak 6 huruf besar
        $code = Str::upper(Str::random(6));

        // Simpan kod dalam database — expired bila kelas habis
        $attendanceCode = $codeModel::create([
            $sessionIdField => $sessionId,
            'code' => $code,
            'expires_at' => $classEnd,       // Kod expired bila kelas tamat
            'generated_at' => $now,          // Masa kod dijana — untuk kira lambat/awal
        ]);

        return response()->json([
            'message' => 'Attendance code generated successfully',
            'attendance_type' => $attendanceType,
            'attendance_code' => $attendanceCode->code,
            $sessionIdField => $attendanceCode->{$sessionIdField},
            'expires_at' => $attendanceCode->expires_at,
            'generated_at' => $attendanceCode->generated_at,
        ]);
    }

    
    // Ambil senarai submission kehadiran untuk satu sesi kelas.
    public function getSubmissions(Request $request, $classSessionId)
    {
        // Determine jenis attendance — course atau module
        $attendanceType = $request->query('type', 'course');
        $isModule = $attendanceType === 'module';
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';

        // Query submissions — join dengan students dan users untuk dapat nama & matric
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
                // Kalau nama tak ada, fallback ke 'Unknown Student'
                DB::raw("COALESCE(users.name, 'Unknown Student') as student_name"),
                DB::raw("COALESCE(students.matric_no, '-') as matric_no")
            )
            ->orderBy($attendanceTable . '.created_at')
            ->get()
            ->map(function ($item) {
                // Format data untuk response yang kemas
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

    
     // Ambil data dashboard kehadiran untuk seorang pelajar bagi sesuatu subjek.

    public function getStudentAttendance(Request $request, $studentId, $subjectId)
    {
        // Resolve student ID — boleh guna user_id atau student_id
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([
                'message' => 'Student record not found',
            ], 404);
        }

        // Set table dan column names based on attendance type
        $attendanceType = $request->query('type', 'course');
        $isModule = $attendanceType === 'module';
        $sessionTable = $isModule ? 'module_schedules' : 'class_sessions';
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';
        $sessionColumn = $isModule ? 'module_id' : 'subject_id';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;

        // Ambil maklumat asas pelajar — nama, matric, program
        $student = DB::table('students')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('students.id', $studentId)
            ->select(
                'users.name as student_name',
                'students.matric_no as matric_number',
                'students.programme'
            )
            ->first();

        // Untuk module: kira hanya sesi yang pelajar daftar
        // Untuk course: kira semua sesi bawah subjek tu
        if ($isModule) {
            $sessions = DB::table('module_registrations')
                ->where('student_id', $studentId)
                ->where('module_id', $subjectId)
                ->pluck('module_schedule_id');
        } else {
            $sessions = DB::table($sessionTable)
                ->where($sessionColumn, $subjectId)
                ->pluck('id');
        }

        // Ambil semua rekod kehadiran pelajar untuk sesi-sesi berkenaan
        $records = DB::table($attendanceTable)
            ->where('student_id', $studentId)
            ->whereIn($sessionForeignKey, $sessions)
            ->get();

        // Kira hadir — status Present DAN verification Approved
        $present = $records
            ->filter(fn($record) => $record->status === 'Present' && ($record->verification_status ?? 'Pending') === 'Approved')
            ->count();

        // Kira lambat — status Late DAN verification Approved
        $late = $records
            ->filter(fn($record) => $record->status === 'Late' && ($record->verification_status ?? 'Pending') === 'Approved')
            ->count();

        // Kira absent — status Absent ATAU verification Rejected
        $absent = $records
            ->filter(fn($record) => $record->status === 'Absent' || (($record->verification_status ?? 'Pending') === 'Rejected'))
            ->count();

        $totalClasses = $sessions->count();
        $attended = $present + $late; // Hadir = Present + Late

        // Kira peratusan kehadiran
        $attendanceRate = $totalClasses > 0
            ? round(($attended / $totalClasses) * 100) . '%'
            : '0%';

        // Ambil 10 rekod kehadiran terkini untuk display dalam history
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
                $verificationStatus = $item->verification_status ?? 'Pending';

                // Map verification status ke display status yang sesuai
                if ($verificationStatus === 'Rejected') {
                    $displayStatus = 'Absent';       // Rejected = dikira Absent
                } elseif ($verificationStatus === 'Pending') {
                    $displayStatus = 'Pending';      // Belum disahkan lagi
                } else {
                    $displayStatus = $item->status;  // Guna status asal (Present/Late)
                }

                // Format label sesi, contoh: "Lecture Week 3"
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

        // Cari sesi kelas semasa atau akan datang yang terdekat
        $currentSession = DB::table($sessionTable)
            ->where($sessionColumn, $subjectId)
            ->orderBy('class_date')
            ->orderBy('start_time')
            ->get()
            ->first(function ($session) use ($now) {
                // Ambil sesi yang belum tamat lagi
                $sessionEnd = Carbon::parse($session->class_date . ' ' . $session->end_time);
                return $sessionEnd->gte($now);
            });

        // Kalau takde sesi akan datang, guna sesi yang paling terkini
        if (!$currentSession) {
            $currentSession = DB::table($sessionTable)
                ->where($sessionColumn, $subjectId)
                ->orderByDesc('class_date')
                ->orderByDesc('start_time')
                ->first();
        }

        // Cek sama ada ada kod kehadiran yang masih aktif untuk sesi semasa
        $activeCode = null;
        $codeTableExists = !$isModule || Schema::hasTable('module_attendance_codes');

        if ($currentSession && $codeTableExists) {
            $activeCode = $codeModel::where($sessionForeignKey, $currentSession->id)
                ->where('expires_at', '>', $now) // Hanya kod yang belum expired
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

    // Student submits attendance code
     
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

        // Resolve student ID dulu sebelum proceed
        $resolvedStudentId = $this->resolveStudentId($request->student_id);

        if (!$resolvedStudentId) {
            return response()->json([
                'message' => 'Student record not found',
            ], 404);
        }

        // Set model dan table names ikut attendance type
        $isModule = $request->attendance_type === 'module';
        $codeModel = $isModule ? ModuleAttendanceCode::class : AttendanceCode::class;
        $sessionModel = $isModule ? ModuleSchedule::class : ClassSession::class;
        $attendanceTable = $isModule ? 'module_attendances' : 'attendances';
        $sessionForeignKey = $isModule ? 'module_session_id' : 'class_session_id';
        $sessionColumn = $isModule ? 'module_id' : 'subject_id';

        // Cari kod dalam database — pastikan kod tu still valid (belum expired)
        $attendanceCode = $codeModel::where('code', Str::upper($request->code))
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (!$attendanceCode) {
            return response()->json([
                'message' => 'Invalid or expired attendance code',
            ], 422);
        }

        // Verify bahawa kod tu memang untuk subjek yang betul
        $session = $sessionModel::find($attendanceCode->{$sessionForeignKey});

        if (!$session || $session->{$sessionColumn} != $request->subject_id) {
            return response()->json([
                'message' => 'Attendance code does not match the selected class',
            ], 422);
        }

        // Cek kalau pelajar dah submit attendance untuk sesi ni — tak boleh submit dua kali
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

        // Kira status — Late kalau submit lebih dari 15 minit selepas kod dijana
        $codeGeneratedAt = Carbon::parse($attendanceCode->generated_at);
        $lateThreshold = (clone $codeGeneratedAt)->addMinutes(15);

        $computedStatus = $now->gt($lateThreshold) ? 'Late' : 'Present';

        // Module attendance perlu lecturer verify dulu — course terus Approved
        $verificationStatus = $isModule ? 'Pending' : 'Approved';

        // Kalau ada koordinat GPS, tukar jadi nama lokasi
        $latitude = $request->latitude;
        $longitude = $request->longitude;
        $locationName = null;

        if (!is_null($latitude) && !is_null($longitude)) {
            $locationName = $this->getLocationName($latitude, $longitude);
        }

        // Prepare data untuk insert ke database
        $attendanceData = [
            'student_id' => $resolvedStudentId,
            $sessionForeignKey => $attendanceCode->{$sessionForeignKey},
            'status' => $computedStatus,
            'verification_status' => $verificationStatus,
            'created_at' => Carbon::now(),
            'updated_at' => Carbon::now(),
        ];

        // Tambah location columns kalau wujud dalam table (optional fields)
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
            'message' => $isModule
                ? 'Attendance submitted successfully. Waiting for lecturer verification.'
                : 'Attendance submitted successfully',
            'status' => $isModule ? 'Pending' : $computedStatus,
            'attendance_type' => $request->attendance_type,
            'subject_id' => $request->subject_id,
            'location_name' => $locationName ?? 'Location verified successfully',
        ]);
    }

    // Lecturer approves or rejects a student's attendance submission.
    
    public function updateAttendanceStatus(Request $request, $attendanceId)
    {
        $request->validate([
            'status' => 'required|in:Approved,Rejected',
            'attendance_type' => 'nullable|in:course,module',
        ]);

        // Tentukan table berdasarkan jenis attendance
        $attendanceType = $request->input('attendance_type', 'course');
        $attendanceTable = $attendanceType === 'module' ? 'module_attendances' : 'attendances';

        // Pastikan rekod tu memang wujud dalam database
        $attendance = DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'Attendance record not found'
            ], 404);
        }

        // Update verification status — Approved atau Rejected
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

    // Lecturer updates a student's attendance record from the history page.
   
    public function updateAttendanceRecord(Request $request, $attendanceId)
    {
        $request->validate([
            'status' => 'required|in:Present,Late,Absent',
            'attendance_type' => 'required|in:course,module',
        ]);

        $attendanceTable = $request->attendance_type === 'module'
            ? 'module_attendances'
            : 'attendances';

        // Cek rekod wujud dulu
        $attendance = DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'Attendance record not found',
                'table' => $attendanceTable
            ], 404);
        }

        // Kalau Absent, set verification ke Rejected — selain tu set Approved
        $verificationStatus = $request->status === 'Absent'
            ? 'Rejected'
            : 'Approved';

        DB::table($attendanceTable)
            ->where('id', $attendanceId)
            ->update([
                'status' => $request->status,
                'verification_status' => $verificationStatus,
                'updated_at' => now(),
            ]);

        return response()->json([
            'message' => 'Attendance updated successfully',
            'id' => $attendanceId,
            'status' => $request->status
        ]);
    }

    // Lecturer deletes a student's attendance record from the history page.
     
    public function deleteAttendanceRecord(Request $request, $attendanceId)
    {
        // Support both query param dan request body untuk attendance_type
        $attendanceType = $request->input('attendance_type', $request->query('attendance_type', 'course'));
        $attendanceTable = $attendanceType === 'module' ? 'module_attendances' : 'attendances';

        // Pastikan rekod wujud sebelum delete
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

    // Convert koordinat GPS (lat/lon) kepada nama lokasi guna Nominatim API.
     
    private function getLocationName($lat, $lon)
    {
        // Guna OpenStreetMap Nominatim untuk reverse geocoding
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

        // Ambil bahagian pertama je dari display_name (nama bangunan/jalan)
        $location = explode(',', $data['display_name'])[0];

        return $location;
    }

    //Get classes (course + module) assigned to a lecturer.
   
    public function getLecturerClasses($lecturerId)
    {
        // Lecturer boleh ada user_id yang berbeza dari lecturer_id
        $lecturer = DB::table('lecturers')->where('id', $lecturerId)->first();
        $userIdForSessions = $lecturer?->user_id ?? $lecturerId;

        // Ambil semua subjek yang diajar oleh lecturer ni
        $subjects = DB::table('subjects')
            ->where('lecturer_id', $lecturerId)
            ->get()
            ->map(function ($subject) use ($userIdForSessions) {
                // Untuk tiap subjek, ambil semua sesi kelas
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

                // Kalau takde sesi lagi, return placeholder supaya subjek still nampak
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

        // Ambil module classes yang diajar oleh lecturer ni
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

        // Gabungkan course sessions dan module classes dalam satu response
        return response()->json(
            $subjects->concat($moduleClasses)->values()
        );
    }

    // Get subjects registered by a student.
   
    public function getRegisteredSubjects($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json([]);
        }

        // Hanya ambil subjek yang dah di-approve — yang pending/rejected tak masuk
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

    // Get modules registered by a student
   
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
            ->unique('module_id')    // Buang duplicate — ambil yang terbaru
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

    // View course/module details.
    
    public function viewCourse($moduleId)
    {
        $course = DB::table('modules')
            ->where('id', $moduleId)
            ->select('id', 'code', 'name')
            ->first();

        // Kalau module tak jumpa, return 404
        if (!$course) {
            return response()->json([
                'message' => 'Course not found'
            ], 404);
        }

        return response()->json($course);
    }

    // Get student profile.
   
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

        // Column 'advisor' tak semestinya ada — cek dulu sebelum select
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

    // Resolve student ID — boleh handle sama ada student_id, user_id, atau matric number.
    
    private function resolveStudentId($incomingStudentId): ?int
    {
        if (!$incomingStudentId) {
            return null;
        }

        $incomingStudentId = (int) $incomingStudentId;

        // Cuba cari terus guna students.id
        $directStudentId = DB::table('students')
            ->where('id', $incomingStudentId)
            ->value('id');

        if ($directStudentId) {
            return (int) $directStudentId;
        }

        // Cuba cari guna user_id pula
        $studentByUserId = DB::table('students')
            ->where('user_id', $incomingStudentId)
            ->value('id');

        if ($studentByUserId) {
            return (int) $studentByUserId;
        }

        // Last resort — cari guna matric number dalam users table
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

        // Tak jumpa langsung — return null
        return null;
    }

    // Create a new class session for a subject.
    
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

        // Guna user_id lecturer untuk class_sessions table (bukan lecturer_id)
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
            'session_type' => $request->session_type ?? 'Lecture', // Default: Lecture
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
