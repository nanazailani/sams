import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentRecordsPage extends StatefulWidget {
  const PaymentRecordsPage({super.key});

  @override
  State<PaymentRecordsPage> createState() => _PaymentRecordsPageState();
}

class _PaymentRecordsPageState extends State<PaymentRecordsPage> {
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  String selectedStatus = 'All';

  int totalRecords = 0;
  double totalCollected = 0;
  int approvedCount = 0;
  int rejectedCount = 0;

  List records = [];
  int currentPage = 1;
  int lastPage = 1;

  @override
  void initState() {
    super.initState();
    fetchRecords();
  }

  Future<void> fetchRecords({int page = 1}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final uri = Uri.parse(
        //'http://127.0.0.1:8000/api/tuition/treasurer/records'
        'http://10.0.2.2:8000/api/tuition/treasurer/records'
        '?status=$selectedStatus'
        '&search=${Uri.encodeComponent(_searchController.text.trim())}'
        '&page=$page',
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          totalRecords = int.tryParse(
                (data['summary']['total_records'] ?? '0').toString(),
              ) ??
              0;

          totalCollected = double.tryParse(
                (data['summary']['total_collected'] ?? '0').toString(),
              ) ??
              0.0;

          approvedCount = int.tryParse(
                (data['summary']['approved_count'] ?? '0').toString(),
              ) ??
              0;

          rejectedCount = int.tryParse(
                (data['summary']['rejected_count'] ?? '0').toString(),
              ) ??
              0;

          records = data['records']['data'] ?? [];
          currentPage = int.tryParse(
                (data['records']['current_page'] ?? '1').toString(),
              ) ??
              1;
          lastPage = int.tryParse(
                (data['records']['last_page'] ?? '1').toString(),
              ) ??
              1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Failed to load records')),
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

  Widget _summaryCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8C8C8C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String title, String value, Color color) {
    final bool active = selectedStatus == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedStatus = value;
          });
          fetchRecords();
        },
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 2.5,
              color: active ? color : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF22B8CF);
    const bgColor = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
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
                    'Payment Records',
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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by Matric No. or Date',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                              ),
                            ),
                            onSubmitted: (_) => fetchRecords(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _summaryCard('$totalRecords', 'Total Records', primaryColor),
                              _summaryCard(
                                'RM ${totalCollected.toStringAsFixed(0)}',
                                'Total Collected',
                                const Color(0xFF2EAD67),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _tabItem('All', 'All', primaryColor),
                              _tabItem('Approved', 'Approved', const Color(0xFF2EAD67)),
                              _tabItem('Rejected', 'Rejected', const Color(0xFFE85B5B)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E2E2)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'DATE',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A8A8A)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'MATRIC NO.',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A8A8A)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'AMOUNT',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A8A8A)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'STATUS',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A8A8A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                if (records.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text('No payment records found.'),
                                  )
                                else
                                  ...records.map((item) {
                                    final status = item['status']?.toString() ?? 'Pending';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Color(0xFFF1F1F1)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['submitted_at'] != null
                                                  ? item['submitted_at'].toString().substring(0, 10)
                                                  : '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['matric_no']?.toString() ?? '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['amount'] ?? 0).toString()}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: statusBg(status),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: statusText(status),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing page $currentPage of $lastPage',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                              ),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: currentPage > 1
                                        ? () => fetchRecords(page: currentPage - 1)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      foregroundColor: const Color(0xFF666666),
                                      minimumSize: const Size(66, 34),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('< Prev'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: currentPage < lastPage
                                        ? () => fetchRecords(page: currentPage + 1)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(66, 34),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Next >'),
                                  ),
                                ],
                              ),
                            ],
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