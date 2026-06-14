import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sams_frontend/attendance/lecturer/attendance.dart';
import 'package:sams_frontend/attendance/lecturer/add_session.dart';
import 'package:sams_frontend/main.dart' show LoginPage;

class ClassPage extends StatefulWidget {
  const ClassPage({super.key});

  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  List<Map<String, String>> courses = [];   // Senarai subjek unik yang diajar
  List<Map<String, String>> modules = [];   // Senarai module unik yang diajar
  bool isLoading = true;
  int lecturerId = 0;                        // ID lecturer dari SharedPreferences

  // Semua sesi gabungan (course + module) — untuk reference kalau perlu
  List<Map<String, String>> allClassSessions = [];

  // Map untuk group sesi ikut kod kursus — key: "BCS1234", value: list of sessions
  Map<String, List<Map<String, String>>> courseSessionsMap = {};
  Map<String, List<Map<String, String>>> moduleSessionsMap = {};

  @override
  void initState() {
    super.initState();
    loadSessionAndFetch();
  }

  /// Logout — clear semua SharedPreferences dan redirect ke LoginPage.
  /// pushAndRemoveUntil supaya user tak boleh back ke ClassPage selepas logout.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Buang semua route sebelum ni
    );
  }

  /// Load lecturer ID dari SharedPreferences, kemudian fetch kelas.
  /// Guna lecturer_id kalau ada, fallback ke user_id kalau lecturer_id takde.
  Future<void> loadSessionAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLecturerId = prefs.getInt('lecturer_id');
    final savedUserId = prefs.getInt('user_id');

    // Prioriti: lecturer_id → user_id → 0 (takde session)
    final resolvedLecturerId = savedLecturerId ?? savedUserId ?? 0;

    debugPrint('=== PREFS CHECK ===');
    debugPrint('lecturer_id: $savedLecturerId');
    debugPrint('user_id: $savedUserId');
    debugPrint('resolved: $resolvedLecturerId');

    if (mounted) {
      setState(() {
        lecturerId = resolvedLecturerId;
      });
    }

    await fetchClasses(overrideLecturerId: resolvedLecturerId);
  }

  /// Fetch semua kelas (course + module) untuk lecturer dari API.
  /// [overrideLecturerId] dipakai pada first load sebab lecturerId state
  /// mungkin belum update lagi masa function ni dipanggil.
  Future<void> fetchClasses({int? overrideLecturerId}) async {
    final idToUse = overrideLecturerId ?? lecturerId;

    // Kalau ID tak valid, reset semua dan stop
    if (idToUse == 0) {
      setState(() {
        isLoading = false;
        courses = [];
        modules = [];
        courseSessionsMap = {};
        moduleSessionsMap = {};
      });
      debugPrint('No lecturer_id found in session');
      return;
    }

    debugPrint('Fetching classes for lecturerId: $idToUse');

    try {
      final response = await http
          .get(
            Uri.parse(
                'https://darkgrey-lyrebird-505549.hostingersite.com/api/lecturer/$idToUse/classes'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Lecturer classes API success: ${response.body}');
        final List data = json.decode(response.body);

        // Temp lists untuk kumpul sesi sebelum setState
        final List<Map<String, String>> courseSessionData = [];
        final List<Map<String, String>> moduleSessionData = [];

        // Map untuk deduplicate — key: "code|name" supaya takde duplicate card
        final Map<String, Map<String, String>> uniqueCourses = {};
        final Map<String, Map<String, String>> uniqueModules = {};

        // Map untuk group sesi ikut kod — untuk bottom sheet list
        final Map<String, List<Map<String, String>>> groupedCourseSessions = {};
        final Map<String, List<Map<String, String>>> groupedModuleSessions = {};

        for (final rawItem in data) {
          final Map<String, dynamic> item =
              Map<String, dynamic>.from(rawItem as Map);

          final attendanceType =
              item['attendance_type']?.toString().toLowerCase() ?? '';
          final bool isModuleItem = attendanceType == 'module';

          // Pilih code dan name ikut jenis item
          final String code = isModuleItem
              ? (item['module_code']?.toString() ?? '')
              : (item['subject_code']?.toString() ?? '');
          final String name = isModuleItem
              ? (item['module_name']?.toString() ?? '')
              : (item['subject_name']?.toString() ?? '');
          final String sessionId = item['id']?.toString() ?? '';

          // Normalize semua data jadi Map<String, String> yang seragam
          final sessionMap = {
            'id': sessionId,
            'code': code,
            'name': name,
            'class_date': item['class_date']?.toString() ?? '',
            'start_time': item['start_time']?.toString() ?? '',
            'end_time': item['end_time']?.toString() ?? '',
            'session_type': item['session_type']?.toString() ?? '',
            'week_number': item['week_number']?.toString() ?? '',
            'attendance_type': isModuleItem ? 'module' : 'course',
            'module_id': item['module_id']?.toString() ?? '',
            'subject_id': item['subject_id']?.toString() ?? '',
          };

          if (isModuleItem) {
            // Skip placeholder module sessions (API return row tanpa session ID)
            if (sessionId.isEmpty) continue;

            moduleSessionData.add(sessionMap);

            // Deduplicate module — guna "code|name" sebagai unique key
            final key = '$code|$name';
            uniqueModules.putIfAbsent(
              key,
              () => {
                'code': code,
                'name': name,
                'attendance_type': 'module',
                'module_id': item['module_id']?.toString() ?? '',
              },
            );

            // Group sesi ikut kod yang dinormalize (uppercase, trim)
            final normalizedCode = code.trim().toUpperCase();
            groupedModuleSessions.putIfAbsent(normalizedCode, () => []);
            groupedModuleSessions[normalizedCode]!.add(sessionMap);
          } else {
            // Deduplicate course — sama macam module
            final key = '$code|$name';
            uniqueCourses.putIfAbsent(
              key,
              () => {
                'code': code,
                'name': name,
                'attendance_type': 'course',
                'subject_id': item['subject_id']?.toString() ?? '',
              },
            );

            // Course boleh ada placeholder (subjek tanpa sesi lagi) —
            // subjek still dipaparkan tapi takde dalam sessions list
            if (sessionId.isNotEmpty) {
              courseSessionData.add(sessionMap);
              final normalizedCode = code.trim().toUpperCase();
              groupedCourseSessions.putIfAbsent(normalizedCode, () => []);
              groupedCourseSessions[normalizedCode]!.add(sessionMap);
            }
          }
        }

        debugPrint('Parsed courses count: ${uniqueCourses.length}');
        debugPrint('Parsed modules count: ${uniqueModules.length}');

        setState(() {
          allClassSessions = [...courseSessionData, ...moduleSessionData];
          courseSessionsMap = groupedCourseSessions;
          moduleSessionsMap = groupedModuleSessions;
          courses = uniqueCourses.values.toList();
          modules = uniqueModules.values.toList();
          isLoading = false;
        });
      } else {
        debugPrint('Lecturer classes API failed: ${response.statusCode}');
        // Reset state kalau API gagal — tunjuk empty state
        setState(() {
          courses = [];
          modules = [];
          courseSessionsMap = {};
          moduleSessionsMap = {};
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lecturer classes: $e');
      // Sama — reset state kalau ada network error
      setState(() {
        courses = [];
        modules = [];
        courseSessionsMap = {};
        moduleSessionsMap = {};
        isLoading = false;
      });
    }
  }

  /// Tunjuk bottom sheet dengan senarai sesi kelas untuk kursus/module yang dipilih.
  /// Tap pada sesi akan navigate ke AttendancePage untuk sesi tersebut.
  void _showCourseSessions(Map<String, String> course) {
    final selectedCode = (course['code'] ?? '').trim().toUpperCase();
    final attendanceType = course['attendance_type'] ?? 'course';

    // Ambil sesi dari map yang betul ikut attendance type
    final sessions = List<Map<String, String>>.from(
      attendanceType == 'module'
          ? (moduleSessionsMap[selectedCode] ?? <Map<String, String>>[])
          : (courseSessionsMap[selectedCode] ?? <Map<String, String>>[]),
    );

    debugPrint('Selected code: $selectedCode');
    debugPrint('Attendance type: $attendanceType');
    debugPrint('Mapped sessions count: ${sessions.length}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // DraggableScrollableSheet untuk bottom sheet yang boleh drag naik/turun
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,  // Default 50% screen
          maxChildSize: 0.9,       // Max 90% screen
          minChildSize: 0.3,       // Min 30% screen
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header — nama subjek/module
                    Text(
                      '${course['code'] ?? ''} ${course['name'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: sessions.isEmpty
                          // Empty state — subjek ada tapi belum ada sesi
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 48, color: Colors.black26),
                                  SizedBox(height: 12),
                                  Text(
                                    'No class sessions yet.',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap "Add Session" to create one.',
                                    style: TextStyle(
                                        color: Colors.black38, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          // List sesi kelas yang boleh di-scroll
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F7FB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                    // Tarikh sesi sebagai title
                                    title: Text(
                                      _formatDisplayDate(
                                          session['class_date'] ?? '-'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Label sesi, contoh: "Lecture Session • Week 3"
                                          Text(
                                            _buildSessionLabel(session),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E4E96),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Masa mula - masa tamat
                                          Text(
                                            _formatTimeRange(
                                              session['start_time'] ?? '-',
                                              session['end_time'] ?? '-',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16),
                                    onTap: () {
                                      // Resolve subject ID yang betul ikut attendance type
                                      final subjectId = int.tryParse(
                                              session['subject_id'] ?? '') ??
                                          0;
                                      final moduleId = int.tryParse(
                                              session['module_id'] ?? '') ??
                                          0;
                                      // Module guna module_id, course guna subject_id
                                      final resolvedSubjectId =
                                          attendanceType == 'module'
                                              ? moduleId
                                              : subjectId;

                                      // Tutup bottom sheet dulu, pastu navigate
                                      Navigator.pop(context);
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(
                                          builder: (context) => AttendancePage(
                                            classSessionId: int.tryParse(
                                                    session['id'] ?? '') ??
                                                1,
                                            subjectId: resolvedSubjectId,
                                            subjectCode:
                                                session['code'] ?? '',
                                            subjectName:
                                                session['name'] ?? '',
                                            classDate:
                                                session['class_date'] ?? '',
                                            startTime:
                                                session['start_time'] ?? '',
                                            endTime:
                                                session['end_time'] ?? '',
                                            attendanceType: session[
                                                    'attendance_type'] ??
                                                attendanceType,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Format tarikh dari "2026-06-14" ke "14 Jun 2026" untuk display dalam list
  String _formatDisplayDate(String rawDate) {
    if (rawDate.isEmpty || rawDate == '-') return '-';
    try {
      final date = DateTime.parse(rawDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return rawDate; // Fallback kalau parse gagal
    }
  }

  /// Format masa dari "08:00:00" ke "8:00 AM" (12-jam format)
  String _formatTimeValue(String rawTime) {
    if (rawTime.isEmpty || rawTime == '-') return '-';
    try {
      final parts = rawTime.split(':');
      if (parts.length < 2) return rawTime;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12; // 0 → 12
      final displayMinute = minute.toString().padLeft(2, '0');
      return '$displayHour:$displayMinute $suffix';
    } catch (_) {
      return rawTime;
    }
  }

  /// Gabungkan start dan end time jadi "8:00 AM - 10:00 AM"
  String _formatTimeRange(String startTime, String endTime) {
    return '${_formatTimeValue(startTime)} - ${_formatTimeValue(endTime)}';
  }

  /// Bina label sesi untuk display, contoh: "Lecture Session • Week 3"
  /// Kalau takde session_type, guna default berdasarkan attendance type.
  String _buildSessionLabel(Map<String, String> session) {
    final rawType = (session['session_type'] ?? '').trim();
    final rawWeek = (session['week_number'] ?? '').trim();

    // Capitalize first letter, lowercase the rest: "LECTURE" → "Lecture Session"
    final sessionType = rawType.isEmpty
        ? (session['attendance_type'] == 'module'
            ? 'Module Session'
            : 'Session')
        : '${rawType[0].toUpperCase()}${rawType.substring(1).toLowerCase()} Session';

    // Kalau takde week number, return type sahaja
    if (rawWeek.isEmpty) return sessionType;
    return '$sessionType • Week $rawWeek';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAssignments = courses.isNotEmpty || modules.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1F2),
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar — ada butang logout kat kanan
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF2E4E96),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Course and Module List',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout,
                        color: Colors.white, size: 28),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                // Pull-to-refresh akan trigger fetchClasses semula
                onRefresh: fetchClasses,
                child: isLoading
                    // Loading state — tunjuk spinner
                    ? const Center(child: CircularProgressIndicator())
                    : hasAssignments
                        // Ada data — tunjuk table course dan/atau module
                        ? SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // Wajib untuk RefreshIndicator
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Section Course — hanya papar kalau ada
                                if (courses.isNotEmpty) ...[
                                  const Text(
                                    'Course',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildListCard(
                                    titleOne: 'COURSE CODE',
                                    titleTwo: 'COURSE NAME',
                                    actionTitle: 'ACTION',
                                    data: courses,
                                    viewLabel: 'View Course',
                                    isCourse: true, // Course ada butang "Add Session"
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                // Section Module — hanya papar kalau ada
                                if (modules.isNotEmpty) ...[
                                  const Text(
                                    'Module',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildListCard(
                                    titleOne: 'MODULE CODE',
                                    titleTwo: 'MODULE NAME',
                                    actionTitle: 'ACTION',
                                    data: modules,
                                    viewLabel: 'View Module',
                                    isCourse: false, // Module takde butang "Add Session"
                                  ),
                                ],
                              ],
                            ),
                          )
                        // Empty state — lecturer belum ada assignment
                        : ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // Wajib untuk RefreshIndicator
                            children: const [
                              SizedBox(height: 120),
                              Icon(
                                Icons.menu_book_outlined,
                                size: 72,
                                color: Color(0xFF9AA0AF),
                              ),
                              SizedBox(height: 20),
                              Center(
                                child: Text(
                                  'No course or module assigned yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32),
                                child: Text(
                                  'Please wait until the Faculty Registrar assigns a course or module to you.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bina table card untuk senarai course atau module.
  /// [isCourse] menentukan sama ada butang "Add Session" dipaparkan —
  /// hanya course boleh tambah sesi, module sesi diurus dari sistem lain.
  Widget _buildListCard({
    required String titleOne,
    required String titleTwo,
    required String actionTitle,
    required List<Map<String, String>> data,
    required String viewLabel,
    required bool isCourse,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          // Header row untuk column titles
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    titleOne,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    titleTwo,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    actionTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
              height: 1, thickness: 1, color: Color(0xFF3C3C3C)),
          // Generate rows untuk setiap item
          ...List.generate(data.length, (index) {
            final item = data[index];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Kod kursus/module
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['code'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Nama kursus/module
                      Expanded(
                        flex: 4,
                        child: Text(
                          item['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Kolum butang tindakan
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            // "View Course" / "View Module" — placeholder, belum ada action
                            _buildActionButton(viewLabel),
                            const SizedBox(height: 8),
                            // "Attendance" — buka bottom sheet senarai sesi
                            _buildActionButton(
                              'Attendance',
                              onPressed: () =>
                                  _showCourseSessions(item),
                            ),
                            // "Add Session" — hanya untuk course, bukan module
                            if (isCourse) ...[
                              const SizedBox(height: 8),
                              _buildActionButton(
                                'Add Session',
                                color: const Color(0xFF1A8C5B), // Hijau untuk distinguish
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AddSessionPage(
                                        lecturerId: lecturerId,
                                        subjectId:
                                            item['subject_id'] ?? '',
                                        subjectCode:
                                            item['code'] ?? '',
                                        subjectName:
                                            item['name'] ?? '',
                                      ),
                                    ),
                                  );
                                  // Refresh list kalau sesi berjaya ditambah
                                  if (result == true) fetchClasses();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider antara rows — kecuali row terakhir
                if (index != data.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Color(0xFF3C3C3C),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Reusable action button — kecil dan seragam untuk semua butang dalam table.
  /// [color] optional — default biru, boleh override (e.g. hijau untuk Add Session).
  Widget _buildActionButton(String label,
      {VoidCallback? onPressed, Color? color}) {
    return SizedBox(
      width: 92,
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed ?? () {}, // Fallback ke no-op kalau takde handler
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF2E4E96),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
