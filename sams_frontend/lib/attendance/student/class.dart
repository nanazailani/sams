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
  // Base URL API — static const supaya tak perlu instantiate
  static const _baseUrl =
      'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  int studentId = 0;
  List<Map<String, dynamic>> bookedCourses = []; // Senarai subjek yang didaftar
  List<Map<String, dynamic>> bookedModules = []; // Senarai module yang didaftar
  bool isLoading = true;

  // Status lock pelajar — true kalau yuran belum bayar selepas Week 5
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    // Dua call parallel: load data pelajar DAN semak lock status
    loadSessionAndFetch();
    _checkLockStatus();
  }

  /// Semak dari API sama ada pelajar ini di-block (yuran belum bayar).
  /// Kalau blocked, butang attendance dan drop akan disabled, tunjuk warning banner.
  Future<void> _checkLockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = prefs.getInt('student_id') ?? 0;
      // Hantar student_id sebagai query param untuk API semak status lock
      final uri = Uri.parse('$_baseUrl/week-lock/status')
          .replace(queryParameters: {'student_id': sid.toString()});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // API return boolean field 'student_blocked'
            _isBlocked = data['student_blocked'] == true;
          });
        }
      }
    } catch (e) {
      // Silent fail — kalau lock check gagal, anggap tak blocked
      debugPrint('Lock check error: $e');
    }
  }

  /// Load student ID dari SharedPreferences kemudian fetch senarai subjek.
  /// Prioriti ID: student_id → user_id → 0
  Future<void> loadSessionAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');
    final savedUserId = prefs.getInt('user_id');

    // Fallback chain: student_id → user_id → 0
    int resolvedStudentId = savedStudentId ?? savedUserId ?? 0;

    setState(() {
      studentId = resolvedStudentId;
    });

    debugPrint('StudentClassPage loaded studentId: $resolvedStudentId');
    await fetchRegisteredSubjectsWithId(resolvedStudentId);
  }

  /// Wrapper untuk pull-to-refresh — guna studentId yang dah diset dalam state
  Future<void> fetchRegisteredSubjects() async {
    await fetchRegisteredSubjectsWithId(studentId);
  }

  /// Fetch subjects dan modules secara parallel dari dua endpoint berbeza.
  /// Modules deduplicate guna seenModuleIds supaya takde duplicate dalam list.
  Future<void> fetchRegisteredSubjectsWithId(int id) async {
    setState(() => isLoading = true);

    // Guard: kalau ID tak valid, reset dan stop
    if (id == 0) {
      setState(() {
        bookedCourses = [];
        bookedModules = [];
        isLoading = false;
      });
      return;
    }

    try {
      // Fetch subjects dan modules — dua request berasingan
      final response = await http
          .get(Uri.parse('$_baseUrl/student/$id/subjects'))
          .timeout(const Duration(seconds: 10));

      final moduleResponse = await http
          .get(Uri.parse('$_baseUrl/student/$id/modules'))
          .timeout(const Duration(seconds: 10));

      List data = [];
      List moduleData = [];

      if (response.statusCode == 200) {
        data = json.decode(response.body);
      }

      if (moduleResponse.statusCode == 200) {
        moduleData = json.decode(moduleResponse.body);
      }

      setState(() {
        // Map subjects ke format seragam
        bookedCourses = data.map<Map<String, dynamic>>((item) => {
              'id': item['id'],
              'subject_id': item['subject_id'],
              'code': item['code']?.toString() ?? '',
              'name': item['name']?.toString() ?? '',
              'attendanceEnabled': true,
            }).toList();

        // Deduplicate modules — API mungkin return duplicate module_id
        final seenModuleIds = <String>{};
        bookedModules = moduleData
            .where((item) =>
                seenModuleIds.add(item['module_id'].toString()))
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
    } catch (e) {
      debugPrint('Error fetching data: $e');
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
            // Custom app bar — teal untuk student side
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 28),
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
                // Pull-to-refresh trigger fetchRegisteredSubjects
                onRefresh: fetchRegisteredSubjects,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        // AlwaysScrollableScrollPhysics wajib supaya RefreshIndicator berfungsi
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Warning banner — hanya dipapar kalau pelajar di-block ──
                            // Tunjuk bila yuran belum bayar selepas Week 5
                            if (_isBlocked)
                              Container(
                                width: double.infinity,
                                margin:
                                    const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD), // Kuning muda
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFFD54F)),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: const [
                                    Icon(Icons.lock,
                                        color: Color(0xFFF9A825),
                                        size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Reminder: Your tuition has not been fully paid. '
                                        'Academic modules are locked after Week 5 until '
                                        'payment is completed. Please proceed to the '
                                        'Payment module to settle your balance.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7B5800),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 18),

                            // ── Section: Booked Course ──
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
                              // Empty state untuk course
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(20),
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
                              // Render card untuk setiap subjek yang didaftar
                              ...bookedCourses.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 14),
                                  child: _buildBookingCard(
                                    subjectId: int.tryParse(
                                            item['subject_id']
                                                .toString()) ??
                                        0,
                                    code: item['code'] as String,
                                    name: item['name'] as String,
                                    attendanceEnabled:
                                        item['attendanceEnabled']
                                            as bool,
                                    attendanceType: 'course',
                                    canDrop: true, // Course boleh drop, module tidak
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),

                            // ── Section: Booked Module ──
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
                              // Empty state untuk module
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(20),
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
                              // Render card untuk setiap module yang didaftar
                              ...bookedModules.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 14),
                                  child: _buildBookingCard(
                                    subjectId: int.tryParse(
                                            item['module_id']
                                                .toString()) ??
                                        0,
                                    code: item['code'] as String,
                                    name: item['name'] as String,
                                    attendanceEnabled:
                                        item['attendanceEnabled']
                                            as bool,
                                    attendanceType: 'module',
                                    canDrop: false, // Module tak boleh drop dari sini
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

  /// Bina card untuk satu subjek atau module.
  /// [canDrop] — true untuk course (ada butang Drop), false untuk module.
  /// Semua butang disabled kalau [_isBlocked] = true (yuran belum bayar).
  Widget _buildBookingCard({
    required int subjectId,
    required String code,
    required String name,
    required bool attendanceEnabled,
    required String attendanceType,
    required bool canDrop,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gambar ilustrasi subjek — fallback ke icon kalau asset tak jumpa
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
                  // Fallback icon kalau image asset tak wujud
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
                // Kod subjek/module
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
                // Nama subjek/module
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
                // Butang-butang action — Wrap supaya responsive kalau text panjang
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Butang View Course — disabled kalau blocked
                    _buildActionButton(
                      label: 'View Course',
                      isEnabled: !_isBlocked,
                      onPressed: _isBlocked
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ViewCoursePage(),
                                ),
                              );
                            },
                    ),
                    // Butang Submit Attendance — disabled kalau blocked atau attendance tak enabled
                    // Label bertukar ke 'Locked' kalau blocked
                    _buildActionButton(
                      label: _isBlocked
                          ? 'Locked'
                          : 'Submit Attendance',
                      isEnabled:
                          !_isBlocked && attendanceEnabled,
                      onPressed: _isBlocked || !attendanceEnabled
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StudentAttendancePage(
                                    studentId: studentId,
                                    subjectId: subjectId,
                                    subjectCode: code,
                                    subjectName: name,
                                    attendanceType: attendanceType,
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Butang Drop — hanya dipapar untuk course (canDrop = true)
          // Disabled dan label 'Locked' kalau pelajar di-block
          if (canDrop) ...[
            const SizedBox(width: 10),
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 58,
                height: 30,
                child: ElevatedButton(
                  onPressed: _isBlocked
                      ? null
                      : () => _confirmDropSubject(
                            subjectId,
                            code,
                            name,
                          ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    // Warna kelabu kalau blocked, merah kalau boleh drop
                    backgroundColor: _isBlocked
                        ? const Color(0xFFE5E5E7)
                        : const Color(0xFFFF2338),
                    foregroundColor: _isBlocked
                        ? const Color(0xFFB8B8BC)
                        : Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isBlocked ? 'Locked' : 'Drop',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tunjuk dialog konfirmasi sebelum drop subjek.
  /// Kalau confirm, hantar DELETE request ke API dan refresh list.
  Future<void> _confirmDropSubject(
      int subjectId, String code, String name) async {
    final shouldDrop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Drop Subject'),
        content:
            Text('Are you sure you want to drop $code - $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2338),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Drop'),
          ),
        ],
      ),
    );

    // Stop kalau user cancel atau studentId tak valid
    if (shouldDrop != true || studentId == 0) return;

    try {
      final response = await http
          .delete(
            Uri.parse(
              '$_baseUrl/students/$studentId/registered-subjects/$subjectId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject dropped successfully'),
            backgroundColor: Color(0xFF67C5C4), // Teal untuk success
          ),
        );
        // Refresh list selepas drop berjaya
        await fetchRegisteredSubjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to drop subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  /// Reusable action button untuk View Course dan Submit Attendance.
  /// [isEnabled] menentukan warna — teal kalau aktif, kelabu kalau disabled.
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
          // Teal kalau enabled, kelabu kalau disabled
          backgroundColor: isEnabled
              ? const Color(0xFF67C5C4)
              : const Color(0xFFE5E5E7),
          foregroundColor: isEnabled
              ? Colors.white
              : const Color(0xFFB8B8BC),
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
