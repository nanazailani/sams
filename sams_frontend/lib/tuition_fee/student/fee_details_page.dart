import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'upload_payment_proof_page.dart';

class FeeDetailsPage extends StatefulWidget {
  final int studentId;

  const FeeDetailsPage({
    super.key,
    required this.studentId,
  });

  @override
  State<FeeDetailsPage> createState() => _FeeDetailsPageState();
}

class _FeeDetailsPageState extends State<FeeDetailsPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchFeeDetails();
  }

  Future<void> fetchFeeDetails() async {
    try {
      final response = await http.get(
        Uri.parse(
          //'http://127.0.0.1:8000/api/tuition/student/${widget.studentId}/details',
          'http://10.0.2.2:8000/api/tuition/student/${widget.studentId}/details',
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
          error = 'Failed to load fee details: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Unable to connect to server: $e';
        isLoading = false;
      });
    }
  }

  String formatMoney(dynamic value) {
    final number =
        (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    return number.toStringAsFixed(2);
  }

  Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFFE8F5E9);
      case 'partial':
        return const Color(0xFFF8E8A5);
      case 'unpaid':
      default:
        return const Color(0xFFFFE5E0);
    }
  }

  Color getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF00C853);
      case 'partial':
        return const Color(0xFFF39C12);
      case 'unpaid':
      default:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF40C4C4);
    const Color bgColor = Color(0xFFF3F3F3);
    const Color borderColor = Color(0xFFB7C0CC);
    const Color greenText = Color(0xFF00C853);
    const Color redText = Color(0xFFE53935);

    if (isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Fee Details'),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    final studentName = data?['student_name']?.toString() ?? '-';
    final matricNo = data?['matric_no']?.toString() ?? '-';
    final programme = data?['programme']?.toString() ?? '-';
    final semester = data?['semester']?.toString() ?? '-';
    final session = data?['session']?.toString() ?? '-';
    final tuitionFee = data?['tuition_fee'] ?? 0;
    final hostelFee = data?['hostel_fee'] ?? 0;
    final totalFee = data?['total_fee'] ?? 0;
    final paid = data?['paid'] ?? 0;
    final outstanding = data?['outstanding'] ?? 0;
    final completion = ((data?['completion_percentage'] ?? 0) as num).toDouble();
    final status = data?['status']?.toString() ?? 'Unpaid';
    final deadline = data?['deadline']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchFeeDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 92,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: primaryColor,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Fee Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 58),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '$matricNo · $studentName\n$semester, $session\n$programme',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Fee Breakdown',
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'FEE TYPE',
                                style: TextStyle(
                                  color: Color(0xFF566276),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                color: Color(0xFF566276),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _BreakdownRow(
                          label: 'Tuition Fee',
                          value: 'RM ${formatMoney(tuitionFee)}',
                        ),
                        const Divider(height: 18),
                        _BreakdownRow(
                          label: 'Hostel Fee',
                          value: 'RM ${formatMoney(hostelFee)}',
                        ),
                        const Divider(height: 18),
                        _BreakdownRow(
                          label: 'Total',
                          value: 'RM ${formatMoney(totalFee)}',
                          labelColor: primaryColor,
                          valueColor: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Payment Status',
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Status',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: getStatusBgColor(status),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: getStatusTextColor(status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _BreakdownRow(
                          label: 'Paid',
                          value: 'RM ${formatMoney(paid)}',
                          valueColor: greenText,
                        ),
                        const Divider(height: 24),
                        _BreakdownRow(
                          label: 'Outstanding',
                          value: 'RM ${formatMoney(outstanding)}',
                          valueColor: redText,
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Completion',
                                style: TextStyle(
                                  color: Color(0xFF677285),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '${completion.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF677285),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: completion / 100,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFE5E5E5),
                            valueColor:
                                const AlwaysStoppedAnimation(primaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Deadline: $deadline',
                            style: const TextStyle(
                              color: Color(0xFF677285),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                              pageTitle: 'Upload Payment Proof',
                              studentId: widget.studentId,
                            ),
                          ),
                        ).then((_) => fetchFeeDetails());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.payment, color: Colors.white),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.labelColor = Colors.black,
    this.valueColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: labelColor,
              fontWeight: label == 'Total' ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}