<?php

namespace App\Http\Controllers;

use App\Models\Subject;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;

class RegistrationController extends Controller
{
    public function index(Request $request)
    {
        $studentId = $request->query('student_id');
        $registeredSubjectIds = [];
        $rejectedSubjects = [];

        if ($studentId && Schema::hasTable('subject_registrations')) {
            $registrations = DB::table('subject_registrations')
                ->where('student_id', $studentId)
                ->get();

            $registeredSubjectIds = $registrations
                ->pluck('subject_id')
                ->map(fn ($id) => (int) $id)
                ->all();

            if (Schema::hasColumn('subject_registrations', 'rejection_reason')) {
                $rejectedSubjects = $registrations
                    ->filter(fn ($row) => ($row->approval_status ?? null) === 'Rejected')
                    ->mapWithKeys(fn ($row) => [
                        (int) $row->subject_id => (string) ($row->rejection_reason ?? ''),
                    ])
                    ->all();
            }
        }

        $subjects = Subject::orderBy('code')->get();

        return $subjects->map(function (Subject $subject) use ($registeredSubjectIds, $rejectedSubjects) {
            return [
                'id' => $subject->id,
                'code' => $subject->code,
                'name' => $subject->name,
                'credit_hour' => $subject->credit_hour,
                'examination' => $subject->examination ?? null,
                'exam_date' => $subject->exam_date ?? null,
                'exam_period' => $subject->exam_period ?? null,
                'instructors' => $this->getSubjectInstructors($subject->id),
                'is_registered' => in_array((int) $subject->id, $registeredSubjectIds, true),
                'rejection_reason' => $rejectedSubjects[(int) $subject->id] ?? null,
            ];
        });
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'code' => ['required', 'string', 'max:255', Rule::unique('subjects', 'code')],
            'name' => ['required', 'string', 'max:255'],
            'credit_hour' => ['required', 'integer', 'min:1'],
            'examination' => ['nullable', 'boolean'],
            'exam_date' => ['nullable', 'date'],
            'exam_period' => ['nullable', 'in:AM,PM'],
            'sections' => ['nullable', 'array'],
            'sections.*.name' => ['required_with:sections', 'string', 'max:50'],
            'sections.*.day' => ['nullable', 'string', 'max:20'],
            'sections.*.time' => ['nullable', 'string', 'max:20'],
            'sections.*.location' => ['nullable', 'string', 'max:50'],
            'sections.*.capacity' => ['nullable', 'integer', 'min:0'],
            'sections.*.instructor' => ['nullable', 'string', 'max:255'],
            'tutorials' => ['nullable', 'array'],
            'tutorials.*.name' => ['required_with:tutorials', 'string', 'max:50'],
            'tutorials.*.day' => ['nullable', 'string', 'max:20'],
            'tutorials.*.time' => ['nullable', 'string', 'max:20'],
            'tutorials.*.location' => ['nullable', 'string', 'max:50'],
            'tutorials.*.capacity' => ['nullable', 'integer', 'min:0'],
            'tutorials.*.instructor' => ['nullable', 'string', 'max:255'],
        ]);

        return DB::transaction(function () use ($validated) {
            $subjectData = [
                'code' => strtoupper($validated['code']),
                'name' => $validated['name'],
                'credit_hour' => $validated['credit_hour'],
            ];

            foreach (['examination', 'exam_date', 'exam_period'] as $column) {
                if (Schema::hasColumn('subjects', $column)) {
                    $subjectData[$column] = $validated[$column] ?? null;
                }
            }

            $subject = Subject::create($subjectData);

            $this->insertClassEntries(
                'lecture_section',
                $subject->id,
                $validated['sections'] ?? []
            );
            $this->insertClassEntries(
                'lab_section',
                $subject->id,
                $validated['tutorials'] ?? []
            );

            return response()->json([
                'message' => 'Subject created successfully',
                'data' => $subject,
            ], 201);
        });
    }

    public function show($id)
    {
        $subject = Subject::findOrFail($id);
        $sections = $this->getSubjectTimetableEntries('lecture_section', $subject->id, 'L');
        $tutorials = $this->getSubjectTimetableEntries('lab_section', $subject->id, 'B');
        $legacySessions = $this->getSubjectTimetableEntries('class_sessions', $subject->id);

        return response()->json([
            'id' => $subject->id,
            'code' => $subject->code,
            'name' => $subject->name,
            'credit_hour' => $subject->credit_hour,
            'examination' => $subject->examination ?? null,
            'exam_date' => $subject->exam_date ?? null,
            'exam_period' => $subject->exam_period ?? null,
            'instructors' => $this->getSubjectInstructors($subject->id),
            'sections' => $sections,
            'tutorials' => $tutorials,
            'timetable' => array_merge($sections, $tutorials, $legacySessions),
        ]);
    }

    public function update(Request $request, $id)
    {
        $subject = Subject::findOrFail($id);

        $validated = $request->validate([
            'code' => ['required', 'string', 'max:255', Rule::unique('subjects', 'code')->ignore($subject->id)],
            'name' => ['required', 'string', 'max:255'],
            'credit_hour' => ['required', 'integer', 'min:1'],
            'examination' => ['nullable', 'boolean'],
            'exam_date' => ['nullable', 'date'],
            'exam_period' => ['nullable', 'in:AM,PM'],
            'sections' => ['nullable', 'array'],
            'sections.*.name' => ['required_with:sections', 'string', 'max:50'],
            'sections.*.day' => ['nullable', 'string', 'max:20'],
            'sections.*.time' => ['nullable', 'string', 'max:20'],
            'sections.*.location' => ['nullable', 'string', 'max:50'],
            'sections.*.capacity' => ['nullable', 'integer', 'min:0'],
            'sections.*.instructor' => ['nullable', 'string', 'max:255'],
            'tutorials' => ['nullable', 'array'],
            'tutorials.*.name' => ['required_with:tutorials', 'string', 'max:50'],
            'tutorials.*.day' => ['nullable', 'string', 'max:20'],
            'tutorials.*.time' => ['nullable', 'string', 'max:20'],
            'tutorials.*.location' => ['nullable', 'string', 'max:50'],
            'tutorials.*.capacity' => ['nullable', 'integer', 'min:0'],
            'tutorials.*.instructor' => ['nullable', 'string', 'max:255'],
        ]);

        return DB::transaction(function () use ($subject, $validated) {
            $subjectData = [
                'code' => strtoupper($validated['code']),
                'name' => $validated['name'],
                'credit_hour' => $validated['credit_hour'],
            ];

            foreach (['examination', 'exam_date', 'exam_period'] as $column) {
                if (Schema::hasColumn('subjects', $column)) {
                    $subjectData[$column] = $validated[$column] ?? null;
                }
            }

            $subject->update($subjectData);
            $this->replaceClassEntries('lecture_section', $subject->id, $validated['sections'] ?? []);
            $this->replaceClassEntries('lab_section', $subject->id, $validated['tutorials'] ?? []);

            return response()->json([
                'message' => 'Subject updated successfully',
                'data' => $subject->fresh(),
            ]);
        });
    }

    public function destroy($id)
    {
        $subject = Subject::findOrFail($id);
        $subject->delete();

        return response()->json(['message' => 'Subject deleted successfully']);
    }

    public function register(Request $request)
    {
        $validated = $request->validate([
            'student_id' => ['required', 'integer', 'exists:students,id'],
            'subject_id' => ['required', 'integer', 'exists:subjects,id'],
            'section' => ['nullable', 'string', 'max:50'],
            'tutorial_lab' => ['nullable', 'string', 'max:50'],
        ]);

        if (!$this->tutorialMatchesLectureSection($validated['section'] ?? null, $validated['tutorial_lab'] ?? null)) {
            return response()->json([
                'message' => 'Tutorial/Lab must match the selected lecture section.',
            ], 422);
        }

        $clash = $this->findRegistrationClash(
            (int) $validated['student_id'],
            (int) $validated['subject_id'],
            $validated['section'] ?? null,
            $validated['tutorial_lab'] ?? null
        );

        if ($clash !== null) {
            return response()->json([
                'message' => 'This subject will clash with '
                    . $clash['code'] . ' - ' . strtoupper($clash['name'])
                    . ' on ' . $clash['day'] . ' at ' . $clash['time'] . '.',
            ], 422);
        }

        $data = [
            'student_id' => $validated['student_id'],
            'subject_id' => $validated['subject_id'],
        ];

        foreach (['approval_status', 'registrar_id', 'section', 'tutorial_lab'] as $column) {
            if (!Schema::hasColumn('subject_registrations', $column)) {
                continue;
            }

            $data[$column] = match ($column) {
                'approval_status' => 'Pending',
                'section' => $validated['section'] ?? null,
                'tutorial_lab' => $validated['tutorial_lab'] ?? null,
                default => null,
            };
        }

        DB::table('subject_registrations')->updateOrInsert(
            [
                'student_id' => $validated['student_id'],
                'subject_id' => $validated['subject_id'],
            ],
            $data + [
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        return response()->json(['message' => 'Subject registered successfully']);
    }

    public function registeredSubjects($studentId)
    {
        return $this->registeredSubjectRows($studentId, true, true);
    }

    public function registeredStudentsBySubject(Request $request, $subjectId)
    {
        $subject = Subject::findOrFail($subjectId);
        $mode = strtoupper((string) $request->query('mode', ''));
        $slot = trim((string) $request->query('section', ''));

        if (!Schema::hasTable('subject_registrations')) {
            return response()->json([
                'subject' => [
                    'id' => $subject->id,
                    'code' => $subject->code,
                    'name' => $subject->name,
                ],
                'students' => [],
            ]);
        }

        $query = DB::table('subject_registrations')
            ->join('students', 'subject_registrations.student_id', '=', 'students.id')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('subject_registrations.subject_id', $subjectId);

        if (Schema::hasColumn('subject_registrations', 'approval_status')) {
            $query->where('subject_registrations.approval_status', 'Approved');
        } else {
            $query->whereRaw('1 = 0');
        }

        $slotColumn = $mode === 'B' ? 'tutorial_lab' : 'section';
        if ($slot !== '' && Schema::hasColumn('subject_registrations', $slotColumn)) {
            $query->where("subject_registrations.$slotColumn", $slot);
        }

        $selects = [
            'students.id as student_id',
            'users.name',
            'students.matric_no',
            'students.year',
        ];

        foreach (['section', 'tutorial_lab'] as $column) {
            if (Schema::hasColumn('subject_registrations', $column)) {
                $selects[] = "subject_registrations.$column";
            }
        }

        $students = $query
            ->select($selects)
            ->orderBy('users.name')
            ->get()
            ->map(function ($student) {
                return [
                    'student_id' => $student->student_id,
                    'name' => $student->name,
                    'matric_no' => $student->matric_no,
                    'year' => $student->year,
                    'section' => $student->section ?? null,
                    'tutorial_lab' => $student->tutorial_lab ?? null,
                    'advisor' => $this->getStudentAdvisor((int) $student->student_id),
                ];
            });

        return response()->json([
            'subject' => [
                'id' => $subject->id,
                'code' => $subject->code,
                'name' => $subject->name,
            ],
            'slot' => [
                'mode' => $mode,
                'section' => $slot,
            ],
            'students' => $students,
        ]);
    }

    public function removeRegisteredSubject($studentId, $subjectId = null)
    {
        $query = DB::table('subject_registrations')
            ->where('student_id', $studentId);

        if ($subjectId !== null) {
            $query->where('subject_id', $subjectId);
        }

        $query->delete();

        return response()->json([
            'message' => $subjectId === null
                ? 'All subjects removed successfully'
                : 'Subject removed successfully',
        ]);
    }

    public function notifyRegistrar($studentId)
    {
        $pendingQuery = DB::table('subject_registrations')
            ->where('student_id', $studentId);

        if (Schema::hasColumn('subject_registrations', 'approval_status')) {
            $pendingQuery->where('approval_status', 'Pending');
        }

        $pendingRegistrationIds = $pendingQuery->pluck('id');

        if ($pendingRegistrationIds->isEmpty()) {
            return response()->json([
                'message' => 'No pending subject registration to notify.',
            ], 422);
        }

        if (Schema::hasTable('subject_registration_notifications')) {
            DB::table('subject_registration_notifications')->updateOrInsert(
                ['student_id' => $studentId],
                [
                    'pending_count' => $pendingRegistrationIds->count(),
                    'message' => 'Student requested subject registration approval.',
                    'notified_at' => now(),
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }

        return response()->json([
            'message' => 'Faculty registrar has been notified.',
            'pending_count' => $pendingRegistrationIds->count(),
        ]);
    }

    public function approvalRequests(Request $request)
    {
        if (!Schema::hasTable('subject_registrations')) {
            return response()->json([
                'counts' => ['pending' => 0, 'approved' => 0, 'rejected' => 0],
                'students' => [],
            ]);
        }

        $query = DB::table('subject_registrations')
            ->join('students', 'subject_registrations.student_id', '=', 'students.id')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->select(
                'students.id as student_id',
                'users.name',
                'students.matric_no',
                'students.programme',
                'students.year'
            )
            ->groupBy(
                'students.id',
                'users.name',
                'students.matric_no',
                'students.programme',
                'students.year'
            )
            ->orderBy('users.name');

        $search = trim((string) $request->query('search', ''));
        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('users.name', 'like', "%$search%")
                    ->orWhere('students.matric_no', 'like', "%$search%");
            });
        }

        $students = $query->get()->map(function ($student) {
            $registrations = DB::table('subject_registrations')
                ->where('student_id', $student->student_id)
                ->get();

            return [
                'student_id' => $student->student_id,
                'name' => $student->name,
                'matric_no' => $student->matric_no,
                'programme' => $student->programme,
                'year' => $student->year,
                'advisor' => $this->getStudentAdvisor((int) $student->student_id),
                'status' => $this->approvalStatusSummary($registrations),
                'registered_count' => $registrations->count(),
            ];
        });

        return response()->json([
            'counts' => $this->approvalStatusSummary(),
            'students' => $students,
        ]);
    }

    public function studentApprovalSubjects($studentId)
    {
        $subjects = $this->registeredSubjectRows($studentId, true)->map(function ($subject) {
            return $subject + [
                'status' => $subject['approval_status'] ?? 'Pending',
            ];
        });

        return response()->json([
            'student' => $this->approvalStudentInfo($studentId),
            'subjects' => $subjects,
        ]);
    }

    public function updateRegistrationStatus(Request $request, $registrationId = null)
    {
        $validated = $request->validate([
            'status' => ['required', 'in:Pending,Approved,Rejected'],
            'rejection_reason' => ['nullable', 'string', 'max:1000'],
        ]);

        if (!Schema::hasColumn('subject_registrations', 'approval_status')) {
            return response()->json([
                'message' => 'approval_status column is missing. Please run migrations.',
            ], 422);
        }

        $studentId = $request->route('studentId');
        $query = DB::table('subject_registrations');

        if ($studentId !== null) {
            $query->where('student_id', $studentId);
        } else {
            $query->where('id', $registrationId);
        }

        $updateData = [
            'approval_status' => $validated['status'],
            'updated_at' => now(),
        ];

        if (Schema::hasColumn('subject_registrations', 'rejection_reason')) {
            $updateData['rejection_reason'] = $validated['status'] === 'Rejected'
                ? trim((string) ($validated['rejection_reason'] ?? ''))
                : null;
        }

        $query->update($updateData);

        return response()->json([
            'message' => $studentId !== null
                ? 'All subjects ' . strtolower($validated['status']) . ' successfully'
                : 'Registration status updated',
        ]);
    }

    private function insertClassEntries(string $table, int $subjectId, array $entries): void
    {
        if (!Schema::hasTable($table)) {
            return;
        }

        foreach ($entries as $entry) {
            $row = [];

            foreach (['section_name', 'section', 'name', 'lab_name', 'tutorial_name'] as $column) {
                if (Schema::hasColumn($table, $column)) {
                    $row[$column] = $entry['name'];
                    break;
                }
            }

            if (Schema::hasColumn($table, 'subject_id')) {
                $row['subject_id'] = $subjectId;
            }

            if (Schema::hasColumn($table, 'room')) {
                $row['room'] = $entry['location'] ?? null;
            }

            if (Schema::hasColumn($table, 'location')) {
                $row['location'] = $entry['location'] ?? null;
            }

            if (Schema::hasColumn($table, 'capacity')) {
                $row['capacity'] = $entry['capacity'] ?? 0;
            }

            foreach (['day', 'time'] as $column) {
                if (!Schema::hasColumn($table, $column)) {
                    continue;
                }

                $row[$column] = $entry[$column] ?? null;
            }

            foreach (['instructor', 'instructor_name'] as $column) {
                if (Schema::hasColumn($table, $column)) {
                    $row[$column] = $entry['instructor'] ?? null;
                }
            }

            DB::table($table)->insert($row);
        }
    }

    private function replaceClassEntries(string $table, int $subjectId, array $entries): void
    {
        if (!Schema::hasTable($table) || !Schema::hasColumn($table, 'subject_id')) {
            return;
        }

        DB::table($table)->where('subject_id', $subjectId)->delete();
        $this->insertClassEntries($table, $subjectId, $entries);
    }

    private function registeredSubjectRows(
        $studentId,
        bool $includeApprovalStatus = false,
        bool $onlyUnapproved = false
    )
    {
        if (!Schema::hasTable('subject_registrations')) {
            return collect();
        }

        $query = DB::table('subject_registrations')
            ->join('subjects', 'subject_registrations.subject_id', '=', 'subjects.id')
            ->where('subject_registrations.student_id', $studentId)
            ->orderBy('subjects.code');

        if ($onlyUnapproved && Schema::hasColumn('subject_registrations', 'approval_status')) {
            $query->where(function ($statusQuery) {
                $statusQuery
                    ->whereNull('subject_registrations.approval_status')
                    ->orWhere('subject_registrations.approval_status', '!=', 'Approved');
            });
        }

        $selects = [
            'subjects.id',
            'subjects.code',
            'subjects.name',
            'subjects.credit_hour',
            'subject_registrations.id as registration_id',
        ];

        foreach (['examination', 'exam_date', 'exam_period'] as $column) {
            if (Schema::hasColumn('subjects', $column)) {
                $selects[] = "subjects.$column";
            }
        }

        $optionalColumns = ['section', 'tutorial_lab'];

        if ($includeApprovalStatus) {
            $optionalColumns[] = 'approval_status';
            $optionalColumns[] = 'rejection_reason';
        }

        foreach ($optionalColumns as $column) {
            if (Schema::hasColumn('subject_registrations', $column)) {
                $selects[] = "subject_registrations.$column";
            }
        }

        return $query->select($selects)->get()->map(function ($subject) use ($includeApprovalStatus) {
            $sections = $this->getSubjectTimetableEntries('lecture_section', $subject->id, 'L');
            $tutorials = $this->getSubjectTimetableEntries('lab_section', $subject->id, 'B');
            $legacySessions = $this->getSubjectTimetableEntries('class_sessions', $subject->id);
            $timetable = array_merge($sections, $tutorials, $legacySessions);
            $timing = $this->selectedTimetableDetails(
                $timetable,
                $subject->section ?? null,
                $subject->tutorial_lab ?? null
            );

            $row = [
                'id' => $subject->id,
                'registration_id' => $subject->registration_id,
                'code' => $subject->code,
                'name' => $subject->name,
                'credit_hour' => $subject->credit_hour,
                'examination' => $subject->examination ?? null,
                'exam_date' => $subject->exam_date ?? null,
                'exam_period' => $subject->exam_period ?? null,
                'section' => $timing['section'],
                'tutorial_lab' => $timing['tutorial_lab'],
                'time_summary' => $timing['time_summary'],
                'instructors' => $this->getSubjectInstructors($subject->id),
            ];

            if ($includeApprovalStatus) {
                $row['approval_status'] = $subject->approval_status ?? 'Pending';
                $row['rejection_reason'] = $subject->rejection_reason ?? null;
            }

            return $row;
        });
    }

    private function findRegistrationClash(
        int $studentId,
        int $subjectId,
        ?string $section,
        ?string $tutorialLab
    ): ?array {
        if (!Schema::hasTable('subject_registrations')) {
            return null;
        }

        $subject = Subject::find($subjectId);
        if (!$subject) {
            return null;
        }

        $newEntries = $this->selectedTimetableEntries(
            array_merge(
                $this->getSubjectTimetableEntries('lecture_section', $subjectId, 'L'),
                $this->getSubjectTimetableEntries('lab_section', $subjectId, 'B'),
                $this->getSubjectTimetableEntries('class_sessions', $subjectId)
            ),
            $section,
            $tutorialLab
        );

        if (empty($newEntries)) {
            return null;
        }

        $selects = [
            'subjects.id',
            'subjects.code',
            'subjects.name',
        ];

        foreach (['section', 'tutorial_lab'] as $column) {
            if (Schema::hasColumn('subject_registrations', $column)) {
                $selects[] = "subject_registrations.$column";
            }
        }

        $registeredSubjects = DB::table('subject_registrations')
            ->join('subjects', 'subject_registrations.subject_id', '=', 'subjects.id')
            ->where('subject_registrations.student_id', $studentId)
            ->where('subject_registrations.subject_id', '!=', $subjectId)
            ->select($selects)
            ->get();

        foreach ($registeredSubjects as $registeredSubject) {
            $registeredEntries = $this->selectedTimetableEntries(
                array_merge(
                    $this->getSubjectTimetableEntries('lecture_section', $registeredSubject->id, 'L'),
                    $this->getSubjectTimetableEntries('lab_section', $registeredSubject->id, 'B'),
                    $this->getSubjectTimetableEntries('class_sessions', $registeredSubject->id)
                ),
                $registeredSubject->section ?? null,
                $registeredSubject->tutorial_lab ?? null
            );

            foreach ($newEntries as $newEntry) {
                foreach ($registeredEntries as $registeredEntry) {
                    if (!$this->timetableEntriesClash($newEntry, $registeredEntry)) {
                        continue;
                    }

                    return [
                        'code' => (string) $registeredSubject->code,
                        'name' => (string) $registeredSubject->name,
                        'day' => (string) ($newEntry['day'] ?? ''),
                        'time' => (string) ($newEntry['time'] ?? ''),
                    ];
                }
            }
        }

        return null;
    }

    private function selectedTimetableEntries(array $timetable, ?string $section, ?string $tutorialLab): array
    {
        $selected = [];
        $section = (string) ($section ?? '');
        $tutorialLab = (string) ($tutorialLab ?? '');

        foreach ($timetable as $entry) {
            $mode = $entry['mode'] ?? '';
            $entrySection = (string) ($entry['section'] ?? '');

            if ($section === '' && $mode === 'L' && $entrySection !== '') {
                $section = $entrySection;
            }

            if ($tutorialLab === '' && $mode === 'B' && $entrySection !== '') {
                $tutorialLab = $entrySection;
            }

            $isSelectedLecture = $mode === 'L' && $entrySection === $section;
            $isSelectedTutorial = $mode === 'B' && $entrySection === $tutorialLab;

            if (!$isSelectedLecture && !$isSelectedTutorial) {
                continue;
            }

            $day = trim((string) ($entry['day'] ?? ''));
            $time = trim((string) ($entry['time'] ?? ''));

            if ($day === '' || $time === '') {
                continue;
            }

            $selected[] = $entry;
        }

        return $selected;
    }

    private function timetableEntriesClash(array $first, array $second): bool
    {
        if (
            $this->normalizedTimetableDay($first['day'] ?? '')
            !== $this->normalizedTimetableDay($second['day'] ?? '')
        ) {
            return false;
        }

        $firstRange = $this->timetableTimeRange($first['time'] ?? '');
        $secondRange = $this->timetableTimeRange($second['time'] ?? '');

        if ($firstRange === null || $secondRange === null) {
            return $this->normalizedTimetableTime($first['time'] ?? '')
                === $this->normalizedTimetableTime($second['time'] ?? '');
        }

        return $firstRange['start'] < $secondRange['end']
            && $secondRange['start'] < $firstRange['end'];
    }

    private function normalizedTimetableDay($day): string
    {
        return strtolower(substr(trim((string) $day), 0, 3));
    }

    private function normalizedTimetableTime($time): string
    {
        return preg_replace('/\s+/', '', strtolower(trim((string) $time)));
    }

    private function timetableTimeRange($time): ?array
    {
        $time = strtolower(trim((string) $time));
        if ($time === '') {
            return null;
        }

        $parts = preg_split('/\s*-\s*/', $time);
        if (!is_array($parts) || count($parts) !== 2) {
            return null;
        }

        $start = $this->timeToMinutes($parts[0]);
        $end = $this->timeToMinutes($parts[1]);

        if ($start === null || $end === null || $start >= $end) {
            return null;
        }

        return [
            'start' => $start,
            'end' => $end,
        ];
    }

    private function timeToMinutes(string $time): ?int
    {
        $time = trim($time);
        if (!preg_match('/^(\d{1,2}):(\d{2})\s*(am|pm)?$/', $time, $matches)) {
            return null;
        }

        $hour = (int) $matches[1];
        $minute = (int) $matches[2];
        $period = isset($matches[3]) && $matches[3] !== '' ? $matches[3] : null;

        if ($minute > 59 || $hour > 23) {
            return null;
        }

        if ($period !== null) {
            if ($hour < 1 || $hour > 12) {
                return null;
            }

            if ($period === 'am') {
                $hour = $hour === 12 ? 0 : $hour;
            } else {
                $hour = $hour === 12 ? 12 : $hour + 12;
            }
        }

        return ($hour * 60) + $minute;
    }

    private function approvalStatusSummary($registrations = null)
    {
        if (!Schema::hasColumn('subject_registrations', 'approval_status')) {
            return $registrations === null
                ? ['pending' => 0, 'approved' => 0, 'rejected' => 0]
                : 'Pending';
        }

        if ($registrations !== null) {
            $statuses = $registrations
                ->pluck('approval_status')
                ->map(fn ($status) => $status ?: 'Pending')
                ->unique()
                ->values();

            if ($statuses->count() === 1) {
                return (string) $statuses->first();
            }

            if ($statuses->contains('Pending')) {
                return 'Pending';
            }

            return 'Mixed';
        }

        $students = DB::table('subject_registrations')
            ->select('student_id', 'approval_status')
            ->get()
            ->groupBy('student_id')
            ->map(fn ($rows) => $this->approvalStatusSummary($rows));

        $pending  = $students->filter(fn($s) => $s === 'Pending')->count();
        $approved = $students->filter(fn($s) => $s === 'Approved')->count();
        $rejected = $students->filter(fn($s) => $s === 'Rejected')->count();

        return [
            'pending'  => $pending,
            'approved' => $approved,
            'rejected' => $rejected,
        ];
    }

    private function approvalStudentInfo($studentId): ?array
    {
        $student = DB::table('students')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('students.id', $studentId)
            ->select(
                'students.id as student_id',
                'users.name',
                'students.matric_no',
                'students.programme',
                'students.year'
            )
            ->first();

        if (!$student) {
            return null;
        }

        return [
            'student_id' => $student->student_id,
            'name' => $student->name,
            'matric_no' => $student->matric_no,
            'programme' => $student->programme,
            'year' => $student->year,
            'advisor' => $this->getStudentAdvisor((int) $student->student_id),
        ];
    }

    private function getStudentAdvisor(int $studentId): string
    {
        if (!Schema::hasColumn('students', 'advisor')) {
            return '-';
        }

        return (string) (DB::table('students')
            ->where('id', $studentId)
            ->value('advisor') ?? '-');
    }

    private function getSubjectInstructors(int $subjectId): array
    {
        $instructors = [];

        foreach (['lecture_section', 'lab_section'] as $table) {
            if (!Schema::hasTable($table) || !Schema::hasColumn($table, 'subject_id')) {
                continue;
            }

            $instructorColumn = null;
            foreach (['instructor', 'instructor_name'] as $column) {
                if (Schema::hasColumn($table, $column)) {
                    $instructorColumn = $column;
                    break;
                }
            }

            if (!$instructorColumn) {
                continue;
            }

            $rows = DB::table($table)
                ->where('subject_id', $subjectId)
                ->whereNotNull($instructorColumn)
                ->pluck($instructorColumn)
                ->all();

            foreach ($rows as $instructor) {
                $instructor = trim((string) $instructor);
                if ($instructor !== '' && !in_array($instructor, $instructors, true)) {
                    $instructors[] = $instructor;
                }
            }
        }

        return $instructors;
    }

    private function getSubjectTimetableEntries(string $table, int $subjectId, string $mode = ''): array
    {
        if (!Schema::hasTable($table) || !Schema::hasColumn($table, 'subject_id')) {
            return [];
        }

        if ($table === 'class_sessions') {
            return DB::table($table)
                ->where('subject_id', $subjectId)
                ->get()
                ->map(function ($row) {
                    $sessionType = strtolower((string) ($row->session_type ?? ''));
                    $mode = str_contains($sessionType, 'tutorial') || str_contains($sessionType, 'lab')
                        ? 'B'
                        : 'L';
                    $startTime = (string) ($row->start_time ?? '');
                    $endTime = (string) ($row->end_time ?? '');
                    $start = $startTime === '' ? '' : substr($startTime, 0, 5);
                    $end = $endTime === '' ? '' : substr($endTime, 0, 5);

                    return [
                        'id' => $row->id ?? null,
                        'section' => (string) ($row->section ?? ''),
                        'day' => $row->class_date ? strtoupper(date('D', strtotime($row->class_date))) : '',
                        'time' => trim($start . '-' . $end, '-'),
                        'location' => (string) ($row->venue ?? ''),
                        'mode' => $mode,
                        'capacity' => '',
                        'instructor' => '',
                    ];
                })
                ->values()
                ->all();
        }

        $value = function (object $row, array $columns): string {
            foreach ($columns as $column) {
                if (property_exists($row, $column) && $row->{$column} !== null) {
                    return (string) $row->{$column};
                }
            }

            return '';
        };

        return DB::table($table)
            ->where('subject_id', $subjectId)
            ->get()
            ->map(function ($row) use ($mode, $value, $subjectId) {
                $section = $value(
                    $row,
                    ['section_name', 'section', 'name', 'lab_name', 'tutorial_name']
                );
                $capacity = $value($row, ['capacity']);
                $usedCapacity = $this->registeredSlotCount($subjectId, $section, $mode);
                $capacityValue = is_numeric($capacity) ? (int) $capacity : null;

                return [
                    'id' => $row->id ?? null,
                    'section' => $section,
                    'day' => $value($row, ['day']),
                    'time' => $value($row, ['time']),
                    'location' => $value($row, ['room', 'location']),
                    'mode' => $mode,
                    'capacity' => $capacity,
                    'remaining_capacity' => $capacityValue === null
                        ? ''
                        : max(0, $capacityValue - $usedCapacity),
                    'instructor' => $value($row, ['instructor', 'instructor_name']),
                ];
            })
            ->values()
            ->all();
    }

    private function selectedTimetableDetails(array $timetable, ?string $section, ?string $tutorialLab): array
    {
        $matches = [];
        $section = (string) ($section ?? '');
        $tutorialLab = (string) ($tutorialLab ?? '');

        foreach ($timetable as $entry) {
            $mode = $entry['mode'] ?? '';
            $entrySection = (string) ($entry['section'] ?? '');

            if ($section === '' && $mode === 'L' && $entrySection !== '') {
                $section = $entrySection;
            }

            if ($tutorialLab === '' && $mode === 'B' && $entrySection !== '') {
                $tutorialLab = $entrySection;
            }

            $isSelectedLecture = $mode === 'L' && $entrySection === $section;
            $isSelectedTutorial = $mode === 'B' && $entrySection === $tutorialLab;

            if (!$isSelectedLecture && !$isSelectedTutorial) {
                continue;
            }

            $time = trim((string) ($entry['time'] ?? ''));
            $day = trim((string) ($entry['day'] ?? ''));
            $modeLabel = $mode === 'B' ? 'B' : 'L';

            if ($time !== '' || $day !== '') {
                $matches[] = trim($time . ' (' . $day . ') ' . $modeLabel);
            }
        }

        return [
            'section' => $section,
            'tutorial_lab' => $tutorialLab,
            'time_summary' => implode(' | ', $matches),
        ];
    }

    private function tutorialMatchesLectureSection(?string $section, ?string $tutorialLab): bool
    {
        $sectionPrefix = $this->sectionNumericPrefix($section);
        $tutorialPrefix = $this->sectionNumericPrefix($tutorialLab);

        if ($sectionPrefix === '' || $tutorialPrefix === '') {
            return true;
        }

        return $sectionPrefix === $tutorialPrefix;
    }

    private function sectionNumericPrefix(?string $value): string
    {
        $value = trim((string) ($value ?? ''));
        if (!preg_match('/^(\d+)/', $value, $matches)) {
            return '';
        }

        return str_pad((string) ((int) $matches[1]), 2, '0', STR_PAD_LEFT);
    }

    private function registeredSlotCount(int $subjectId, string $section, string $mode): int
    {
        if (
            $section === ''
            || !Schema::hasTable('subject_registrations')
            || !Schema::hasColumn('subject_registrations', 'subject_id')
        ) {
            return 0;
        }

        $column = $mode === 'B' ? 'tutorial_lab' : 'section';
        if (!Schema::hasColumn('subject_registrations', $column)) {
            return 0;
        }

        $query = DB::table('subject_registrations')
            ->where('subject_id', $subjectId)
            ->where($column, $section);

        if (Schema::hasColumn('subject_registrations', 'approval_status')) {
            $query->where(function ($statusQuery) {
                $statusQuery
                    ->whereNull('approval_status')
                    ->orWhere('approval_status', '!=', 'Rejected');
            });
        }

        return $query->count();
    }

}
