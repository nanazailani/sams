import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'module_model.dart';

class AvailableClassesPage extends StatefulWidget {
  final ModuleModel module;

  const AvailableClassesPage({
    super.key,
    required this.module,
  });

  @override
  State<AvailableClassesPage> createState() => _AvailableClassesPageState();
}

class _AvailableClassesPageState extends State<AvailableClassesPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _schedules = [];

  int? _studentId;

  int? _resolvedStudentId;


  @override
  void initState() {
    super.initState();

    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getInt('student_id');
    _loadStudentIdAndFetchSchedules();
  }

  Future<void> _loadStudentIdAndFetchSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');

    setState(() {
      _resolvedStudentId = savedStudentId ;
    });


    await fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/modules/${widget.module.id}/schedules'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          _schedules = decoded['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load available classes';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> bookSchedule(int scheduleId) async {
    final studentId = _resolvedStudentId ;
    try {
      if (_studentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student ID not found. Please login again.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/modules/book'),
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _schedules.length,
                          itemBuilder: (context, index) {
                            final item = _schedules[index];

                            final bool isFull =
                                item['status'] == 'full' ||
                                ((item['booked_count'] ?? 0) >= (item['capacity'] ?? 0));
                            final bool studentMissing = _resolvedStudentId == null || _resolvedStudentId! <= 0;

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

                                        // color: isFull ? Colors.grey : primaryColor,

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