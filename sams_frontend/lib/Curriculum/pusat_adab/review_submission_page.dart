import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'approve_credit_page.dart';

class ReviewSubmissionPage extends StatefulWidget {
  const ReviewSubmissionPage({super.key});

  @override
  State<ReviewSubmissionPage> createState() => _ReviewSubmissionPageState();
}

class _ReviewSubmissionPageState extends State<ReviewSubmissionPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _modules = [];
  Map<String, dynamic> _summary = {
    'total_registered': 0,
    'present': 0,
    'claims_submitted': 0,
    'approved_claims': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final query = <String, String>{};
      final search = _searchController.text.trim();

      if (search.isNotEmpty) {
        query['search'] = search;
      }

      if (_selectedFilter != 'All') {
        query['filter'] = _selectedFilter.toUpperCase();
      }

      final uri = Uri.https(
        'darkgrey-lyrebird-505549.hostingersite.com',
        '/api/pusat-adab/module-registrations',
        query,
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      );

      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];

        setState(() {
          _modules = rows
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _summary = Map<String, dynamic>.from(decoded['summary'] ?? {});
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              decoded['message']?.toString() ?? 'Failed to load records';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return {
        'status': false,
        'message': 'Server returned an empty response.',
      };
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'status': false,
        'message': 'Unexpected server response format.',
      };
    } on FormatException {
      return {
        'status': false,
        'message':
            'Server returned a non-JSON response. Please check Laravel logs or make sure the backend server is running.',
      };
    }
  }

  int _number(String key) {
    return int.tryParse((_summary[key] ?? 0).toString()) ?? 0;
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF27206F), Color(0xFF5A4DFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: const Text(
        'Review Submissions',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onSubmitted: (_) => _fetchRecords(),
        decoration: InputDecoration(
          hintText: 'Search student, matric, module',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38),
          suffixIcon: IconButton(
            onPressed: _fetchRecords,
            icon: const Icon(Icons.tune, size: 18, color: Color(0xFF5A4DFF)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const filters = ['All', 'Registered', 'Present', 'Claimed', 'Not Claimed'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              selectedColor: const Color(0xFF5A4DFF),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide.none,
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
                _fetchRecords();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        _SummaryCard(
          value: _number('total_registered'),
          label: 'Registered',
          color: const Color(0xFF5A4DFF),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: _number('present'),
          label: 'Present',
          color: const Color(0xFF00B050),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: _number('claims_submitted'),
          label: 'Claimed',
          color: const Color(0xFFF2B500),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: _number('approved_claims'),
          label: 'Approved',
          color: const Color(0xFF1BA76A),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 90),
      child: Center(
        child: Text(
          'No module registration records yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module) {
    final records = (module['records'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFF5A4DFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${module['module_code'] ?? '--'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF27206F),
                      ),
                    ),
                    Text(
                      module['module_name']?.toString() ?? '--',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: 'Registered',
                value: module['total_registered']?.toString() ?? '0',
              ),
              _MiniStat(
                label: 'Present',
                value: module['present']?.toString() ?? '0',
              ),
              _MiniStat(
                label: 'Claimed',
                value: module['claimed']?.toString() ?? '0',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: records.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModuleRecordsPage(
                            module: module,
                            records: records,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35C9CA),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black26,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Records',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchRecords,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    _buildSearch(),
                    const SizedBox(height: 10),
                    _buildFilters(),
                    const SizedBox(height: 12),
                    _buildSummary(),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 90),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 90),
                        child: Center(
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else if (_modules.isEmpty)
                      _buildEmptyState()
                    else
                      ..._modules.map(_buildModuleCard),
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

class ModuleRecordsPage extends StatelessWidget {
  final Map<String, dynamic> module;
  final List<Map<String, dynamic>> records;

  const ModuleRecordsPage({
    super.key,
    required this.module,
    required this.records,
  });

  Color _chipColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
      case 'APPROVED':
        return const Color(0xFF00B050);
      case 'IN PROGRESS':
        return const Color(0xFFF2B500);
      case 'REJECTED':
      case 'ABSENT':
        return const Color(0xFFE51C2A);
      default:
        return const Color(0xFF8A8A8A);
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '--';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--';
    final parts = rawTime.split(':');
    if (parts.length < 2) return rawTime;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record, int index) {
    final attendance = record['attendance_status']?.toString() ?? 'REGISTERED';
    final claim = record['claim_status']?.toString() ?? 'NOT CLAIMED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                index.isEven ? const Color(0xFFE9C6D5) : const Color(0xFFB8E4F2),
            child: const Icon(Icons.person, color: Color(0xFF27206F)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['student_name']?.toString() ?? '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                Text(
                  record['matric_no']?.toString() ?? '--',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  '${record['venue'] ?? '--'} | ${_formatDate(record['class_date']?.toString())}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(attendance, _chipColor(attendance)),
                    _chip(claim, _chipColor(claim)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27206F), Color(0xFF5A4DFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${module['module_code'] ?? '--'} Records',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    module['module_name']?.toString() ?? '--',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatDate(module['class_date']?.toString())} | '
                    '${_formatTime(module['start_time']?.toString())} - '
                    '${_formatTime(module['end_time']?.toString())} | '
                    '${module['venue'] ?? '--'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ApproveCreditPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Approve Credit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35C9CA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 90),
                      child: Center(
                        child: Text(
                          'No student records for this module',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    ...records.asMap().entries.map(
                          (entry) => _recordCard(entry.value, entry.key),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF5A4DFF),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
