<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\AttendanceController;
use App\Http\Controllers\RegistrationController;
use App\Http\Controllers\Api\ModuleController;


//deli
Route::post('/login', [AuthController::class, 'login']);
Route::get('/subjects', [RegistrationController::class, 'index']);
Route::post('/subjects', [RegistrationController::class, 'store']);
Route::post('/subjects/register', [RegistrationController::class, 'register']);
Route::get('/subjects/{subjectId}/registered-students', [RegistrationController::class, 'registeredStudentsBySubject']);
Route::get('/students/{studentId}/registered-subjects', [RegistrationController::class, 'registeredSubjects']);
Route::delete('/students/{studentId}/registered-subjects', [RegistrationController::class, 'removeRegisteredSubject']);
Route::delete('/students/{studentId}/registered-subjects/{subjectId}', [RegistrationController::class, 'removeRegisteredSubject']);
Route::post('/students/{studentId}/notify-registrar', [RegistrationController::class, 'notifyRegistrar']);
Route::get('/subject-approvals', [RegistrationController::class, 'approvalRequests']);
Route::get('/subject-approvals/{studentId}/subjects', [RegistrationController::class, 'studentApprovalSubjects']);
Route::post('/subject-approvals/registrations/{registrationId}/status', [RegistrationController::class, 'updateRegistrationStatus']);
Route::post('/subject-approvals/student/{studentId}/status', [RegistrationController::class, 'updateRegistrationStatus']); // ✅ NEW
Route::get('/subjects/{id}', [RegistrationController::class, 'show']);
Route::put('/subjects/{id}', [RegistrationController::class, 'update']);
Route::delete('/subjects/{id}', [RegistrationController::class, 'destroy']);

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
Route::get('/lecturers', [ModuleController::class, 'lecturers']);
Route::get('/modules/{id}/schedules', [ModuleController::class, 'schedules']);
Route::post('/modules/book', [ModuleController::class, 'book']);
Route::post('/pusat-adab/modules', [ModuleController::class, 'pusatAdabStoreModule']);
Route::put('/pusat-adab/modules/{moduleId}', [ModuleController::class, 'pusatAdabUpdateModule']);
Route::delete('/pusat-adab/modules/{moduleId}', [ModuleController::class, 'pusatAdabDeleteModule']);
Route::post('/pusat-adab/modules/{moduleId}/schedules', [ModuleController::class, 'pusatAdabStoreSchedule']);
Route::put('/pusat-adab/schedules/{scheduleId}', [ModuleController::class, 'pusatAdabUpdateSchedule']);
Route::delete('/pusat-adab/schedules/{scheduleId}', [ModuleController::class, 'pusatAdabDeleteSchedule']);

Route::get('/modules/my-bookings', [ModuleController::class, 'myBookings']);
Route::get('/modules/activities', [ModuleController::class, 'joinedActivities']);
Route::delete('/modules/bookings/{registrationId}/cancel', [ModuleController::class, 'cancelBooking']);
Route::get('/modules/credit-claims', [ModuleController::class, 'creditClaims']);
Route::post('/modules/credit-claims/apply', [ModuleController::class, 'applyCreditClaim']);
Route::get('/pusat-adab/module-registrations', [ModuleController::class, 'pusatAdabModuleRegistrations']);
Route::delete('/pusat-adab/module-registrations/{registrationId}', [ModuleController::class, 'pusatAdabRemoveModuleRegistration']);
Route::get('/pusat-adab/credit-claims', [ModuleController::class, 'pusatAdabCreditClaims']);
Route::post('/pusat-adab/credit-claims/{claimId}/status', [ModuleController::class, 'updateCreditClaimStatus']);


//izzah
use App\Http\Controllers\FeeController;

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
