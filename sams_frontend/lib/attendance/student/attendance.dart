import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';

class StudentAttendancePage extends StatefulWidget {
  final int studentId;
  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final String attendanceType;

  const StudentAttendancePage({
    super.key,
    required this.studentId,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.attendanceType,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  bool isLoading = true;
  int? sessionStudentId;
  int? savedUserId;
  final TextEditingController codeController = TextEditingController();
  bool isSubmitting = false;
  bool isGpsVerified = false;
  String gpsStatusText = 'GPS permission not granted';

  String studentName = '-';
  String matricNumber = '-';
  String programme = '-';

  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int classesAttend = 0;
  int totalClasses = 0;
  String attendanceRate = '0%';

  String currentSessionTitle = '-';
  String currentSessionDate = '-';
  String currentSessionTime = '-';
  String activeCode = '-';

  List<Map<String, String>> recentRecords = [];

  String get _normalizedAttendanceType {
    final type = widget.attendanceType.trim().toLowerCase();
    return type == 'module' ? 'module' : 'course';
  }

  bool _hasMeaningfulAttendanceData(Map<String, dynamic> data) {
    final studentNameValue = (data['student_name'] ?? '').toString().trim();
    final currentTitleValue = (data['current_session_title'] ?? '').toString().trim();
    final currentDateValue = (data['current_session_date'] ?? '').toString().trim();
    final currentTimeValue = (data['current_session_time'] ?? '').toString().trim();
    final activeCodeValue = (data['active_code'] ?? '').toString().trim();
    final totalClassesValue = int.tryParse((data['total_classes'] ?? '0').toString()) ?? 0;
    final recentRecordsValue = data['recent_records'] as List? ?? [];

    return (studentNameValue.isNotEmpty && studentNameValue != '-') ||
        (currentTitleValue.isNotEmpty && currentTitleValue != '-') ||
        (currentDateValue.isNotEmpty && currentDateValue != '-') ||
        (currentTimeValue.isNotEmpty && currentTimeValue != '-') ||
        (activeCodeValue.isNotEmpty && activeCodeValue != '-') ||
        totalClassesValue > 0 ||
        recentRecordsValue.isNotEmpty;
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadSession();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');
    final savedUserIdFromPrefs = prefs.getInt('user_id');

    savedUserId = savedUserIdFromPrefs;
    sessionStudentId = savedStudentId ?? widget.studentId;

    debugPrint(
      'StudentAttendancePage loaded studentId: ${sessionStudentId ?? widget.studentId}, '
      'subjectId: ${widget.subjectId}, attendanceType: $_normalizedAttendanceType',
    );

    fetchAttendanceData();
  }

  Future<void> fetchAttendanceData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final candidateIds = <int>[];
      final primaryId = sessionStudentId ?? widget.studentId;
      if (primaryId > 0) candidateIds.add(primaryId);
      if (!candidateIds.contains(widget.studentId) && widget.studentId > 0) {
        candidateIds.add(widget.studentId);
      }
      if (savedUserId != null && !candidateIds.contains(savedUserId) && savedUserId! > 0) {
        candidateIds.add(savedUserId!);
      }

      http.Response? successfulResponse;
      int? successfulStudentId;
      http.Response? lastResponse;
      Map<String, dynamic>? successfulData;

      for (final candidateId in candidateIds) {
        final response = await http
            .get(
              Uri.parse(
                //'http://127.0.0.1:8000/api/student/$candidateId/attendance/${widget.subjectId}?type=$_normalizedAttendanceType',
                'http://10.0.2.2:8000/api/student/$candidateId/attendance/${widget.subjectId}?type=$_normalizedAttendanceType',
              ),
            )
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'Attendance fetch try => studentId: $candidateId, '
          'subjectId: ${widget.subjectId}, type: $_normalizedAttendanceType, '
          'status: ${response.statusCode}',
        );
        debugPrint('Attendance fetch body => ${response.body}');

        lastResponse = response;

        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body) as Map<String, dynamic>;
          final hasMeaningfulData = _hasMeaningfulAttendanceData(decodedData);

          debugPrint(
            'Attendance fetch parsed => studentId: $candidateId, '
            'meaningful: $hasMeaningfulData',
          );

          if (hasMeaningfulData) {
            successfulResponse = response;
            successfulStudentId = candidateId;
            successfulData = decodedData;
            break;
          }
        }
      }

      if (successfulResponse != null) {
        final data = successfulData ?? json.decode(successfulResponse.body) as Map<String, dynamic>;

        final records = (data['recent_records'] as List? ?? [])
            .map<Map<String, String>>(
              (item) => {
                'session': item['session']?.toString() ?? '-',
                'date': item['date']?.toString() ?? '-',
                'time': item['time']?.toString() ?? '-',
                'status': item['status']?.toString() ?? '-',
              },
            )
            .toList();

        setState(() {
          sessionStudentId = successfulStudentId;
          studentName = data['student_name']?.toString() ?? '-';
          matricNumber = data['matric_number']?.toString() ?? '-';
          programme = data['programme']?.toString() ?? '-';

          presentCount = int.tryParse(data['present_count'].toString()) ?? 0;
          lateCount = int.tryParse(data['late_count'].toString()) ?? 0;
          absentCount = int.tryParse(data['absent_count'].toString()) ?? 0;
          classesAttend = int.tryParse(data['classes_attend'].toString()) ?? 0;
          totalClasses = int.tryParse(data['total_classes'].toString()) ?? 0;
          attendanceRate = data['attendance_rate']?.toString() ?? '0%';

          currentSessionTitle =
              data['current_session_title']?.toString() ?? '-';
          currentSessionDate =
              data['current_session_date']?.toString() ?? '-';
          currentSessionTime =
              data['current_session_time']?.toString() ?? '-';
          activeCode = data['active_code']?.toString() ?? '-';

          recentRecords = records;
          isLoading = false;
        });
      } else {
        debugPrint('Student attendance API failed for all candidate IDs or returned only placeholder data');
        if (lastResponse != null) {
          debugPrint('Last student attendance status: ${lastResponse.statusCode}');
          debugPrint('Last student attendance body: ${lastResponse.body}');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to load attendance data${lastResponse != null ? ' (${lastResponse.statusCode})' : ''}.',
              ),
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching student attendance data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error while loading attendance data: $e'),
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }
  Future<LocationData?> _getVerifiedLocation() async {
    final location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() {
          isGpsVerified = false;
          gpsStatusText = 'Please turn on location services';
        });
        return null;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }

    if (permissionGranted != PermissionStatus.granted &&
        permissionGranted != PermissionStatus.grantedLimited) {
      setState(() {
        isGpsVerified = false;
        gpsStatusText = 'Location permission is required';
      });
      return null;
    }

    final locationData = await location.getLocation();

    if (locationData.latitude == null || locationData.longitude == null) {
      setState(() {
        isGpsVerified = false;
        gpsStatusText = 'Unable to read GPS location';
      });
      return null;
    }

    setState(() {
      isGpsVerified = true;
      gpsStatusText = 'Location verified successfully';
    });

    return locationData;
  }

  Future<void> submitAttendance() async {
    final enteredCode = codeController.text.trim().toUpperCase();

    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the attendance code')),
      );
      return;
    }

    final studentId = sessionStudentId ?? widget.studentId;

    setState(() {
      isSubmitting = true;
    });

    try {
      final locationData = await _getVerifiedLocation();
      if (locationData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(gpsStatusText)),
        );
        return;
      }

      final response = await http.post(
        //Uri.parse('http://127.0.0.1:8000/api/attendance/submit'),
        Uri.parse('http://10.0.2.2:8000/api/attendance/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'subject_id': widget.subjectId,
          'attendance_type': _normalizedAttendanceType,
          'code': enteredCode,
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
        }),
      );

      debugPrint('SUBMIT ATTENDANCE status => ${response.statusCode}');
      debugPrint('SUBMIT ATTENDANCE body => ${response.body}');

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          data = {
            'message': response.statusCode >= 500
                ? 'Server error while submitting attendance.'
                : 'Unexpected server response while submitting attendance.',
          };
        }
      }

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Attendance submitted')),
        );
        codeController.clear();
        fetchAttendanceData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Failed to submit attendance',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('SUBMIT ATTENDANCE error => $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
  data: Theme.of(context).copyWith(
    textTheme: Theme.of(context).textTheme.apply(
      fontFamily: 'Nunito',
    ),
  ),
  child: Scaffold(
    backgroundColor: const Color(0xFFF3F1F2),
    body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
  decoration: const BoxDecoration(
    color: Color(0xFF67C5C4),
  ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${widget.subjectCode} ${widget.subjectName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.account_circle,
                                    size: 96,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$matricNumber - $programme',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  attendanceRate,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  'Attendance Rate',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$classesAttend/$totalClasses',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  'Classes Attend',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  count: '$presentCount',
                                  label: 'Present',
                                  numberColor: const Color(0xFF59C26A),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  count: '$lateCount',
                                  label: 'Late',
                                  numberColor: const Color(0xFFE0A92F),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  count: '$absentCount',
                                  label: 'Absent',
                                  numberColor: const Color(0xFFE35B4F),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Submit Attendance Code',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  currentSessionTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currentSessionDate,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currentSessionTime,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  height: 74,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF98A3B7),
                                      width: 2,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: codeController,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    textCapitalization: TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      letterSpacing: 1,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '------',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isGpsVerified
                                        ? const Color(0xFFBFE8CC)
                                        : const Color(0xFFFFE9C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isGpsVerified ? Icons.location_on : Icons.location_off,
                                        size: 16,
                                        color: isGpsVerified
                                            ? const Color(0xFF59B97A)
                                            : const Color(0xFFE0A92F),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          gpsStatusText,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: 210,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: isSubmitting ? null : submitAttendance,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF49C1C4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle_outline,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Submit Attendance',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Recent Records',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF4F6FA),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'SESSION',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6F7A8C),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'DATE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6F7A8C),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'TIME',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6F7A8C),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'STATUS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6F7A8C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (recentRecords.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Text(
                                      'No attendance records yet.',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  )
                                else
                                  ...List.generate(recentRecords.length, (index) {
                                    final item = recentRecords[index];
                                    final status = item['status'] ?? '';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: index == 0
                                                ? const Color(0xFF3C3C3C)
                                                : const Color(0xFFE9EDF4),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item['session'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item['date'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['time'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 9,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _statusBackgroundColor(status),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: _statusTextColor(status),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
  ),
    );
    
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF5ECF84);
      case 'Late':
        return const Color(0xFFE0A92F);
      case 'Absent':
        return const Color(0xFFF06A6A);
      default:
        return Colors.black54;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFFE6F8EC);
      case 'Late':
        return const Color(0xFFFFF3D8);
      case 'Absent':
        return const Color(0xFFFFE6E6);
      default:
        return const Color(0xFFF3F3F3);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String count;
  final String label;
  final Color numberColor;

  const _StatCard({
    required this.count,
    required this.label,
    required this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  }
