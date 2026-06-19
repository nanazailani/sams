import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'fee_details_page.dart';
import 'payment_history_page.dart';
import 'upload_payment_proof_page.dart';

class FeeDashboardPage extends StatefulWidget {
  const FeeDashboardPage({super.key});

  @override
  State<FeeDashboardPage> createState() => _FeeDashboardPageState();
}

class _FeeDashboardPageState extends State<FeeDashboardPage> {
  // Data yuran yang difetch dari API
  Map<String, dynamic>? data;
  bool isLoading = true;
  String error = '';
  int? studentId;

  @override
  void initState() {
    super.initState();
    // Mula dengan load student ID dari local storage
    loadStudentId();
  }

  // Ambik student ID yang dah save masa login.
  // Kalau takde, suruh login balik.
  Future<void> loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStudentId = prefs.getInt('student_id');

    if (!mounted) return;

    if (savedStudentId == null) {
      setState(() {
        error = 'No student_id found. Please login again.';
        isLoading = false;
      });
      return;
    }

    studentId = savedStudentId;
    // Terus fetch data yuran lepas dapat student ID
    await fetchFee();
  }

  // Fetch status yuran student dari API Hostinger.
  // Guna student ID untuk retrieve current semester info
  Future<void> fetchFee() async {
    try {
      final response = await http.get(
        Uri.parse(
          // Untuk development local, uncomment line bawah:
          //'http://127.0.0.1:8000/api/tuition/student/$studentId/status',
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/tuition/student/$studentId/status',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          data = jsonDecode(response.body);
          isLoading = false;
          error = '';
        });
      } else {
        setState(() {
          error = 'Failed to load fee status: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      // Kemungkinan no internet atau server down
      if (!mounted) return;
      setState(() {
        error = 'Unable to connect to server: $e';
        isLoading = false;
      });
    }
  }

  /// Return warna background badge status — hijau, oren, atau merah.
  Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFFE8F5E9);
      case 'partial':
        return const Color(0xFFFFF3E0);
      case 'unpaid':
      default:
        return const Color(0xFFFFE5E0);
    }
  }

  /// Return warna teks badge status.
  Color getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF2E7D32);
      case 'partial':
        return const Color(0xFFEF6C00);
      case 'unpaid':
      default:
        return const Color(0xFFFF5A4E);
    }
  }

  /// Format angka kepada 2 decimal places untuk display duit
  String formatMoney(dynamic value) {
    final number = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    return number.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF40C4C4);
    const Color bgColor = Color(0xFFF3F3F3);
    const Color borderColor = Color(0xFFB7C0CC);
    const Color greenText = Color(0xFF00C853);
    const Color redText = Color(0xFFE53935);
    const Color noticeBg = Color(0xFFF8EDBE);
    const Color noticeSide = Color(0xFFF39C12);

    // Tunjuk loading spinner sambil tunggu data dari API
    if (isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Kalau ada error, tunjuk mesej ringkas — jangan crash app
    if (error.isNotEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header sama je walaupun error
                Container(
                  height: 92,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                  ),
                  child: const Text(
                    'Tuition Fee Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Current Fee Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Unable to load tuition fee information right now.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Extract semua field dari API response — guna fallback kalau null
    final status = (data?['status'] ?? 'Unpaid').toString();
    final semester = (data?['semester'] ?? '-').toString();
    final totalFee = data?['total_fee'] ?? 0;
    final amountPaid = data?['amount_paid'] ?? 0;
    final remainingBalance = data?['remaining_balance'] ?? 0;
    final deadline = (data?['deadline'] ?? '-').toString();
    final completionPercentage = ((data?['completion_percentage'] ?? 0) as num).toDouble();
    final studentName = (data?['student_name'] ?? '-').toString();
    final matricNo = (data?['matric_no'] ?? '-').toString();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh — student boleh refresh manual kalau nak
          onRefresh: fetchFee,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                //Header
                Container(
                  height: 92,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                  ),
                  child: const Text(
                    'Tuition Fee Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Info Student
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Info',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Name: $studentName'),
                        const SizedBox(height: 6),
                        Text('Student ID: $matricNo'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Status Yuran Semasa
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Current Fee Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama semester di sebelah kiri
                            Expanded(
                              child: Text(
                                semester,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Badge status — Paid / Partial / Unpaid
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: getStatusBgColor(status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: getStatusTextColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Jumlah keseluruhan yuran
                        Text(
                          'RM ${formatMoney(totalFee)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tarikh akhir bayaran
                        Text(
                          'Deadline: $deadline',
                          style: const TextStyle(
                            color: Color(0xFF677285),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Label progress bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Amount Paid',
                              style: TextStyle(
                                color: Color(0xFF677285),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${completionPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF677285),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Progress bar — tunjuk percentage bayaran yang dah dibayar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: completionPercentage / 100,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFE5E5E5),
                            valueColor: const AlwaysStoppedAnimation(primaryColor),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // fee details button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FeeDetailsPage(studentId: studentId!),
                                ),
                              ).then((_) => fetchFee()); // Refresh lepas balik
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'View Fee Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // payment summary
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        // Jumlah yuran penuh (total)
                        _SummaryRow(
                          label: 'Total Tuition Fee',
                          value: 'RM ${formatMoney(totalFee)}',
                          valueColor: Colors.black,
                        ),
                        const Divider(height: 1),
                        // Berapa dah dibayar dan approved
                        _SummaryRow(
                          label: 'Amount Paid',
                          value: 'RM ${formatMoney(amountPaid)}',
                          valueColor: greenText,
                        ),
                        const Divider(height: 1),
                        // Baki yang still perlu dibayar
                        _SummaryRow(
                          label: 'Remaining Balance',
                          value: 'RM ${formatMoney(remainingBalance)}',
                          valueColor: redText,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // upload receipt button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UploadPaymentProofPage(
                              pageTitle: 'Upload Payment Receipt',
                              studentId: studentId!,
                            ),
                          ),
                        ).then((_) => fetchFee()); // Refresh lepas upload
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      label: const Text(
                        'Upload Payment Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // history button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentHistoryPage(studentId: studentId!),
                          ),
                        ).then((_) => fetchFee()); // Refresh lepas balik dari history
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      icon: const Icon(Icons.history, color: primaryColor),
                      label: const Text(
                        'Payment History',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Notification
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Notification',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Reminder kuning — ingatkan student pasal baki and deadline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: noticeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: noticeSide, width: 6),
                      ),
                    ),
                    child: Text(
                      'Reminder: Your remaining balance is RM ${formatMoney(remainingBalance)}. Please complete payment before the deadline ($deadline) to avoid academic restriction.',
                      style: const TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget helper untuk satu baris dalam Payment Summary.
/// Tunjuk label kat kiri dan nilai berwarna kat kanan.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
