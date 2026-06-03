import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'credit_claim_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyBookingPage extends StatefulWidget {
  const MyBookingPage({super.key});

  @override
  State<MyBookingPage> createState() => _MyBookingPageState();
}

class _MyBookingPageState extends State<MyBookingPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  int? _studentId;
  List<dynamic> _bookings = [];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getInt('student_id');
    await fetchMyBookings();
  }

  Future<void> fetchMyBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_studentId == null) {
        setState(() {
          _errorMessage = 'Student ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/modules/my-bookings?student_id=$_studentId',
        ),
      );

      //  final response = await http.get(
      //   Uri.parse(
      //     'http://10.0.2.2:8000/api/modules/my-bookings?student_id=$_studentId',
      //   ),
      // );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _bookings = decoded['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = decoded['message'] ?? 'Failed to load bookings';
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

  Future<void> cancelBooking(int registrationId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/modules/bookings/$registrationId/cancel',
        ),
        headers: {'Accept': 'application/json'},
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded['message'] ?? 'Booking cancelled successfully',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        fetchMyBookings();
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Unable to cancel booking'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color attendanceColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return const Color(0xFF20BF6B);
      case 'ABSENT':
        return const Color(0xFFFF3B30);
      case 'LATE':
        return const Color(0xFFFF9F43);
      default:
        return Colors.grey;
    }
  }

  IconData attendanceIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Icons.check_circle;
      case 'ABSENT':
        return Icons.cancel;
      case 'LATE':
        return Icons.access_time_filled;
      default:
        return Icons.help;
    }
  }

  String _formatDateTime(String date, String startTime, String endTime) {
    return '$date  •  $startTime - $endTime';
  }

Widget _buildHeader() {
  const primaryColor = Color(0xFF3FC7C4);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: const BoxDecoration(
      color: primaryColor,
      borderRadius: BorderRadius.only(
        // bottomLeft: Radius.circular(22),
        // bottomRight: Radius.circular(22),
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
          'My KoQ Booking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
              // SizedBox(height: 2),
              // Text(
              //   'View your booked modules and attendance',
              //   style: TextStyle(
              //     color: Colors.white70,
              //     fontSize: 12,
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
      );
  }

  Widget _buildSectionHeader() {
    const primaryColor = Color(0xFF3FC7C4);

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booked Modules',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track attendance and manage your active module bookings',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreditClaimPage(),
            ),
          );
          },
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text(
            'Claim Credit',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 74,
              color: Color(0xFFB8B8B8),
            ),
            SizedBox(height: 14),
            Text(
              'No booked modules yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your booked KoQ modules will appear here once you complete a booking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load bookings',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: fetchMyBookings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3FC7C4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bool canCancel = booking['can_cancel'] == true;
    final String attendanceStatus =
        (booking['attendance_status'] ?? '--').toString();
    final String percentage =
        (booking['attendance_percentage'] ?? '--').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '${booking['code']} ${booking['name']}'.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF202020),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Color(0xFFFF5A5F),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking['venue'] ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 15,
                color: Color(0xFF7A7A7A),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDateTime(
                    booking['class_date'] ?? '',
                    booking['start_time'] ?? '',
                    booking['end_time'] ?? '',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InfoBlock(
                    label: 'CATS',
                    value: '${booking['cats'] ?? '-'}',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: attendanceColor(attendanceStatus),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              attendanceIcon(attendanceStatus),
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              attendanceStatus.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _InfoBlock(
                    label: 'Progress',
                    value: percentage,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  canCancel ? () => cancelBooking(booking['registration_id']) : null,
              icon: Icon(
                canCancel ? Icons.close_rounded : Icons.lock_clock_rounded,
                size: 18,
              ),
              label: Text(
                canCancel
                    ? 'Cancel Booking'
                    : 'Cannot cancel on event day',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canCancel ? const Color(0xFFFF4D4F) : const Color(0xFFB8B8B8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _bookings.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: fetchMyBookings,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                children: [
                                  _buildSectionHeader(),
                                  const SizedBox(height: 16),
                                  ..._bookings.map(
                                    (booking) => _buildBookingCard(
                                      booking as Map<String, dynamic>,
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
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _InfoBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF252525),
          ),
        ),
      ],
    );
  }
}