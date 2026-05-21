<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\AttendanceController;
use App\Http\Controllers\SubjectController;
use App\Http\Controllers\Api\ModuleController;
use App\Http\Controllers\FeeController;


//deli
Route::post('/login', [AuthController::class, 'login']);
Route::get('/subjects', [SubjectController::class, 'index']);
Route::post('/subjects', [SubjectController::class, 'store']);
Route::post('/subjects/register', [SubjectController::class, 'register']);
Route::get('/students/{studentId}/registered-subjects', [SubjectController::class, 'registeredSubjects']);
Route::delete('/students/{studentId}/registered-subjects', [SubjectController::class, 'clearRegisteredSubjects']);
Route::delete('/students/{studentId}/registered-subjects/{subjectId}', [SubjectController::class, 'removeRegisteredSubject']);
Route::post('/students/{studentId}/notify-registrar', [SubjectController::class, 'notifyRegistrar']);
Route::get('/subject-approvals', [SubjectController::class, 'approvalRequests']);
Route::get('/subject-approvals/{studentId}/subjects', [SubjectController::class, 'studentApprovalSubjects']);
Route::post('/subject-approvals/registrations/{registrationId}/status', [SubjectController::class, 'updateRegistrationStatus']);
Route::post('/subject-approvals/student/{studentId}/status', [SubjectController::class, 'updateStudentAllSubjectsStatus']); // ✅ NEW
Route::get('/subjects/{id}', [SubjectController::class, 'show']);
Route::delete('/subjects/{id}', [SubjectController::class, 'destroy']);

//nana
Route::get('/lecturer/{id}/classes', [AttendanceController::class, 'getLecturerClasses']);
Route::post('/attendance/generate', [AttendanceController::class, 'generateCode']);
Route::get('/attendance/{classSessionId}/submissions', [AttendanceController::class, 'getSubmissions']);
Route::get('/student/{id}/subjects', [AttendanceController::class, 'getRegisteredSubjects']);
Route::get('/student/{id}/modules', [AttendanceController::class, 'getRegisteredModules']);
Route::get('/student/{id}/info', [AttendanceController::class, 'getStudentInfo']);
Route::get('/student/{studentId}/attendance/{subjectId}', [AttendanceController::class, 'getStudentAttendance']);
Route::post('/attendance/{attendanceId}/status', [AttendanceController::class, 'updateAttendanceStatus']);
Route::post(
    '/attendance/submit',
    [AttendanceController::class, 'submitAttendance']
);
Route::put('/attendance/records/{attendanceId}', [AttendanceController::class, 'updateAttendanceRecord']);
Route::delete('/attendance/records/{attendanceId}', [AttendanceController::class, 'deleteAttendanceRecord']);

//meor
Route::get('/modules', [ModuleController::class, 'index']);
Route::get('/modules/{id}/schedules', [ModuleController::class, 'schedules']);
Route::post('/modules/book', [ModuleController::class, 'book']);
Route::get('/modules/my-bookings', [ModuleController::class, 'myBookings']);
Route::delete('/modules/bookings/{registrationId}/cancel', [ModuleController::class, 'cancelBooking']);
Route::get('/modules/credit-claims', [ModuleController::class, 'creditClaims']);
Route::post('/modules/credit-claims/apply', [ModuleController::class, 'applyCreditClaim']);

//izzah
Route::prefix('tuition')->group(function () {
    // Student
    Route::get('/student/{studentId}/status', [FeeController::class, 'getStudentFeeStatus']);
    Route::get('/student/{studentId}/details', [FeeController::class, 'getFeeDetails']);
    Route::post('/student/submit-payment', [FeeController::class, 'submitPayment']);
    Route::get('/student/{studentId}/history', [FeeController::class, 'getPaymentHistory']);

    // Treasurer
    Route::get('/treasurer/pending', [FeeController::class, 'getPendingPayments']);
    Route::get('/treasurer/payment/{paymentId}', [FeeController::class, 'viewPayment']);
    Route::post('/treasurer/payment/{paymentId}/approve', [FeeController::class, 'approvePayment']);
    Route::post('/treasurer/payment/{paymentId}/reject', [FeeController::class, 'rejectPayment']);
    Route::get('/treasurer/records', [FeeController::class, 'getPaymentRecords']);
});
