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

  // Filter status — All, Approved, atau Rejected
  String selectedStatus = 'All';

  // Summary stats untuk kad atas
  int totalRecords = 0;
  double totalCollected = 0;
  int approvedCount = 0;
  int rejectedCount = 0;

  // Data rekod dan pagination
  List records = [];
  int currentPage = 1;
  int lastPage = 1;

  @override
  void initState() {
    super.initState();
    // Load rekod payment masa page dibuka
    fetchRecords();
  }

  // Fetch rekod payment dari API ikut status dan search yang dipilih.
  // Support pagination — pass page number untuk navigate antara pages.
  Future<void> fetchRecords({int page = 1}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final uri = Uri.parse(
        // Untuk development local, uncomment line bawah:
        //'http://127.0.0.1:8000/api/tuition/treasurer/records'
        'https://darkgrey-lyrebird-505549.hostingersite.com/api/tuition/treasurer/records'
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
          // Parse summary stats — guna tryParse untuk elak crash kalau type lain
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

          // Extract rekod dan info pagination
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
        // API error — tunjuk mesej dari response
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Failed to load records')),
        );
      }
    } catch (e) {
      // Network error atau lain-lain
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  // Return warna background badge status payment.
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

  // Return warna teks badge status payment.
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

  // tunjuk nilai dan label.
  // Digunakan untuk Total Records dan Total Collected.
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
            // Nilai utama — bold dengan warna ikut jenis
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

  // Tab filter status — All, Approved, Rejected.
  // Yang active ada underline bawah.
  Widget _tabItem(String title, String value, Color color) {
    final bool active = selectedStatus == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedStatus = value;
          });
          // Fetch semula bila tukar tab
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
            // Underline — nampak kalau tab active je
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

            // Header dengan button back
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
                  // Loading spinner — tunjuk masa fetch data
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [

                          // Search Bar 
                          // Cari by matric no atau tarikh — submit untuk trigger fetch
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

                          // Kad Summary 
                          // Total rekod dan jumlah kutipan yang dah approved
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

                          // Tab Filter Status 
                          // Klik untuk filter rekod ikut status
                          Row(
                            children: [
                              _tabItem('All', 'All', primaryColor),
                              _tabItem('Approved', 'Approved', const Color(0xFF2EAD67)),
                              _tabItem('Rejected', 'Rejected', const Color(0xFFE85B5B)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Table Rekod Payment
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E2E2)),
                            ),
                            child: Column(
                              children: [
                                // Header table
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

                                // Kalau kosong — tunjuk mesej tiada rekod
                                if (records.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text('No payment records found.'),
                                  )
                                else
                                  // Generate satu row untuk setiap rekod payment
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
                                          // Tarikh submitted — ambil 10 char pertama (YYYY-MM-DD)
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['submitted_at'] != null
                                                  ? item['submitted_at'].toString().substring(0, 10)
                                                  : '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          // Matric no student
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['matric_no']?.toString() ?? '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          // Jumlah bayaran
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['amount'] ?? 0).toString()}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          // Badge status — Approved / Rejected / Pending
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
                                  }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Pagination
                          // Tunjuk page semasa dan butang prev/next
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing page $currentPage of $lastPage',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                              ),
                              Row(
                                children: [
                                  // Butang Prev — disabled kalau dah kat page pertama
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
                                  // Butang Next — disabled kalau dah kat page terakhir
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
