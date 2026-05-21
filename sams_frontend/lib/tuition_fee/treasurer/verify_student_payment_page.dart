import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VerifyStudentPaymentPage extends StatefulWidget {
  final int paymentId;

  const VerifyStudentPaymentPage({
    super.key,
    required this.paymentId,
  });

  @override
  State<VerifyStudentPaymentPage> createState() => _VerifyStudentPaymentPageState();
}

class _VerifyStudentPaymentPageState extends State<VerifyStudentPaymentPage> {
  Map<String, dynamic>? payment;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    fetchPaymentDetail();
  }

  Future<void> fetchPaymentDetail() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          //'http://127.0.0.1:8000/api/tuition/treasurer/payment/${widget.paymentId}',
          'http://10.0.2.2:8000/api/tuition/treasurer/payment/${widget.paymentId}',
        ),
        headers: {'Accept': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          payment = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Failed to load payment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Color statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFE8F8EE);
      case 'rejected':
        return const Color(0xFFFFE6E6);
      default:
        return const Color(0xFFFFF2CC);
    }
  }

  Color statusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2EAD67);
      case 'rejected':
        return const Color(0xFFE85B5B);
      default:
        return const Color(0xFFF4B400);
    }
  }

  Future<void> approvePayment() async {
    setState(() {
      isProcessing = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          //'http://127.0.0.1:8000/api/tuition/treasurer/payment/${widget.paymentId}/approve',
          'http://10.0.2.2:8000/api/tuition/treasurer/payment/${widget.paymentId}/approve',
        ),
        headers: {'Accept': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Approved')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Approve failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      isProcessing = false;
    });
  }

  Future<void> rejectPayment() async {
    final controller = TextEditingController();

    final remarks = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Reject Payment'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter remarks (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (remarks == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          //'http://127.0.0.1:8000/api/tuition/treasurer/payment/${widget.paymentId}/reject',
          'http://10.0.2.2:8000/api/tuition/treasurer/payment/${widget.paymentId}/reject',
        ),
        headers: {'Accept': 'application/json'},
        body: {
          'remarks': remarks,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Rejected')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Reject failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      isProcessing = false;
    });
  }

  void showReceipt() {
    final receiptUrl = payment?['receipt_url']?.toString();

    if (receiptUrl == null || receiptUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No uploaded receipt found')),
      );
      return;
    }

    final lower = receiptUrl.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Uploaded Receipt'),
        content: isImage
            ? Image.network(
                receiptUrl,
                errorBuilder: (_, __, ___) => SelectableText(receiptUrl),
              )
            : SelectableText(receiptUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF22B8CF);
    const bgColor = Color(0xFFF5F5F5);

    final currentStatus = payment?['status']?.toString() ?? 'Pending';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Verify Student Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E2E2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Student Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _infoRow('Student ID', payment?['matric_no']?.toString() ?? '-'),
                                _infoRow('Full Name', payment?['full_name']?.toString() ?? '-'),
                                _infoRow('Course', payment?['programme']?.toString() ?? '-'),
                                _infoRow('Semester', payment?['semester']?.toString() ?? '-'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E2E2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _infoRow(
                                  'Amount',
                                  'RM ${(payment?['amount'] ?? 0).toString()}',
                                  valueColor: primaryColor,
                                ),
                                _infoRow('Method', payment?['payment_method']?.toString() ?? '-'),
                                _infoRow('Date Submitted', payment?['date_submitted']?.toString() ?? '-'),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Current Status',
                                        style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: statusBg(currentStatus),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        currentStatus.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: statusText(currentStatus),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: showReceipt,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: primaryColor, width: 1.8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.folder, color: Color(0xFFF4B400)),
                                    label: const Text(
                                      'View Uploaded Receipt',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (isProcessing || currentStatus != 'Pending')
                                      ? null
                                      : approvePayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: const Text(
                                    '✓ Approve',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (isProcessing || currentStatus != 'Pending')
                                      ? null
                                      : rejectPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF44336),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: const Text(
                                    '✕ Reject',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
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
      ),
    );
  }
}