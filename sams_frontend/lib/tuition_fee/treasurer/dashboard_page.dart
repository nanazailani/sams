import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _TreasurerFeeDashboardPageState();
}

class _TreasurerFeeDashboardPageState
    extends State<DashboardPage> {
  static const Color primaryColor = Color(0xFF26BCD3);
  static const Color bgColor = Color(0xFFF4F4F4);
  static const Color borderColor = Color(0xFFB9C0CC);
  static const Color pendingColor = Color(0xFFF2B233);
  static const Color approvedColor = Color(0xFF00B85C);
  static const Color rejectedColor = Color(0xFFE53935);

  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allPayments = [];
  bool _isLoading = true;
  String _selectedTab = 'Pending';
  String? _selectedCourse;
  String? _selectedBatch;

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
    _fetchPendingPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // change this to your real backend URL
      const String baseUrl = 'http://10.0.2.2:8000/api';

      final queryParams = <String, String>{};

      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }

      if (_selectedCourse != null && _selectedCourse != 'All') {
        queryParams['course'] = _selectedCourse!;
      }

      if (_selectedTab != 'Pending') {
        queryParams['status'] = _selectedTab;
      }

      final uri = Uri.parse('$baseUrl/tuition/treasurer/pending')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          _allPayments = decoded['data'] ?? [];
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

  List<dynamic> get _filteredPayments {
    return _allPayments.where((item) {
      final matric = (item['matric_no'] ?? '').toString().toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final programme = (item['programme'] ?? '').toString();
      final search = _searchController.text.trim().toLowerCase();

      final matchesSearch = search.isEmpty ||
          matric.contains(search) ||
          name.contains(search);

      final matchesCourse =
          _selectedCourse == null ||
          _selectedCourse == 'All' ||
          programme == _selectedCourse;

      final batchText = (item['semester'] ?? '').toString();
      final matchesBatch = _selectedBatch == null ||
          _selectedBatch == 'All' ||
          batchText.contains(_selectedBatch!);

      return matchesSearch && matchesCourse && matchesBatch;
    }).toList();
  }

  int get _pendingCount => _selectedTab == 'Pending'
      ? _filteredPayments.length
      : _allPayments
            .where((e) => (e['status'] ?? '').toString().toLowerCase() == 'pending')
            .length;

  int get _approvedCount => _allPayments
      .where((e) => (e['status'] ?? '').toString().toLowerCase() == 'approved')
      .length;

  int get _rejectedCount => _allPayments
      .where((e) => (e['status'] ?? '').toString().toLowerCase() == 'rejected')
      .length;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final payments = _filteredPayments;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPendingPayments,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 95,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _SemesterChip(text: 'Semester 2, 2025/2026'),
                ),
                const SizedBox(height: 18),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _fetchPendingPayments(),
                    decoration: InputDecoration(
                      hintText: 'Search Matric No.',
                      prefixIcon: const Icon(Icons.search, color: pendingColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
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
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : payments.isEmpty
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
                                  ...payments.take(5).map((item) {
                                    final status =
                                        (item['status'] ?? 'Pending').toString();
                                    return Column(
                                      children: [
                                        const SizedBox(height: 14),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['matric_no'] ?? '-',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item['name'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'RM ${(item['amount'] ?? 0).toString()}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _statusBg(status),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: _statusText(status),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: SizedBox(
                                                  height: 36,
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      _showMessage(
                                                        'Next page: Verify payment for ID ${item['id']}',
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          primaryColor,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                20),
                                                      ),
                                                      padding: const EdgeInsets
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
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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