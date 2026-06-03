import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'module_model.dart';

class AvailableClassesPage extends StatefulWidget {
  final ModuleModel module;
  final int studentId;

  const AvailableClassesPage({
    super.key,
    required this.module,
    required this.studentId,
  });

  @override
  State<AvailableClassesPage> createState() => _AvailableClassesPageState();
}

class _AvailableClassesPageState extends State<AvailableClassesPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _schedules = [];

  int? _resolvedStudentId;


  @override
  void initState() {
    super.initState();

    _initPage();
  }

  Future<void> _initPage() async {
    await _loadStudentIdAndFetchSchedules();
  }

  Future<void> _loadStudentIdAndFetchSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');

    if (!mounted) return;
    setState(() {
      _resolvedStudentId = savedStudentId ?? widget.studentId;
    });

    await fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/modules/${widget.module.id}/schedules'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (!mounted) return;
        setState(() {
          _schedules = decoded['data'] ?? [];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load available classes';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> bookSchedule(int scheduleId) async {
    final studentId = _resolvedStudentId ?? widget.studentId;
    try {
      if (studentId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student ID not found. Please login again.')),
        );
        return;
      }

      final response = await http.post(
        //Uri.parse('http://127.0.0.1:8000/api/modules/book'),
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/modules/book'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'module_id': widget.module.id,
          'module_schedule_id': scheduleId,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Booking failed'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  String formatDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;

    final year = parts[0];
    final month = parts[1];
    final day = parts[2];

    const months = {
      '01': 'Jan',
      '02': 'Feb',
      '03': 'Mar',
      '04': 'Apr',
      '05': 'May',
      '06': 'Jun',
      '07': 'Jul',
      '08': 'Aug',
      '09': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Dec',
    };

    return '$day ${months[month]} $year';
  }

  String formatTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '$hour:$minute $suffix';
  }

  Widget _emptyAvailableClassesNote() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: Colors.black38,
              size: 42,
            ),
            SizedBox(height: 10),
            Text(
              'No available classes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'There are no upcoming available classes for this module at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF43C7C7);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  // bottomLeft: Radius.circular(18),
                  // bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Available Classes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : _schedules.isEmpty
                          ? _emptyAvailableClassesNote()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _schedules.length,
                          itemBuilder: (context, index) {
                            final item = _schedules[index];

                            final bool isFull =
                                item['status'] == 'full' ||
                                ((item['booked_count'] ?? 0) >= (item['capacity'] ?? 0));
                            final bool studentMissing = (_resolvedStudentId ?? widget.studentId) <= 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${widget.module.code} ${widget.module.name}'.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${formatDate(item['date'])}   ${formatTime(item['start_time'])} - ${formatTime(item['end_time'])}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📍 ${item['venue']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          '👤 ${item['lecturer']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: isFull || studentMissing
                                        ? null
                                        : () {
                                            bookSchedule(item['id']);
                                          },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? Colors.grey
                                            : (studentMissing ? Colors.grey : primaryColor),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        studentMissing
                                            ? 'Student session not found'
                                            : (isFull ? 'Full Capacity' : 'Book Now'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
