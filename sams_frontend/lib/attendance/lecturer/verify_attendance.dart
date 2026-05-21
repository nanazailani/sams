


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerifyAttendancePage extends StatefulWidget {
  final int classSessionId;
  final String subjectCode;
  final String subjectName;
  final String classDate;
  final String startTime;
  final String endTime;
  final String attendanceType;

  const VerifyAttendancePage({
    super.key,
    required this.classSessionId,
    required this.subjectCode,
    required this.subjectName,
    required this.classDate,
    required this.startTime,
    required this.endTime,
    required this.attendanceType,
  });

  @override
  State<VerifyAttendancePage> createState() => _VerifyAttendancePageState();
}

class _VerifyAttendancePageState extends State<VerifyAttendancePage> {
  List<Map<String, String>> submissions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSubmissions();
  }

  Future<void> fetchSubmissions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              //'http://127.0.0.1:8000/api/attendance/${widget.classSessionId}/submissions',
              'http://10.0.2.2:8000/api/attendance/${widget.classSessionId}/submissions',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          submissions = data
              .map<Map<String, String>>(
                (item) => {
                  'id': item['id']?.toString() ?? '',
                  'name': item['name']?.toString() ?? '-',
                  'matric': item['matric']?.toString() ?? '-',
                  'time': item['time']?.toString() ?? '-',
                  'status': item['status']?.toString() ?? '-',
                  'verification_status': item['verification_status']?.toString() ?? 'Pending',
                  'location_name': item['location_name']?.toString() ?? '-',
                },
              )
              .toList();
        });
      }
    } catch (_) {
      //
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> updateAttendanceStatus(String attendanceId, String status) async {
    try {
      final response = await http.post(
        //Uri.parse('http://127.0.0.1:8000/api/attendance/$attendanceId/status'),
        Uri.parse('http://10.0.2.2:8000/api/attendance/$attendanceId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        // Update the local submissions list immediately
        setState(() {
          final index = submissions.indexWhere((item) => item['id'] == attendanceId);
          if (index != -1) {
            submissions[index]['verification_status'] = status;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance $status successfully.'),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      //
    }
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

  String _formatClassDate(String value) {
    if (value.isEmpty) return '-';
    try {
      final date = DateTime.parse(value);
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
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
                color: const Color(0xFF2E4E96),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Verify Attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchSubmissions,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${widget.subjectCode} ${widget.subjectName}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatClassDate(widget.classDate),
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatTime(widget.startTime)} - ${_formatTime(widget.endTime)}',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Submitted Students',
                        style: TextStyle(
                          fontSize: 16,
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
                                    flex: 2,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Text(
                                        'MATRIC NO',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Text(
                                        'LOCATION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        'STATUS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: Text(
                                        'ACTION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF6F7A8C),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoading)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
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
                                final status = verificationStatus == 'Rejected'
                                    ? 'Absent'
                                    : originalStatus;
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
                                        flex: 2,
                                        child: Text(
                                          item['matric'] ?? '',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          item['location_name'] ?? 'Faculty Location',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                                                          Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusBackgroundColor(status),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _statusTextColor(status),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: verificationStatus == 'Pending'
                                            ? Column(
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: const Text('Confirm Approval'),
                                                            content: const Text('Are you sure you want to approve this attendance?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(false),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(true),
                                                                child: const Text('Approve'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          final id = item['id'] ?? '';
                                                          if (id.isNotEmpty) {
                                                            updateAttendanceStatus(id, 'Approved');
                                                          }
                                                        }
                                                      },
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: Container(
                                                        margin: const EdgeInsets.only(bottom: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF4CAF50),
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                        child: const Text(
                                                          'Approve',
                                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: const Text('Confirm Rejection'),
                                                            content: const Text('Are you sure you want to reject this attendance?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(false),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(true),
                                                                child: const Text('Reject'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          final id = item['id'] ?? '';
                                                          if (id.isNotEmpty) {
                                                            updateAttendanceStatus(id, 'Rejected');
                                                          }
                                                        }
                                                      },
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE74C3C),
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                        child: const Text(
                                                          'Reject',
                                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: verificationStatus == 'Approved'
                                                        ? const Color(0xFFE6F8EC)
                                                        : const Color(0xFFFFE6E6),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    verificationStatus,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: verificationStatus == 'Approved'
                                                          ? const Color(0xFF2E7D32)
                                                          : const Color(0xFFC62828),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      )
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
}
