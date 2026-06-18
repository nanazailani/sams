<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class FeeController extends Controller
{
    // Resolve student ID — boleh pass students.id atau users.id, dua-dua handle
    private function resolveStudentId($incomingStudentId): ?int
    {
        if (!$incomingStudentId) {
            return null;
        }

        $incomingStudentId = (int) $incomingStudentId;

        // cuba cari guna students.id dulu
        $directStudentId = DB::table('students')
            ->where('id', $incomingStudentId)
            ->value('id');

        if ($directStudentId) {
            return (int) $directStudentId;
        }

        // tak jumpa — cuba try guna users.id pula
        $studentByUserId = DB::table('students')
            ->where('user_id', $incomingStudentId)
            ->value('id');

        if ($studentByUserId) {
            return (int) $studentByUserId;
        }

        return null; // langsung tak jumpa
    }

    // Ambil info student + nama sekali — nama ada kat users table, kena join
    private function getStudentRecord(int $studentId)
    {
        return DB::table('students')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->where('students.id', $studentId)
            ->select(
                'students.id',
                'students.user_id',
                'students.matric_no',
                'students.programme',
                'students.year',
                'students.hostel',
                'users.name'
            )
            ->first();
    }

    // Cari fee config ikut programme — kalau ada lebih satu, ambil yang latest
    private function getFeeConfigForStudent($student)
    {
        if (!$student || empty($student->programme)) {
            return null;
        }

        return DB::table('tuition_fees')
            ->where('programme', $student->programme)
            ->orderByDesc('id')
            ->first();
    }

    // Kira total yuran — kalau student duduk hostel, kena tambah hostel fee sekali
    private function calculateTotalAmount($student, $fee): float
    {
        $tuitionFee = (float) ($fee->tuition_fee ?? 0);
        $hostelFee = (float) ($fee->hostel_fee ?? 0);

        $isHostel = (int) ($student->hostel ?? 0) === 1;

        return $isHostel ? ($tuitionFee + $hostelFee) : $tuitionFee;
    }

    // Dashboard student — tunjuk berapa dah bayar, outstanding, percentage
    public function getStudentFeeStatus($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $student = $this->getStudentRecord($studentId);

        if (!$student) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $fee = $this->getFeeConfigForStudent($student);

        if (!$fee) {
            return response()->json([
                'message' => 'No tuition fee configuration found for this programme'
            ], 404);
        }

        $totalAmount = $this->calculateTotalAmount($student, $fee);

        // approved je dikira bayar — pending tak kira lagi
        $approvedPaid = DB::table('payments')
            ->where('student_id', $studentId)
            ->where('tuition_fee_id', $fee->id)
            ->where('status', 'Approved')
            ->sum('amount');

        // pending — dah submit tapi belum disahkan treasurer
        $pendingPaid = DB::table('payments')
            ->where('student_id', $studentId)
            ->where('tuition_fee_id', $fee->id)
            ->where('status', 'Pending')
            ->sum('amount');

        $remaining = max($totalAmount - $approvedPaid, 0);
        $completion = $totalAmount > 0
            ? round(($approvedPaid / $totalAmount) * 100)
            : 0;

        // status overall — Paid kalau dah settle, Partial kalau ada sikit, Unpaid kalau belum langsung
        $overallStatus = $remaining <= 0
            ? 'Paid'
            : ($approvedPaid > 0 ? 'Partial' : 'Unpaid');

        return response()->json([
            'student_name'          => $student->name ?? '-',
            'matric_no'             => $student->matric_no ?? '-',
            'programme'             => $student->programme ?? '-',
            'semester'              => ($fee->semester ?? '-') . ', ' . ($fee->session ?? '-'),
            'total_fee'             => (float) $totalAmount,
            'amount_paid'           => (float) $approvedPaid,
            'pending_amount'        => (float) $pendingPaid,
            'remaining_balance'     => (float) $remaining,
            'deadline'              => !empty($fee->deadline)
                                        ? Carbon::parse($fee->deadline)->format('j M Y')
                                        : '-',
            'completion_percentage' => $completion,
            'status'                => $overallStatus,
            'hostel'                => (int) ($student->hostel ?? 0),
        ]);
    }

    // Detail yuran — lebih terperinci, ada breakdown tuition vs hostel fee
    public function getFeeDetails($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $student = $this->getStudentRecord($studentId);

        if (!$student) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $fee = $this->getFeeConfigForStudent($student);

        if (!$fee) {
            return response()->json([
                'message' => 'No tuition fee configuration found for this programme'
            ], 404);
        }

        $totalAmount = $this->calculateTotalAmount($student, $fee);

        $approvedPaid = DB::table('payments')
            ->where('student_id', $studentId)
            ->where('tuition_fee_id', $fee->id)
            ->where('status', 'Approved')
            ->sum('amount');

        $remaining = max($totalAmount - $approvedPaid, 0);
        $completion = $totalAmount > 0
            ? round(($approvedPaid / $totalAmount) * 100)
            : 0;

        $status = $remaining <= 0
            ? 'Paid'
            : ($approvedPaid > 0 ? 'Partial' : 'Unpaid');

        // kalau tak duduk hostel, hostel fee = 0
        $hostelFeeApplied = ((int) ($student->hostel ?? 0) === 1)
            ? (float) ($fee->hostel_fee ?? 0)
            : 0.0;

        return response()->json([
            'student_name'          => $student->name ?? '-',
            'matric_no'             => $student->matric_no ?? '-',
            'programme'             => $student->programme ?? '-',
            'semester'              => $fee->semester ?? '-',
            'session'               => $fee->session ?? '-',
            'tuition_fee'           => (float) ($fee->tuition_fee ?? 0),
            'hostel_fee'            => $hostelFeeApplied,
            'total_fee'             => (float) $totalAmount,
            'paid'                  => (float) $approvedPaid,
            'outstanding'           => (float) $remaining,
            'completion_percentage' => $completion,
            'status'                => $status,
            'deadline'              => !empty($fee->deadline)
                                        ? Carbon::parse($fee->deadline)->format('j F Y')
                                        : '-',
            'hostel'                => (int) ($student->hostel ?? 0),
        ]);
    }

    // Student submit payment — upload resit, validate, then save dengan status Pending
    public function submitPayment(Request $request)
    {
        $request->validate([
            'student_id'     => 'required|integer',
            'amount'         => 'required|numeric|min:1',
            'payment_method' => 'required|in:Online Banking,Credit/Debit Card,Other',
            'receipt'        => 'required|file|mimes:jpg,jpeg,png,pdf|max:4096',
        ]);

        $studentId = $this->resolveStudentId($request->student_id);

        if (!$studentId) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $student = $this->getStudentRecord($studentId);

        if (!$student) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $fee = $this->getFeeConfigForStudent($student);

        if (!$fee) {
            return response()->json([
                'message' => 'No tuition fee configuration found for this programme'
            ], 404);
        }

        $totalAmount = $this->calculateTotalAmount($student, $fee);

        // kira outstanding — approved je, pending tak masuk kira
        $approvedPaid = DB::table('payments')
            ->where('student_id', $studentId)
            ->where('tuition_fee_id', $fee->id)
            ->where('status', 'Approved')
            ->sum('amount');

        $remaining = max($totalAmount - $approvedPaid, 0);

        // tak boleh bayar lebih dari yang outstanding
        if ($request->amount > $remaining) {
            return response()->json([
                'message'           => 'Payment amount exceeds outstanding balance',
                'remaining_balance' => $remaining,
            ], 422);
        }

        // store resit ke public/storage — guna public_direct disk supaya accessible via URL
        $receiptPath = $request->file('receipt')->storeAs(
            'payment_receipts',
            uniqid() . '_' . time() . '.' . $request->file('receipt')->getClientOriginalExtension(),
            ['disk' => 'public_direct']
        );

        $insertData = [
            'student_id'     => $studentId,
            'tuition_fee_id' => $fee->id,
            'amount'         => $request->amount,
            'payment_method' => $request->payment_method,
            'status'         => 'Pending', // default pending — kena tunggu treasurer approve
            'created_at'     => now(),
            'updated_at'     => now(),
        ];

        // check column wujud dulu sebelum insert — elak error kalau migration lain
        if (Schema::hasColumn('payments', 'receipt_path')) {
            $insertData['receipt_path'] = $receiptPath;
        }

        if (Schema::hasColumn('payments', 'submitted_at')) {
            $insertData['submitted_at'] = now();
        }

        if (Schema::hasColumn('payments', 'remarks') && $request->filled('remarks')) {
            $insertData['remarks'] = $request->remarks;
        }

        DB::table('payments')->insert($insertData);

        return response()->json([
            'message'      => 'Payment submitted successfully',
            'amount'       => (float) $request->amount,
            'status'       => 'Pending',
            'receipt_path' => $receiptPath,
        ]);
    }

    // History payment student — return summary dan senarai semua transaksi
    public function getPaymentHistory($studentId)
    {
        $studentId = $this->resolveStudentId($studentId);

        if (!$studentId) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $student = $this->getStudentRecord($studentId);

        if (!$student) {
            return response()->json(['message' => 'Student not found'], 404);
        }

        $fee = $this->getFeeConfigForStudent($student);

        if (!$fee) {
            return response()->json([
                'message' => 'No tuition fee configuration found for this programme'
            ], 404);
        }

        $totalAmount = $this->calculateTotalAmount($student, $fee);

        $summary = [
            'total_paid' => DB::table('payments')
                ->where('student_id', $studentId)
                ->where('tuition_fee_id', $fee->id)
                ->where('status', 'Approved')
                ->sum('amount'),
            'outstanding'    => 0, // kira lepas dapat total_paid
            'approved_count' => DB::table('payments')
                ->where('student_id', $studentId)
                ->where('tuition_fee_id', $fee->id)
                ->where('status', 'Approved')
                ->count(),
            'pending_count'  => DB::table('payments')
                ->where('student_id', $studentId)
                ->where('tuition_fee_id', $fee->id)
                ->where('status', 'Pending')
                ->count(),
            'all_count'      => DB::table('payments')
                ->where('student_id', $studentId)
                ->where('tuition_fee_id', $fee->id)
                ->count(),
        ];

        $summary['outstanding'] = max($totalAmount - $summary['total_paid'], 0);

        // format tarikh dan ambil fields yang perlu je untuk display kat Flutter
        $payments = DB::table('payments')
            ->where('student_id', $studentId)
            ->where('tuition_fee_id', $fee->id)
            ->orderByDesc('submitted_at')
            ->orderByDesc('id')
            ->get()
            ->map(function ($payment) {
                return [
                    'id'           => $payment->id,
                    'date'         => !empty($payment->submitted_at)
                        ? Carbon::parse($payment->submitted_at)->format('j M Y')
                        : (!empty($payment->created_at)
                            ? Carbon::parse($payment->created_at)->format('j M Y')
                            : '-'),
                    'amount'       => (float) ($payment->amount ?? 0),
                    'method'       => $payment->payment_method ?? '-',
                    'status'       => $payment->status ?? 'Pending',
                    'receipt_path' => $payment->receipt_path ?? null,
                ];
            });

        return response()->json([
            'semester' => ($fee->semester ?? '-') . ', ' . ($fee->session ?? '-'),
            'summary'  => $summary,
            'payments' => $payments,
        ]);
    }

    // Base query untuk treasurer — join semua table yang perlu sekali gus
    private function treasurerBaseQuery()
    {
        return DB::table('payments')
            ->join('students', 'payments.student_id', '=', 'students.id')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->leftJoin('tuition_fees', 'payments.tuition_fee_id', '=', 'tuition_fees.id');
    }

    // Apply filter search dan kursus — reuse untuk summary dan records
    private function applyTreasurerFilters($query, Request $request)
    {
        if ($request->filled('search')) {
            $search = trim($request->search);

            // boleh search by matric, nama, atau tarikh submitted
            $query->where(function ($q) use ($search) {
                $q->where('students.matric_no', 'like', '%' . $search . '%')
                    ->orWhere('users.name', 'like', '%' . $search . '%')
                    ->orWhereDate('payments.submitted_at', $search);
            });
        }

        if ($request->filled('course') && strtolower($request->course) !== 'all') {
            $query->where('students.programme', $request->course);
        }

        return $query;
    }

    // Generate URL resit yang boleh akses terus via browser
    private function buildReceiptUrl(?string $receiptPath): ?string
    {
        if (!$receiptPath) {
            return null;
        }

        return url('storage/' . $receiptPath);
    }

    // Dashboard treasurer — senarai payment pending + summary count by status
    public function getPendingPayments(Request $request)
    {
        $status = $request->get('status', 'Pending');

        $summaryBase = $this->applyTreasurerFilters(
            $this->treasurerBaseQuery(),
            $request
        );

        // count untuk semua status — display kat tab atas
        $summary = [
            'pending_count'  => (clone $summaryBase)->where('payments.status', 'Pending')->count(),
            'approved_count' => (clone $summaryBase)->where('payments.status', 'Approved')->count(),
            'rejected_count' => (clone $summaryBase)->where('payments.status', 'Rejected')->count(),
        ];

        $recordsBase = $this->applyTreasurerFilters(
            $this->treasurerBaseQuery(),
            $request
        );

        // kalau 'all' — tunjuk semua, kalau ada status specific — filter
        if (!empty($status) && strtolower($status) !== 'all') {
            $recordsBase->where('payments.status', $status);
        }

        $records = $recordsBase
            ->select(
                'payments.id',
                'payments.amount',
                'payments.status',
                'payments.payment_method',
                'payments.submitted_at',
                'students.matric_no',
                'users.name',
                'students.programme',
                'tuition_fees.semester',
                'tuition_fees.session'
            )
            ->orderByDesc('payments.submitted_at')
            ->orderByDesc('payments.id')
            ->paginate(5);

        return response()->json([
            'summary' => $summary,
            'records' => $records,
        ]);
    }

    // Treasurer tengok detail satu payment — semua info student + resit ada kat sini
    public function viewPayment($paymentId)
    {
        $payment = DB::table('payments')
            ->join('students', 'payments.student_id', '=', 'students.id')
            ->join('users', 'students.user_id', '=', 'users.id')
            ->leftJoin('tuition_fees', 'payments.tuition_fee_id', '=', 'tuition_fees.id')
            ->where('payments.id', $paymentId)
            ->select(
                'payments.id',
                'payments.amount',
                'payments.payment_method',
                'payments.status',
                'payments.receipt_path',
                'payments.submitted_at',
                'payments.created_at',
                'payments.remarks',
                'students.id as student_id',
                'students.matric_no',
                'students.programme',
                'users.name',
                'tuition_fees.semester',
                'tuition_fees.session'
            )
            ->first();

        if (!$payment) {
            return response()->json(['message' => 'Payment not found'], 404);
        }

        return response()->json([
            'payment_id'     => $payment->id,
            'student_id'     => $payment->student_id,
            'matric_no'      => $payment->matric_no,
            'full_name'      => $payment->name,
            'programme'      => $payment->programme,
            'semester'       => ($payment->semester ?? '-') . ', ' . ($payment->session ?? '-'),
            'amount'         => (float) ($payment->amount ?? 0),
            'payment_method' => $payment->payment_method ?? '-',
            'status'         => $payment->status ?? '-',
            'date_submitted' => !empty($payment->submitted_at)
                ? Carbon::parse($payment->submitted_at)->format('j M Y')
                : (!empty($payment->created_at)
                    ? Carbon::parse($payment->created_at)->format('j M Y')
                    : '-'),
            'receipt_path'   => $payment->receipt_path ?? null,
            'receipt_url'    => $this->buildReceiptUrl($payment->receipt_path ?? null), // full URL untuk treasurer tengok resit
            'remarks'        => $payment->remarks ?? null,
        ]);
    }

    // Treasurer approve payment — hanya boleh kalau masih Pending
    public function approvePayment(Request $request, $paymentId)
    {
        $payment = DB::table('payments')->where('id', $paymentId)->first();

        if (!$payment) {
            return response()->json(['message' => 'Payment not found'], 404);
        }

        // double check — kalau dah approved/rejected, tak boleh buat lagi
        if (($payment->status ?? null) !== 'Pending') {
            return response()->json([
                'message' => 'Only pending payments can be approved'
            ], 422);
        }

        $updateData = [
            'status'     => 'Approved',
            'updated_at' => now(),
        ];

        // save masa dan siapa yang verify — column ni optional, check dulu
        if (Schema::hasColumn('payments', 'verified_at')) {
            $updateData['verified_at'] = now();
        }

        if (Schema::hasColumn('payments', 'verified_by')) {
            $updateData['verified_by'] = optional($request->user())->id;
        }

        DB::table('payments')->where('id', $paymentId)->update($updateData);

        return response()->json([
            'message'    => 'Payment approved successfully',
            'payment_id' => $paymentId,
            'status'     => 'Approved',
        ]);
    }

    // Treasurer reject payment — kena ada remarks, tapi optional (student nak tau kenapa ditolak)
    public function rejectPayment(Request $request, $paymentId)
    {
        $request->validate([
            'remarks' => 'nullable|string|max:255'
        ]);

        $payment = DB::table('payments')->where('id', $paymentId)->first();

        if (!$payment) {
            return response()->json(['message' => 'Payment not found'], 404);
        }

        // sama macam approve — status kena Pending dulu
        if (($payment->status ?? null) !== 'Pending') {
            return response()->json([
                'message' => 'Only pending payments can be rejected'
            ], 422);
        }

        $updateData = [
            'status'     => 'Rejected',
            'remarks'    => $request->remarks, // sebab ditolak — student boleh tengok kat history
            'updated_at' => now(),
        ];

        if (Schema::hasColumn('payments', 'verified_at')) {
            $updateData['verified_at'] = now();
        }

        if (Schema::hasColumn('payments', 'verified_by')) {
            $updateData['verified_by'] = optional($request->user())->id;
        }

        DB::table('payments')->where('id', $paymentId)->update($updateData);

        return response()->json([
            'message'    => 'Payment rejected successfully',
            'payment_id' => $paymentId,
            'status'     => 'Rejected',
        ]);
    }

    // Semua rekod payment — untuk treasurer tengok history lengkap dengan summary stats
    public function getPaymentRecords(Request $request)
    {
        $status = $request->get('status', 'All');

        $summaryBase = $this->applyTreasurerFilters(
            $this->treasurerBaseQuery(),
            $request
        );

        // stats untuk display kat header page
        $summary = [
            'total_records'   => (clone $summaryBase)->count(),
            'total_collected' => (clone $summaryBase)->where('payments.status', 'Approved')->sum('payments.amount'),
            'approved_count'  => (clone $summaryBase)->where('payments.status', 'Approved')->count(),
            'rejected_count'  => (clone $summaryBase)->where('payments.status', 'Rejected')->count(),
            'pending_count'   => (clone $summaryBase)->where('payments.status', 'Pending')->count(),
        ];

        $recordsBase = $this->applyTreasurerFilters(
            $this->treasurerBaseQuery(),
            $request
        );

        if (!empty($status) && strtolower($status) !== 'all') {
            $recordsBase->where('payments.status', $status);
        }

        $records = $recordsBase
            ->select(
                'payments.id',
                'payments.amount',
                'payments.status',
                'payments.payment_method',
                'payments.submitted_at',
                'students.matric_no',
                'users.name'
            )
            ->orderByDesc('payments.submitted_at')
            ->orderByDesc('payments.id')
            ->paginate(5);

        return response()->json([
            'summary' => $summary,
            'records' => $records,
        ]);
    }
}
