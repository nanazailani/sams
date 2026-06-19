import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart' show LoginPage;
import 'verify_student_payment_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _TreasurerFeeDashboardPageState();
}

class _TreasurerFeeDashboardPageState
    extends State<DashboardPage> {
  // Warna-warna yang digunakan throughout page ni
  static const Color primaryColor = Color(0xFF26BCD3);
  static const Color bgColor = Color(0xFFF4F4F4);
  static const Color borderColor = Color(0xFFB9C0CC);
  static const Color pendingColor = Color(0xFFF2B233);
  static const Color approvedColor = Color(0xFF00B85C);
  static const Color rejectedColor = Color(0xFFE53935);

  // Base URL API — tukar ke localhost kalau nak test local
  static const String _baseUrl =
      'https://darkgrey-lyrebird-505549.hostingersite.com/api';

  final TextEditingController _searchController = TextEditingController();

  // Senarai payment yang diload dari API
  List<dynamic> _allPayments = [];
  bool _isLoading = true;

  // Tab yang aktif sekarang — Pending, Approved, atau Rejected
  String _selectedTab = 'Pending';

  // Filter dropdown — course dan batch
  String? _selectedCourse;
  String? _selectedBatch;

  // Summary count untuk stat cards atas
  Map<String, dynamic> _summary = {
    'pending_count': 0,
    'approved_count': 0,
    'rejected_count': 0,
  };

  // State untuk Week 5 Lock
  bool _isLocked = false;
  bool _isLockLoading = false;

  // Pilih filter course dan batch
  final List<String> _courseOptions = [
    'All',
    'BCS - Software Engineering',
    'BCS - Data Science',
    'Diploma in Computing',
  ];

  final List<String> _batchOptions = [
    'All',
    '2023',
    '2024',
    '2025',
  ];

  @override
  void initState() {
    super.initState();
    // Load payment dan lock status masa page dibuka
    _fetchPendingPayments();
    _fetchLockStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi Lock / Unlock Akses Student 

  // Check status lock semasa dari API.
  // Digunakan untuk set state awal butang lock/unlock.
  Future<void> _fetchLockStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/week-lock/status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isLocked = data['is_locked'] == true;
        });
      }
    } catch (e) {
      debugPrint('Fetch lock status error: $e');
    }
  }

  // Toggle lock/unlock akses student.
  // Kalau locked, unlock — kalau unlocked, lock.
  // Tunjuk mesej result lepas API response.
  Future<void> _toggleLock() async {
    setState(() => _isLockLoading = true);

    try {
      final endpoint = _isLocked ? 'unlock' : 'lock';
      final response = await http
          .post(Uri.parse('$_baseUrl/week-lock/$endpoint'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isLocked = data['is_locked'] == true;
        });
        _showMessage(data['message'] ?? 'Done');
      } else {
        _showMessage('Failed to update lock status');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isLockLoading = false);
    }
  }

  // Payment

  // Fetch senarai payment dari API ikut tab dan filter yang dipilih.
  // Kalau ada search text, hantar sekali dalam query params.
  Future<void> _fetchPendingPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParams = <String, String>{};

      // Tambah search query kalau ada
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }

      // Filter by status — Pending je default, lain kena pass explicitly
      if (_selectedTab != 'Pending') {
        queryParams['status'] = _selectedTab;
      }

      final uri = Uri.parse('$_baseUrl/tuition/treasurer/pending')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final records = decoded['records'];

        setState(() {
          _summary = Map<String, dynamic>.from(decoded['summary'] ?? {});
          // Handle sama ada response dalam format paginate atau biasa
          _allPayments = records is Map
              ? (records['data'] as List? ?? [])
              : (decoded['data'] as List? ?? []);
        });
      } else {
        _showMessage('Failed to load payment records');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter payment secara local — search, course, dan batch.
  // Ni untuk search yang tak perlu hit API semula.
  List<dynamic> get _filteredPayments {
    return _allPayments.where((item) {
      final matric = (item['matric_no'] ?? '').toString().toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final programme = (item['programme'] ?? '').toString().toLowerCase();
      final search = _searchController.text.trim().toLowerCase();

      // Match search — by matric no or nama
      final matchesSearch = search.isEmpty ||
          matric.contains(search) ||
          name.contains(search);

      // Match course/programme — case-insensitive partial match
      final selectedCourse = (_selectedCourse ?? '').toLowerCase();
      final matchesCourse = _selectedCourse == null ||
          _selectedCourse == 'All' ||
          programme == selectedCourse ||
          selectedCourse.contains(programme) ||
          programme.contains(selectedCourse);

      // Match batch — guna 2 digit terakhir tahun untuk compare dengan matric
      final batchText =
          '${item['semester'] ?? ''} ${item['session'] ?? ''} ${item['matric_no'] ?? ''}'
              .toString();
      final batchShort = (_selectedBatch != null && _selectedBatch!.length == 4)
          ? _selectedBatch!.substring(2)
          : _selectedBatch;
      final matchesBatch = _selectedBatch == null ||
          _selectedBatch == 'All' ||
          batchText.contains(_selectedBatch!) ||
          (batchShort != null && matric.contains(batchShort.toLowerCase()));

      return matchesSearch && matchesCourse && matchesBatch;
    }).toList();
  }

  // Helper untuk parse count dari summary map — handle null dan type mismatch.
  int _summaryCount(String key) {
    return int.tryParse((_summary[key] ?? 0).toString()) ?? 0;
  }

  int get _pendingCount => _summaryCount('pending_count');
  int get _approvedCount => _summaryCount('approved_count');
  int get _rejectedCount => _summaryCount('rejected_count');

  // Logout — clear semua SharedPreferences dan balik ke login page.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // Tunjuk snackbar mesej — used untuk success dan error.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Return warna background badge status payment.
  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFDDF5E7);
      case 'rejected':
        return const Color(0xFFFFE0E0);
      default:
        return const Color(0xFFF9E7AE);
    }
  }

  // Return warna teks badge status payment.
  Color _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return approvedColor;
      case 'rejected':
        return rejectedColor;
      default:
        return pendingColor;
    }
  }

  // Widget Butang Lock

  // Button untuk lock/unlock akses student.
  // Hijau = locked (akses disekat), Merah = unlocked (boleh akses).
  // Tunjuk spinner semasa proses API sedang berlaku.
  Widget _buildLockButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isLockLoading ? null : _toggleLock,
          icon: _isLockLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(_isLocked ? Icons.lock_open : Icons.lock),
          label: Text(
            _isLocked
                ? 'Unlock Student Access'
                : 'Lock Access (Week 5)',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            // Hijau kalau locked, merah kalau unlocked
            backgroundColor: _isLocked ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payments = _filteredPayments;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh untuk reload latest payment
          onRefresh: _fetchPendingPayments,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Header dengan butang logout
                Container(
                  height: 95,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: const BoxDecoration(
                    color: primaryColor,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tuition Fee Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Button logout — clear session dan balik login
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Chip current semester
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SemesterChip(text: 'Semester 2, 2025/2026'),
                ),
                const SizedBox(height: 18),

                // Button Lock / Unlock Akses 
                _buildLockButton(),
                const SizedBox(height: 18),

                // Stat Cards — Pending, Approved, Rejected 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopStatCard(
                          value: '$_pendingCount',
                          label: 'Pending',
                          valueColor: pendingColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _TopStatCard(
                          value: '$_approvedCount',
                          label: 'Approved',
                          valueColor: approvedColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _TopStatCard(
                          value: '$_rejectedCount',
                          label: 'Rejected',
                          valueColor: rejectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Search Bar 
                // Cari by matric no — submit untuk trigger fetch API
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _fetchPendingPayments(),
                    decoration: InputDecoration(
                      hintText: 'Search Matric No.',
                      prefixIcon:
                          const Icon(Icons.search, color: pendingColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Dropdown Filter Course & Batch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Filter by programme/kursus
                      Expanded(
                        child: _DropdownBox(
                          hint: 'Course',
                          value: _selectedCourse,
                          items: _courseOptions,
                          onChanged: (value) {
                            setState(() {
                              _selectedCourse = value;
                            });
                            _fetchPendingPayments();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter by tahun batch — compare dengan matric no
                      Expanded(
                        child: _DropdownBox(
                          hint: 'Batch',
                          value: _selectedBatch,
                          items: _batchOptions,
                          onChanged: (value) {
                            setState(() {
                              _selectedBatch = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Tab Status — Pending / Approved / Rejected 
                // Klik tab untuk filter senarai ikut status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatusTab(
                        text: 'Pending',
                        count: '$_pendingCount',
                        active: _selectedTab == 'Pending',
                        color: pendingColor,
                        onTap: () {
                          setState(() {
                            _selectedTab = 'Pending';
                          });
                          _fetchPendingPayments();
                        },
                      ),
                      _StatusTab(
                        text: 'Approved',
                        count: '$_approvedCount',
                        active: _selectedTab == 'Approved',
                        color: approvedColor,
                        onTap: () {
                          setState(() {
                            _selectedTab = 'Approved';
                          });
                          _fetchPendingPayments();
                        },
                      ),
                      _StatusTab(
                        text: 'Rejected',
                        count: '$_rejectedCount',
                        active: _selectedTab == 'Rejected',
                        color: rejectedColor,
                        onTap: () {
                          setState(() {
                            _selectedTab = 'Rejected';
                          });
                          _fetchPendingPayments();
                        },
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 18),
                ),
                const SizedBox(height: 10),

                // Table Senarai Payment
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isLoading
                        // Loading — tunjuk spinner
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                                child: CircularProgressIndicator()),
                          )
                        : payments.isEmpty
                            // Kosong — tunjuk mesej tiada rekod
                            ? const Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: Text(
                                    'No payment records found',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  // Header table
                                  const Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'MATRIC NO.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF586376),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'AMOUNT',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF586376),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'STATUS',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF586376),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'ACTION',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF586376),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),

                                  // Generate row untuk setiap payment — limit 5 per page
                                  ...payments.take(5).map((item) {
                                    final status =
                                        (item['status'] ?? 'Pending')
                                            .toString();
                                    return Column(
                                      children: [
                                        const SizedBox(height: 14),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Matric no dan nama student
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    item['matric_no'] ??
                                                        '-',
                                                    style:
                                                        const TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      height: 2),
                                                  // Nama student dalam saiz kecik
                                                  Text(
                                                    item['name'] ?? '',
                                                    style:
                                                        const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Jumlah bayaran
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'RM ${(item['amount'] ?? 0).toString()}',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ),
                                            // Badge status
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _statusBg(status),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  textAlign:
                                                      TextAlign.center,
                                                  style: TextStyle(
                                                    color: _statusText(
                                                        status),
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Butang View — navigate ke verify page
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: SizedBox(
                                                  height: 36,
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              VerifyStudentPaymentPage(
                                                            paymentId: int.tryParse(
                                                                    item['id']
                                                                        .toString()) ??
                                                                0,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          primaryColor,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    20),
                                                      ),
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 16,
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text(
                                                      'View',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        const Divider(height: 1),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 18),

                // Pagination
                // Tunjuk berapa rekod yang didisplay dari jumlah total
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Showing ${payments.isEmpty ? 0 : payments.take(5).length} of ${payments.length} ${_selectedTab.toLowerCase()}',
                          style: const TextStyle(
                            color: Color(0xFF677285),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _PageButton(
                        text: '< Prev',
                        color: const Color(0xFF9DA8BA),
                        textColor: const Color(0xFF5A6372),
                        onTap: () {},
                      ),
                      const SizedBox(width: 10),
                      _PageButton(
                        text: 'Next >',
                        color: primaryColor,
                        textColor: Colors.white,
                        onTap: () {},
                      ),
                    ],
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

// Chip kecik untuk tunjuk current semester kat dashboard.
class _SemesterChip extends StatelessWidget {
  final String text;

  const _SemesterChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD9F7F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _TreasurerFeeDashboardPageState.primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Kad stat atas — tunjuk count besar (Pending/Approved/Rejected).
class _TopStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _TopStatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB9C0CC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nombor besar dengan warna ikut status
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Dropdown box untuk filter — course and batch.
// Wrapped dalam container dengan border untuk nampak konsisten.
class _DropdownBox extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownBox({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB9C0CC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Tab status — Pending, Approved, Rejected.
// Yang active ada underline dan teks bold.
// Ada badge count kecik sebelah nama tab.
class _StatusTab extends StatelessWidget {
  final String text;
  final String count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusTab({
    required this.text,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                text,
                style: TextStyle(
                  color: active ? color : Colors.black87,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              // Badge count kecik sebelah nama 
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Underline indicator — only tunjuk untuk tab yang active
          if (active)
            Container(
              width: 95,
              height: 3,
              color: color,
            ),
        ],
      ),
    );
  }
}

/// Button pagination — Prev dan Next.
/// Warna berbeza untuk distinguish antara dua-dua butang.
class _PageButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _PageButton({
    required this.text,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
