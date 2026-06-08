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
  List<Map<String, String>> courses = [];
  List<Map<String, String>> modules = [];
  bool isLoading = true;
  int lecturerId = 0;
  List<Map<String, String>> allClassSessions = [];
  Map<String, List<Map<String, String>>> courseSessionsMap = {};
  Map<String, List<Map<String, String>>> moduleSessionsMap = {};

  @override
  void initState() {
    super.initState();
    loadSessionAndFetch();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> loadSessionAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLecturerId = prefs.getInt('lecturer_id');
    final savedUserId = prefs.getInt('user_id');

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

  Future<void> fetchClasses({int? overrideLecturerId}) async {
    final idToUse = overrideLecturerId ?? lecturerId;

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

        final List<Map<String, String>> courseSessionData = [];
        final List<Map<String, String>> moduleSessionData = [];
        final Map<String, Map<String, String>> uniqueCourses = {};
        final Map<String, Map<String, String>> uniqueModules = {};
        final Map<String, List<Map<String, String>>> groupedCourseSessions = {};
        final Map<String, List<Map<String, String>>> groupedModuleSessions = {};

        for (final rawItem in data) {
          final Map<String, dynamic> item =
              Map<String, dynamic>.from(rawItem as Map);

          final attendanceType =
              item['attendance_type']?.toString().toLowerCase() ?? '';
          final bool isModuleItem = attendanceType == 'module';

          final String code = isModuleItem
              ? (item['module_code']?.toString() ?? '')
              : (item['subject_code']?.toString() ?? '');
          final String name = isModuleItem
              ? (item['module_name']?.toString() ?? '')
              : (item['subject_name']?.toString() ?? '');
          final String sessionId = item['id']?.toString() ?? '';

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
            // Skip placeholder sessions (id is null)
            if (sessionId.isEmpty) continue;

            moduleSessionData.add(sessionMap);

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

            final normalizedCode = code.trim().toUpperCase();
            groupedModuleSessions.putIfAbsent(normalizedCode, () => []);
            groupedModuleSessions[normalizedCode]!.add(sessionMap);
          } else {
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

            // Only add to sessions if it has a real session (not placeholder)
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
      setState(() {
        courses = [];
        modules = [];
        courseSessionsMap = {};
        moduleSessionsMap = {};
        isLoading = false;
      });
    }
  }

  void _showCourseSessions(Map<String, String> course) {
    final selectedCode = (course['code'] ?? '').trim().toUpperCase();
    final attendanceType = course['attendance_type'] ?? 'course';
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
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
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
                                          Text(
                                            _buildSessionLabel(session),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E4E96),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
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
                                      final subjectId = int.tryParse(
                                              session['subject_id'] ?? '') ??
                                          0;
                                      final moduleId = int.tryParse(
                                              session['module_id'] ?? '') ??
                                          0;
                                      final resolvedSubjectId =
                                          attendanceType == 'module'
                                              ? moduleId
                                              : subjectId;

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
      return rawDate;
    }
  }

  String _formatTimeValue(String rawTime) {
    if (rawTime.isEmpty || rawTime == '-') return '-';
    try {
      final parts = rawTime.split(':');
      if (parts.length < 2) return rawTime;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final displayMinute = minute.toString().padLeft(2, '0');
      return '$displayHour:$displayMinute $suffix';
    } catch (_) {
      return rawTime;
    }
  }

  String _formatTimeRange(String startTime, String endTime) {
    return '${_formatTimeValue(startTime)} - ${_formatTimeValue(endTime)}';
  }

  String _buildSessionLabel(Map<String, String> session) {
    final rawType = (session['session_type'] ?? '').trim();
    final rawWeek = (session['week_number'] ?? '').trim();
    final sessionType = rawType.isEmpty
        ? (session['attendance_type'] == 'module'
            ? 'Module Session'
            : 'Session')
        : '${rawType[0].toUpperCase()}${rawType.substring(1).toLowerCase()} Session';
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
                onRefresh: fetchClasses,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasAssignments
                        ? SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
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
                                    isCourse: true,
                                  ),
                                  const SizedBox(height: 24),
                                ],
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
                                    isCourse: false,
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
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
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['code'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
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
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildActionButton(viewLabel),
                            const SizedBox(height: 8),
                            _buildActionButton(
                              'Attendance',
                              onPressed: () =>
                                  _showCourseSessions(item),
                            ),
                            if (isCourse) ...[
                              const SizedBox(height: 8),
                              _buildActionButton(
                                'Add Session',
                                color: const Color(0xFF1A8C5B),
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

  Widget _buildActionButton(String label,
      {VoidCallback? onPressed, Color? color}) {
    return SizedBox(
      width: 92,
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
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