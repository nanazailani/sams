import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentHistoryPage extends StatefulWidget {
  final int studentId;

  const PaymentHistoryPage({
    super.key,
    required this.studentId,
  });

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchPaymentHistory();
  }

  Future<void> fetchPaymentHistory() async {
    try {
      final response = await http.get(
        Uri.parse(
          //'http://127.0.0.1:8000/api/tuition/student/${widget.studentId}/history',
          'http://10.0.2.2:8000/api/tuition/student/${widget.studentId}/history',
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
          error = 'Failed to load payment history: ${response.body}';
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF00C853);
      case 'rejected':
        return const Color(0xFFE53935);
      case 'pending':
      default:
        return const Color(0xFFF39C12);
    }
  }

  Color getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFE6F7EE);
      case 'rejected':
        return const Color(0xFFFFE5E0);
      case 'pending':
      default:
        return const Color(0xFFF8E8A5);
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
          title: const Text('Payment History'),
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

    final semester = data?['semester']?.toString() ?? '-';
    final summary = data?['summary'] as Map<String, dynamic>? ?? {};
    final payments = (data?['payments'] as List?) ?? [];

    final totalPaid = summary['total_paid'] ?? 0;
    final outstanding = summary['outstanding'] ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchPaymentHistory,
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
                        'Payment History',
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
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _SemesterChip(text: semester),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          value: 'RM ${formatMoney(totalPaid)}',
                          label: 'Total Paid',
                          valueColor: greenText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InfoCard(
                          value: 'RM ${formatMoney(outstanding)}',
                          label: 'Outstanding',
                          valueColor: redText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: payments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('No payment history found.'),
                            ),
                          )
                        : Column(
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'DATE',
                                      style: TextStyle(
                                        color: Color(0xFF566276),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'AMOUNT',
                                      style: TextStyle(
                                        color: Color(0xFF566276),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'METHOD',
                                      style: TextStyle(
                                        color: Color(0xFF566276),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'STATUS',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Color(0xFF566276),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              ...List.generate(payments.length, (index) {
                                final item =
                                    payments[index] as Map<String, dynamic>;
                                final status =
                                    item['status']?.toString() ?? 'Pending';

                                return Column(
                                  children: [
                                    _HistoryRow(
                                      date: item['date']?.toString() ?? '-',
                                      amount:
                                          'RM ${formatMoney(item['amount'] ?? 0)}',
                                      method: item['method']?.toString() ?? '-',
                                      status: status.toUpperCase(),
                                      statusColor: getStatusColor(status),
                                      statusBg: getStatusBg(status),
                                    ),
                                    if (index != payments.length - 1)
                                      const Divider(height: 20),
                                  ],
                                );
                              }),
                            ],
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

class _SemesterChip extends StatelessWidget {
  final String text;

  const _SemesterChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F6F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF40C4C4),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _InfoCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB7C0CC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String date;
  final String amount;
  final String method;
  final String status;
  final Color statusColor;
  final Color statusBg;

  const _HistoryRow({
    required this.date,
    required this.amount,
    required this.method,
    required this.status,
    required this.statusColor,
    required this.statusBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(date, style: const TextStyle(fontSize: 15))),
        Expanded(child: Text(amount, style: const TextStyle(fontSize: 15))),
        Expanded(child: Text(method, style: const TextStyle(fontSize: 15))),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}