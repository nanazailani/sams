-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3307
-- Generation Time: Mar 30, 2026 at 04:06 PM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.2.4

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `sams2`
--

-- --------------------------------------------------------

--
-- Table structure for table `activity_participations`
--

CREATE TABLE `activity_participations` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendances`
--

CREATE TABLE `attendances` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `student_id` bigint(20) UNSIGNED NOT NULL,
  `class_session_id` bigint(20) UNSIGNED NOT NULL,
  `attendance_code_id` bigint(20) UNSIGNED DEFAULT NULL,
  `status` enum('Present','Late','Absent') NOT NULL DEFAULT 'Present',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `location_name` varchar(255) DEFAULT NULL,
  `verification_status` varchar(255) NOT NULL DEFAULT 'Pending',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_codes`
--

CREATE TABLE `attendance_codes` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `class_session_id` bigint(20) UNSIGNED NOT NULL,
  `code` varchar(255) NOT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cache`
--

CREATE TABLE `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cache_locks`
--

CREATE TABLE `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `class_sessions`
--

CREATE TABLE `class_sessions` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `subject_id` bigint(20) UNSIGNED NOT NULL,
  `lecturer_id` bigint(20) UNSIGNED NOT NULL,
  `section` varchar(255) NOT NULL,
  `class_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `venue` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `session_type` varchar(50) DEFAULT 'Lecture',
  `week_number` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `class_sessions`
--

INSERT INTO `class_sessions` (`id`, `subject_id`, `lecturer_id`, `section`, `class_date`, `start_time`, `end_time`, `venue`, `created_at`, `updated_at`, `session_type`, `week_number`) VALUES
(1, 1, 1, 'A', '2026-03-18', '08:00:00', '10:00:00', 'DK1', '2026-03-28 09:56:29', '2026-03-28 09:56:29', 'Lecture', 1),
(2, 2, 1, 'A', '2026-03-20', '10:00:00', '12:00:00', 'DK1', '2026-03-28 09:56:29', '2026-03-28 09:56:29', 'Lab', 1);

-- --------------------------------------------------------

--
-- Table structure for table `curriculum_activities`
--

CREATE TABLE `curriculum_activities` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `lecturers`
--

CREATE TABLE `lecturers` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `staff_id` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `lecturers`
--

INSERT INTO `lecturers` (`id`, `user_id`, `staff_id`, `created_at`, `updated_at`) VALUES
(1, 1, '24680', '2026-03-28 09:56:28', '2026-03-28 09:56:28');

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '0001_01_01_000001_create_cache_table', 1),
(2, '2026_03_13_075847_create_users_table', 1),
(3, '2026_03_13_075848_create_subjects_table', 1),
(4, '2026_03_13_075849_create_attendances_table', 1),
(5, '2026_03_13_075849_create_class_sessions_table', 1),
(6, '2026_03_13_075849_create_students_table', 1),
(7, '2026_03_13_075850_create_lecturers_table', 1),
(8, '2026_03_13_075852_create_attendance_codes_table', 1),
(9, '2026_03_13_081232_create_subject_registrations_table', 1),
(10, '2026_03_13_081236_create_activity_participations_table', 1),
(11, '2026_03_13_081236_create_curriculum_activities_table', 1),
(12, '2026_03_13_081237_create_payments_table', 1),
(13, '2026_03_13_081237_create_tuition_fees_table', 1),
(14, '2026_03_13_124927_add_matric_number_to_users_table', 1),
(15, '2026_03_14_205802_create_modules_table', 1),
(16, '2026_03_14_205828_create_module_registrations_table', 1),
(17, '2026_03_15_164059_add_staff_id_to_subject_registrations_table', 1),
(18, '2026_03_15_233207_add_location_fields_to_attendances_table', 1);

-- --------------------------------------------------------

--
-- Table structure for table `modules`
--

CREATE TABLE `modules` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `code` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `lecturer_id` bigint(20) UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `modules`
--

INSERT INTO `modules` (`id`, `code`, `name`, `created_at`, `updated_at`, `location`, `category`, `lecturer_id`) VALUES
(1, 'HQD3062', 'Edit Like A Pro With Canva', '2026-03-28 09:56:29', '2026-03-28 09:56:29', 'Bil Kuliah 8 FKM', 'Entrepreneurial Drive and Innovation', 1),
(2, 'HQS3022', 'Kayak', '2026-03-28 09:56:29', '2026-03-28 09:56:29', 'Pusat Rekreasi Air', 'Sport', 1);

-- --------------------------------------------------------

--
-- Table structure for table `module_attendances`
--

CREATE TABLE `module_attendances` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `student_id` bigint(20) UNSIGNED NOT NULL,
  `module_session_id` bigint(20) UNSIGNED NOT NULL,
  `status` varchar(50) DEFAULT 'Present',
  `verification_status` varchar(50) DEFAULT 'Pending',
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `location_name` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `module_attendance_codes`
--

CREATE TABLE `module_attendance_codes` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `module_session_id` bigint(20) UNSIGNED NOT NULL,
  `code` varchar(255) NOT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `module_registrations`
--

CREATE TABLE `module_registrations` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `student_id` bigint(20) UNSIGNED NOT NULL,
  `module_id` bigint(20) UNSIGNED NOT NULL,
  `module_schedule_id` bigint(20) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `module_registrations`
--

INSERT INTO `module_registrations` (`id`, `student_id`, `module_id`, `module_schedule_id`, `created_at`, `updated_at`) VALUES
(4, 2, 1, 1, '2026-03-30 11:15:24', '2026-03-30 11:15:24'),
(5, 2, 2, 5, '2026-03-30 11:15:40', '2026-03-30 11:15:40'),
(6, 2, 1, 3, '2026-03-30 12:12:16', '2026-03-30 12:12:16'),
(7, 1, 1, 1, '2026-03-30 13:12:35', '2026-03-30 13:12:35');

-- --------------------------------------------------------

--
-- Table structure for table `module_schedules`
--

CREATE TABLE `module_schedules` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `module_id` bigint(20) UNSIGNED NOT NULL,
  `class_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `venue` varchar(255) NOT NULL,
  `capacity` int(11) NOT NULL DEFAULT 30,
  `booked_count` int(11) NOT NULL DEFAULT 0,
  `status` enum('available','full','closed') NOT NULL DEFAULT 'available',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `session_type` varchar(50) DEFAULT 'Lecture',
  `week_number` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `module_schedules`
--

INSERT INTO `module_schedules` (`id`, `module_id`, `class_date`, `start_time`, `end_time`, `venue`, `capacity`, `booked_count`, `status`, `created_at`, `updated_at`, `session_type`, `week_number`) VALUES
(1, 1, '2026-04-04', '08:00:00', '17:00:00', 'Bil Kuliah 8 FKM', 30, 13, 'available', '2026-03-29 16:30:04', '2026-03-30 13:12:35', 'Module', 1),
(2, 1, '2026-04-11', '08:00:00', '17:00:00', 'Bil Kuliah 8 FKM', 30, 30, 'full', '2026-03-29 16:30:04', '2026-03-29 16:30:04', 'Module', 2),
(3, 1, '2026-04-12', '08:00:00', '17:00:00', 'Bil Kuliah 8 FKM', 30, 20, 'available', '2026-03-29 16:30:04', '2026-03-30 12:12:16', 'Module', 3),
(4, 1, '2026-04-18', '08:00:00', '17:00:00', 'Bil Kuliah 8 FKM', 30, 12, 'available', '2026-03-29 16:30:04', '2026-03-29 16:30:04', 'Module', 4),
(5, 2, '2026-04-06', '08:00:00', '17:00:00', 'Pusat Rekreasi Air', 25, 9, 'available', '2026-03-29 16:30:04', '2026-03-30 11:15:40', 'Module', 5),
(6, 2, '2026-04-13', '08:00:00', '17:00:00', 'Pusat Rekreasi Air', 25, 25, 'full', '2026-03-29 16:30:04', '2026-03-29 16:30:04', 'Module', 6);

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `students`
--

CREATE TABLE `students` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `matric_no` varchar(255) NOT NULL,
  `programme` varchar(255) NOT NULL,
  `year` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `students`
--

INSERT INTO `students` (`id`, `user_id`, `matric_no`, `programme`, `year`, `created_at`, `updated_at`) VALUES
(1, 2, 'CB23017', 'Software Engineering', 2, '2026-03-28 09:56:28', '2026-03-28 09:56:28'),
(2, 3, 'CB23067', 'Software Engineering', 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(3, 4, 'CB23052', 'Software Engineering', 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(4, 5, 'CB23093', 'Software Engineering', 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29');

-- --------------------------------------------------------

--
-- Table structure for table `subjects`
--

CREATE TABLE `subjects` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `code` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `credit_hour` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `subjects`
--

INSERT INTO `subjects` (`id`, `code`, `name`, `credit_hour`, `created_at`, `updated_at`) VALUES
(1, 'BCS3143', 'Software Project Management', 3, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(2, 'BCS3133', 'Software Engineering Practices', 3, '2026-03-28 09:56:29', '2026-03-28 09:56:29');

-- --------------------------------------------------------

--
-- Table structure for table `subject_registrations`
--

CREATE TABLE `subject_registrations` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `student_id` bigint(20) UNSIGNED NOT NULL,
  `staff_id` bigint(20) UNSIGNED DEFAULT NULL,
  `subject_id` bigint(20) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `subject_registrations`
--

INSERT INTO `subject_registrations` (`id`, `student_id`, `staff_id`, `subject_id`, `created_at`, `updated_at`) VALUES
(1, 1, NULL, 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(2, 2, NULL, 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(3, 3, NULL, 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(4, 4, NULL, 2, '2026-03-28 09:56:29', '2026-03-28 09:56:29');

-- --------------------------------------------------------

--
-- Table structure for table `tuition_fees`
--

CREATE TABLE `tuition_fees` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `matric_number` varchar(255) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `matric_number`, `password`, `role`, `created_at`, `updated_at`) VALUES
(1, 'Dr Ahmad', 'ahmad@lecturer.com', NULL, '$2y$12$2pKiDA/vpCb5BC3Ubc2yD.mHvh8czlOwLMfTgEIjEvxQ4HbLHMj6G', 'lecturer', '2026-03-28 09:56:28', '2026-03-28 09:56:28'),
(2, 'Ahmad Zikri bin Roslan', 'ahmad@student.com', 'CB23017', '$2y$12$5IpILs/l0rY9jsqjlzwfdOwC25v9ij0J8eV3V7pwGSgd46LuPusIy', 'student', '2026-03-28 09:56:28', '2026-03-28 09:56:28'),
(3, 'Nurul Ain binti Kamal', 'nurul@student.com', 'CB23067', '$2y$12$vuu83p0NyXebO9pFGXCdIOD3RkWPH44wlE3wdynI.SJmnrFOUtJXu', 'student', '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(4, 'Lee Xin Wei', 'lee@student.com', 'CB23052', '$2y$12$zTCalpiKJ4gEkp/eXMFO8uZQvaWy3DWKh5WpWFV9bCvGDd0aC30J.', 'student', '2026-03-28 09:56:29', '2026-03-28 09:56:29'),
(5, 'Priya d/o Ramasamy', 'priya@student.com', 'CB23093', '$2y$12$glS..Yc7BTUO2q17dcGa6ewFif8ThghaarSMPJzH6NM47gi8orQKO', 'student', '2026-03-28 09:56:29', '2026-03-28 09:56:29');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activity_participations`
--
ALTER TABLE `activity_participations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `attendances`
--
ALTER TABLE `attendances`
  ADD PRIMARY KEY (`id`),
  ADD KEY `attendances_student_id_foreign` (`student_id`);

--
-- Indexes for table `attendance_codes`
--
ALTER TABLE `attendance_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `attendance_codes_class_session_id_foreign` (`class_session_id`);

--
-- Indexes for table `cache`
--
ALTER TABLE `cache`
  ADD PRIMARY KEY (`key`),
  ADD KEY `cache_expiration_index` (`expiration`);

--
-- Indexes for table `cache_locks`
--
ALTER TABLE `cache_locks`
  ADD PRIMARY KEY (`key`),
  ADD KEY `cache_locks_expiration_index` (`expiration`);

--
-- Indexes for table `class_sessions`
--
ALTER TABLE `class_sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `class_sessions_subject_id_foreign` (`subject_id`),
  ADD KEY `class_sessions_lecturer_id_foreign` (`lecturer_id`);

--
-- Indexes for table `curriculum_activities`
--
ALTER TABLE `curriculum_activities`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `lecturers`
--
ALTER TABLE `lecturers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `lecturers_staff_id_unique` (`staff_id`),
  ADD KEY `lecturers_user_id_foreign` (`user_id`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `modules`
--
ALTER TABLE `modules`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_modules_lecturer` (`lecturer_id`);

--
-- Indexes for table `module_attendances`
--
ALTER TABLE `module_attendances`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `module_attendance_codes`
--
ALTER TABLE `module_attendance_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_module_session_id` (`module_session_id`);

--
-- Indexes for table `module_registrations`
--
ALTER TABLE `module_registrations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `module_registrations_student_id_foreign` (`student_id`),
  ADD KEY `module_registrations_module_id_foreign` (`module_id`),
  ADD KEY `module_registrations_module_schedule_id_foreign` (`module_schedule_id`);

--
-- Indexes for table `module_schedules`
--
ALTER TABLE `module_schedules`
  ADD PRIMARY KEY (`id`),
  ADD KEY `module_schedules_module_id_foreign` (`module_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `students`
--
ALTER TABLE `students`
  ADD PRIMARY KEY (`id`),
  ADD KEY `students_user_id_foreign` (`user_id`);

--
-- Indexes for table `subjects`
--
ALTER TABLE `subjects`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `subjects_code_unique` (`code`);

--
-- Indexes for table `subject_registrations`
--
ALTER TABLE `subject_registrations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `subject_registrations_student_id_foreign` (`student_id`),
  ADD KEY `subject_registrations_subject_id_foreign` (`subject_id`),
  ADD KEY `subject_registrations_staff_id_foreign` (`staff_id`);

--
-- Indexes for table `tuition_fees`
--
ALTER TABLE `tuition_fees`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activity_participations`
--
ALTER TABLE `activity_participations`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendances`
--
ALTER TABLE `attendances`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attendance_codes`
--
ALTER TABLE `attendance_codes`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `class_sessions`
--
ALTER TABLE `class_sessions`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `curriculum_activities`
--
ALTER TABLE `curriculum_activities`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `lecturers`
--
ALTER TABLE `lecturers`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `modules`
--
ALTER TABLE `modules`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `module_attendances`
--
ALTER TABLE `module_attendances`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `module_attendance_codes`
--
ALTER TABLE `module_attendance_codes`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `module_registrations`
--
ALTER TABLE `module_registrations`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `module_schedules`
--
ALTER TABLE `module_schedules`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `students`
--
ALTER TABLE `students`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `subjects`
--
ALTER TABLE `subjects`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `subject_registrations`
--
ALTER TABLE `subject_registrations`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `tuition_fees`
--
ALTER TABLE `tuition_fees`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendances`
--
ALTER TABLE `attendances`
  ADD CONSTRAINT `attendances_student_id_foreign` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `attendance_codes`
--
ALTER TABLE `attendance_codes`
  ADD CONSTRAINT `attendance_codes_class_session_id_foreign` FOREIGN KEY (`class_session_id`) REFERENCES `class_sessions` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `class_sessions`
--
ALTER TABLE `class_sessions`
  ADD CONSTRAINT `class_sessions_lecturer_id_foreign` FOREIGN KEY (`lecturer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `class_sessions_subject_id_foreign` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `lecturers`
--
ALTER TABLE `lecturers`
  ADD CONSTRAINT `lecturers_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `modules`
--
ALTER TABLE `modules`
  ADD CONSTRAINT `fk_modules_lecturer` FOREIGN KEY (`lecturer_id`) REFERENCES `lecturers` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `module_registrations`
--
ALTER TABLE `module_registrations`
  ADD CONSTRAINT `module_registrations_module_id_foreign` FOREIGN KEY (`module_id`) REFERENCES `modules` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `module_registrations_module_schedule_id_foreign` FOREIGN KEY (`module_schedule_id`) REFERENCES `module_schedules` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `module_registrations_student_id_foreign` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `module_schedules`
--
ALTER TABLE `module_schedules`
  ADD CONSTRAINT `module_schedules_module_id_foreign` FOREIGN KEY (`module_id`) REFERENCES `modules` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `students`
--
ALTER TABLE `students`
  ADD CONSTRAINT `students_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `subject_registrations`
--
ALTER TABLE `subject_registrations`
  ADD CONSTRAINT `subject_registrations_staff_id_foreign` FOREIGN KEY (`staff_id`) REFERENCES `lecturers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `subject_registrations_student_id_foreign` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `subject_registrations_subject_id_foreign` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
