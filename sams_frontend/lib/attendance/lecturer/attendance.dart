import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'verify_attendance.dart';
import 'view_attendance.dart';

class AttendancePage extends StatefulWidget {
  final int classSessionId;
  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final String classDate;
  final String startTime;
  final String endTime;
  final String attendanceType;

  const AttendancePage({
    super.key,
    required this.classSessionId,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.classDate,
    required this.startTime,
    required this.endTime,
    required this.attendanceType,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String attendanceCode = '';
  bool isGenerating = false;
  String expiryText = 'Expires at class end';

  String _formatClassDate(String value) {
    if (value.isEmpty) return '-';
    try {
      final date = DateTime.parse(value);
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ];
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return value;
    }
  }

  String _formatTime(String value) {
    if (value.isEmpty) return '-';
    try {
      final parts = value.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? parts[1] : '00';
      final suffix = hour >= 12 ? 'pm' : 'am';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $suffix';
    } catch (_) {
      return value;
    }
  }

  String _formatExpiry(String value) {
    if (value.isEmpty) return 'Expires at class end';
    try {
      final date = DateTime.parse(value).toLocal();
      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'pm' : 'am';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return 'Expires at $hour:$minute $suffix';
    } catch (_) {
      return 'Expires at class end';
    }
  }

  List<Map<String, String>> submissions = [];
  bool isLoadingSubmissions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchSubmissions();
    });
  }

  Future<void> fetchSubmissions() async {
    setState(() {
      isLoadingSubmissions = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://darkgrey-lyrebird-505549.hostingersite.com/api/attendance/${widget.classSessionId}/submissions?type=${widget.attendanceType}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          submissions = data
              .map<Map<String, String>>((item) => {
                    'name': item['name']?.toString() ?? '-',
                    'matric': item['matric']?.toString() ?? '-',
                    'time': item['time']?.toString() ?? '-',
                    'status': item['status']?.toString() ?? 'Pending',
                    'verification_status': item['verification_status']?.toString() ?? 'Pending',
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('FETCH SUBMISSIONS error => $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSubmissions = false;
        });
      }
    }
  }

  Future<void> _generateCode() async {
    setState(() {
      isGenerating = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/attendance/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (widget.attendanceType == 'module')
                'module_session_id': widget.classSessionId
              else
                'class_session_id': widget.classSessionId,
              'attendance_type': widget.attendanceType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>
          : {};

      if (response.statusCode == 200) {
        setState(() {
          attendanceCode = data['attendance_code']?.toString() ?? '';
          expiryText = data['expires_at'] != null
              ? _formatExpiry(data['expires_at'].toString())
              : 'Expires at class end';
        });
        fetchSubmissions();
      } else {
        final message = data['message']?.toString() ?? 'Failed to generate code.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to connect to server: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  void _showQrCodeDialog() {
    if (attendanceCode.isEmpty) return;

    final deepLink =
        'attendease://attendance?code=$attendanceCode'
        '&subject_id=${widget.subjectId}'
        '&type=${widget.attendanceType}';

    debugPrint('QR deep link => $deepLink');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE1EA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Scan to Submit Attendance',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.subjectCode} ${widget.subjectName}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: deepLink,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF2E4E96),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF2E4E96),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF2E4E96)),
                    const SizedBox(width: 8),
                    Text(
                      attendanceCode,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: Color(0xFF2E4E96),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.black38),
                  const SizedBox(width: 5),
                  Text(
                    expiryText,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4E96),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      case 'Pending':
        return const Color(0xFF8A92A3);
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
      case 'Pending':
        return const Color(0xFFF1F3F7);
      default:
        return const Color(0xFFF3F3F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F1F2),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                decoration: const BoxDecoration(color: Color(0xFF2E4E96)),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Attendance',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Class',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/class_teaching.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${widget.subjectCode} ${widget.subjectName}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatClassDate(widget.classDate),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_formatTime(widget.startTime)} - ${_formatTime(widget.endTime)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: 170,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: isGenerating ? null : _generateCode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E4E96),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                      ),
                                      child: isGenerating
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Generate Attendance Code',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Active Attendance Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      attendanceCode.isEmpty ? '------' : attendanceCode,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  children: [
                                    SizedBox(
                                      width: 118,
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: attendanceCode.isEmpty || isGenerating ? null : _generateCode,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E4E96),
                                          disabledBackgroundColor: const Color(0xFFBFC8DD),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(22),
                                          ),
                                        ),
                                        child: const Text(
                                          'Regenerate',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 118,
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: attendanceCode.isEmpty ? null : _showQrCodeDialog,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E4E96),
                                          disabledBackgroundColor: const Color(0xFFBFC8DD),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(22),
                                          ),
                                        ),
                                        child: const Text(
                                          'Share',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  expiryText,
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              // ✅ FIX 1: await navigation then refresh
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VerifyAttendancePage(
                                      classSessionId: widget.classSessionId,
                                      subjectCode: widget.subjectCode,
                                      subjectName: widget.subjectName,
                                      classDate: widget.classDate,
                                      startTime: widget.startTime,
                                      endTime: widget.endTime,
                                      attendanceType: widget.attendanceType,
                                    ),
                                  ),
                                );
                                fetchSubmissions(); // ← runs after returning
                              },
                              child: _buildFeatureCard(
                                icon: Icons.verified_user_outlined,
                                label: 'Verify Attendance',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: GestureDetector(
                              // ✅ FIX 3: await navigation then refresh (sync with View Record History edits/deletes)
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewAttendancePage(
                                      classSessionId: widget.classSessionId.toString(),
                                      subjectName: '${widget.subjectCode} ${widget.subjectName}',
                                      sessionLabel:
                                          '${widget.attendanceType == 'module' ? 'Module' : 'Lecture'} Session - ${_formatClassDate(widget.classDate)}',
                                      timeRange:
                                          '${_formatTime(widget.startTime)} - ${_formatTime(widget.endTime)}',
                                      attendanceType: widget.attendanceType,
                                    ),
                                  ),
                                );
                                fetchSubmissions(); // ← runs after returning
                              },
                              child: _buildFeatureCard(
                                icon: Icons.assignment_outlined,
                                label: 'View Record History',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Current Class Submission',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.filter_alt_outlined, color: Colors.black87),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                    flex: 4,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Text(
                                        'Name',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 2),
                                      child: Text(
                                        'Matric No.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 2),
                                      child: Text(
                                        'Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoadingSubmissions)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              )
                            else if (submissions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'No attendance submissions yet.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            else
                              ...List.generate(submissions.length, (index) {
                                final item = submissions[index];
                                final originalStatus = item['status'] ?? '';
                                final verificationStatus = item['verification_status'] ?? 'Pending';
                                final verificationStatusNorm = verificationStatus.toLowerCase();
                                // ✅ FIX 2: approved → original status (Present/Late), rejected → Absent, pending → Pending
                                final status = verificationStatusNorm == 'rejected'
                                    ? 'Absent'
                                    : (verificationStatusNorm == 'approved'
                                        ? originalStatus
                                        : (verificationStatusNorm == 'pending'
                                            ? 'Pending'
                                            : originalStatus));
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: index == 0
                                            ? Colors.transparent
                                            : const Color(0xFFE9EDF4),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Text(
                                            item['name'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11.5, color: Colors.black87),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['matric'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 11.5, color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['time'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 11.5, color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _statusBackgroundColor(status),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}