import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sams_frontend/attendance/student/attendance.dart';
import 'package:sams_frontend/attendance/student/view_course.dart';

class StudentClassPage extends StatefulWidget {
  const StudentClassPage({super.key});

  @override
  State<StudentClassPage> createState() => _StudentClassPageState();
}

class _StudentClassPageState extends State<StudentClassPage> {
  int studentId = 0;
  List<Map<String, dynamic>> bookedCourses = [];
  List<Map<String, dynamic>> bookedModules = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSessionAndFetch();
  }

  Future<void> loadSessionAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');
    final savedUserId = prefs.getInt('user_id');

    int resolvedStudentId = savedStudentId ?? savedUserId ?? 0;

    setState(() {
      studentId = resolvedStudentId;
    });

    debugPrint('StudentClassPage loaded studentId: $resolvedStudentId');
    await fetchRegisteredSubjectsWithId(resolvedStudentId);
  }

  Future<void> fetchRegisteredSubjects() async {
    await fetchRegisteredSubjectsWithId(studentId);
  }

  Future<void> fetchRegisteredSubjectsWithId(int id) async {
    setState(() => isLoading = true);

    if (id == 0) {
      setState(() {
        bookedCourses = [];
        bookedModules = [];
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/api/student/$id/subjects'))
          .timeout(const Duration(seconds: 10));

      final moduleResponse = await http
          .get(Uri.parse('http://10.0.2.2:8000/api/student/$id/modules'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        List moduleData = [];
        if (moduleResponse.statusCode == 200) {
          moduleData = json.decode(moduleResponse.body);
        }

        setState(() {
          bookedCourses = data
              .map<Map<String, dynamic>>((item) => {
                    'id': item['id'],
                    'subject_id': item['subject_id'],
                    'code': item['code']?.toString() ?? '',
                    'name': item['name']?.toString() ?? '',
                    'attendanceEnabled': true,
                  })
              .toList();

          bookedModules = moduleData
              .map<Map<String, dynamic>>((item) => {
                    'id': item['id'],
                    'module_id': item['module_id'],
                    'code': item['code']?.toString() ?? '',
                    'name': item['name']?.toString() ?? '',
                    'attendanceEnabled': true,
                  })
              .toList();

          isLoading = false;
        });
      } else {
        debugPrint('Student subjects API failed: ${response.statusCode}');
        debugPrint('Student subjects API body: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching registered subjects/modules: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1F2),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF67C5C4),
              ),
              child: const Text(
                'My Course and Module',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchRegisteredSubjects,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            const Text(
                              'Booked Course',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (bookedCourses.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'No registered course yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5F6570),
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              )
                            else
                              ...bookedCourses.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _buildBookingCard(
                                    subjectId: int.tryParse(item['subject_id'].toString()) ?? 0,
                                    code: item['code'] as String,
                                    name: item['name'] as String,
                                    attendanceEnabled: item['attendanceEnabled'] as bool,
                                    attendanceType: 'course',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Booked Module',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (bookedModules.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'No registered module yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF5F6570),
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              )
                            else
                              ...bookedModules.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _buildBookingCard(
                                    subjectId: int.tryParse(item['module_id'].toString()) ?? 0,
                                    code: item['code'] as String,
                                    name: item['name'] as String,
                                    attendanceEnabled: item['attendanceEnabled'] as bool,
                                    attendanceType: 'module',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required int subjectId,
    required String code,
    required String name,
    required bool attendanceEnabled,
    required String attendanceType,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Center(
              child: Image.asset(
                'assets/images/booked_course.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.menu_book_rounded,
                    size: 68,
                    color: Color(0xFF1F3A68),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.25,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildActionButton(
                      label: 'View Course',
                      isEnabled: true,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ViewCoursePage(),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      label: 'Submit Attendance',
                      isEnabled: attendanceEnabled,
                      onPressed: attendanceEnabled
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentAttendancePage(
                                    studentId: studentId,
                                    subjectId: subjectId,
                                    subjectCode: code,
                                    subjectName: name,
                                    attendanceType: attendanceType,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 120,
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isEnabled ? const Color(0xFF67C5C4) : const Color(0xFFE5E5E7),
          foregroundColor:
              isEnabled ? Colors.white : const Color(0xFFB8B8BC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }
}