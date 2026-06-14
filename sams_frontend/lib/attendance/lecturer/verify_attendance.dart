import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerifyAttendancePage extends StatefulWidget {
  // Data sesi yang dipassing dari AttendancePage
  final int classSessionId;
  final String subjectCode;
  final String subjectName;
  final String classDate;
  final String startTime;
  final String endTime;
  final String attendanceType; // 'course' atau 'module'

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
  List<Map<String, String>> submissions = []; // Senarai submission pelajar
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSubmissions();
  }

  /// Fetch senarai submission kehadiran untuk sesi ni.
  /// Dipanggil semula bila user pull-to-refresh.
  Future<void> fetchSubmissions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              // URL production — guna ?type= untuk distinguish course vs module
              'https://darkgrey-lyrebird-505549.hostingersite.com/api/attendance/${widget.classSessionId}/submissions?type=${widget.attendanceType}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          // Map response ke format seragam, termasuk location dan verification_status
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
      // Silent fail — list akan kekal kosong, user boleh pull-to-refresh
    } finally {
      // Matikan loading walaupun ada error
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Hantar request ke API untuk approve atau reject submission kehadiran.
  /// Selepas berjaya, update local list terus tanpa fetch semula (optimistic update).
  Future<void> updateAttendanceStatus(String attendanceId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/attendance/$attendanceId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,                          // 'Approved' atau 'Rejected'
          'attendance_type': widget.attendanceType,  // Untuk API tahu table mana nak update
        }),
      );

      if (response.statusCode == 200) {
        // Optimistic update — tukar status dalam local list tanpa fetch semula dari API
        setState(() {
          final index = submissions.indexWhere((item) => item['id'] == attendanceId);
          if (index != -1) {
            submissions[index]['verification_status'] = status;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attendance $status successfully.'),
              // Hijau untuk Approved, merah untuk Rejected
              backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update attendance status.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Return warna text untuk badge status attendance
  Color _statusTextColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF5ECF84);
      case 'Late':
        return const Color(0xFFE0A92F);
      case 'Absent':
        return const Color(0xFFF06A6A);
      case 'Pending':
        return const Color(0xFF6F7A8C);
      default:
        return Colors.black54;
    }
  }

  /// Return warna background untuk badge status attendance
  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFFE6F8EC);
      case 'Late':
        return const Color(0xFFFFF3D8);
      case 'Absent':
        return const Color(0xFFFFE6E6);
      case 'Pending':
        return const Color(0xFFF3F3F3);
      default:
        return const Color(0xFFF3F3F3);
    }
  }

  /// Format tarikh dari "2026-06-14" ke "Saturday, 14 June 2026"
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
      return value; // Fallback kalau parse gagal
    }
  }

  /// Format masa dari "08:00:00" ke "8:00 am" (12-jam format)
  String _formatTime(String value) {
    if (value.isEmpty) return '-';
    try {
      final parts = value.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? parts[1] : '00';
      final suffix = hour >= 12 ? 'pm' : 'am';
      hour = hour % 12;
      if (hour == 0) hour = 12; // 0:00 → 12:00 am
      return '$hour:$minute $suffix';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Override font family ke Nunito untuk page ni
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F1F2),
        body: SafeArea(
          child: Column(
            children: [
              // Custom app bar berwarna biru SAMS
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
                  // Pull-to-refresh trigger fetchSubmissions semula
                  onRefresh: fetchSubmissions,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      // ── Card info sesi kelas ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            // Nama dan kod subjek
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
                            // Tarikh kelas dalam format panjang
                            Text(
                              _formatClassDate(widget.classDate),
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            // Masa mula - masa tamat
                            Text(
                              '${_formatTime(widget.startTime)} - ${_formatTime(widget.endTime)}',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Table submission pelajar ──
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
                            // Header row table
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

                            // State: loading, kosong, atau populate rows
                            if (isLoading)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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

                                // Map verification status ke display status:
                                // Rejected → Absent, Pending → Pending, Approved → guna status asal
                                final status = verificationStatus == 'Rejected'
                                    ? 'Absent'
                                    : (verificationStatus == 'Pending'
                                        ? 'Pending'
                                        : originalStatus);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      // Row pertama takde top border — elak double border dengan header
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
                                      // Nombor matric pelajar
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['matric'] ?? '',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                      // Nama lokasi dari GPS reverse geocoding
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          item['location_name'] ?? 'Faculty Location',
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                      // Badge status berwarna
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
                                      // Kolum action — Approve/Reject kalau Pending,
                                      // badge hijau/merah kalau dah diverify
                                      Expanded(
                                        flex: 3,
                                        child: verificationStatus == 'Pending'
                                            // Tunjuk butang Approve & Reject untuk submission Pending
                                            ? Column(
                                                children: [
                                                  // Butang Approve — ada confirmation dialog
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        // Tunjuk dialog konfirmasi sebelum approve
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
                                                        // Proceed hanya kalau user confirm
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
                                                          color: const Color(0xFF4CAF50), // Hijau
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                        child: const Text(
                                                          'Approve',
                                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Butang Reject — ada confirmation dialog
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        // Tunjuk dialog konfirmasi sebelum reject
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
                                                        // Proceed hanya kalau user confirm
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
                                                          color: const Color(0xFFE74C3C), // Merah
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
                                            // Dah diverify — tunjuk badge status sahaja (Approved/Rejected)
                                            : Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    // Hijau untuk Approved, merah untuk Rejected
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
                                                          ? const Color(0xFF2E7D32) // Hijau gelap
                                                          : const Color(0xFFC62828), // Merah gelap
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
}
