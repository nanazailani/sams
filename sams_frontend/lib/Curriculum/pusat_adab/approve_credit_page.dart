import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'claim_report_page.dart';

class ApproveCreditPage extends StatefulWidget {
  const ApproveCreditPage({super.key});

  @override
  State<ApproveCreditPage> createState() => _ApproveCreditPageState();
}

class _ApproveCreditPageState extends State<ApproveCreditPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'All'; // default tunjuk semua, filter ikut status bila user pilih
  List<Map<String, dynamic>> _claims = [];

  // default value kalau API tak return summary (just in case backend rosak/lupa hantar)
  Map<String, dynamic> _summary = {
    'pending': 0,
    'approved_today': 0,
    'urgent': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchClaims(); // terus load data bila page bukak, takyah tunggu user buat apa2
  }

  @override
  void dispose() {
    _searchController.dispose(); // jangan lupa dispose controller, leak kalau tak
    super.dispose();
  }

  // fetch list claims dari API, support search + filter status sekali
  Future<void> _fetchClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final query = <String, String>{};
      final search = _searchController.text.trim();

      // only hantar param search/status kalau ada value, takyah hantar empty string
      if (search.isNotEmpty) {
        query['search'] = search;
      }

      if (_selectedFilter != 'All') {
        query['status'] = _selectedFilter.toUpperCase();
      }

      final uri = Uri.https(
        'darkgrey-lyrebird-505549.hostingersite.com',
        '/api/pusat-adab/credit-claims',
        query,
      );

      final response = await http.get(uri);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      // check mounted dulu sebab async call, takut widget dah dispose time response balik
      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];

        setState(() {
          _claims = rows
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _summary = Map<String, dynamic>.from(decoded['summary'] ?? {});
          _isLoading = false;
        });
      } else {
        // backend reject ke error ke, just tunjuk message dia kat user
        setState(() {
          _errorMessage = decoded['message']?.toString() ?? 'Failed to load claims';
          _isLoading = false;
        });
      }
    } catch (e) {
      // network error / json parse error / apa2 — tangkap je semua kat sini
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // untuk approve/reject claim. status pass kat sini 'APPROVED' atau 'REJECTED'
  Future<void> _updateClaimStatus(int claimId, String status) async {
    try {
      // amik reviewer id dari local storage, ni untuk track sape yg approve/reject claim ni
      final prefs = await SharedPreferences.getInstance();
      final reviewedBy = prefs.getInt('user_id');

      final response = await http.post(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/credit-claims/$claimId/status'),

        // dev/testing url, biar je comment ni kalau nak test local nanti
        // Uri.parse('http://10.0.2.2:8000/api/pusat-adab/credit-claims/$claimId/status'),

        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'status': status,
          'reviewed_by': reviewedBy,
        }),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      // tunjuk snackbar apa2 pun jadi, success ke fail, biar user tau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message']?.toString() ?? 'Claim updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // refresh list kalau berjaya update, supaya UI sync dengan backend
      if (response.statusCode == 200 && decoded['status'] == true) {
        _fetchClaims();
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

  // helper amik number dari summary map, kalau null/invalid default 0 je
  int _summaryNumber(String key) {
    return int.tryParse((_summary[key] ?? 0).toString()) ?? 0;
  }

  // warna badge ikut status — urgent kena letak before default sebab default pun kuning gak
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF19B86A);
      case 'REJECTED':
        return const Color(0xFFE61F2B);
      case 'URGENT':
        return const Color(0xFFFF8A00);
      default:
        return const Color(0xFFF2B500); // pending
    }
  }

  // logic ni untuk decide label apa nak tunjuk kat card
  // backend simpan status 'IN PROGRESS' untuk yg belum approve/reject,
  // so kalau priority dia 'urgent' kita override label jadi "Urgent" instead of "Pending"
  String _statusLabel(Map<String, dynamic> claim) {
    final priority = (claim['priority'] ?? '').toString().toUpperCase();
    final status = (claim['status'] ?? 'IN PROGRESS').toString().toUpperCase();

    if (status == 'IN PROGRESS' && priority == 'URGENT') {
      return 'Urgent';
    }

    if (status == 'IN PROGRESS') {
      return 'Pending';
    }

    // capitalize first letter je, e.g APPROVED -> Approved
    return status[0] + status.substring(1).toLowerCase();
  }

  // format date jadi "18 Jun 2026" instead of raw ISO string dari API
  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '--';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate; // parse fail, return raw je daripada crash
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  // convert 24hr time string (HH:mm) jadi format 12hr dengan AM/PM
  String _formatTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--';
    final parts = rawTime.split(':');
    if (parts.length < 2) return rawTime;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12; // jam 0 (midnight) kena jadi 12, bukan 0
    return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
  }

  // header bar dengan back button + title, gradient purple ikut tema app
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
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            onPressed: () {
              // check canPop dulu, takut crash kalau page ni root (takde page belakang)
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Approve KoQ-Credit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // search bar + dropdown filter + print report button
  Widget _buildToolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchClaims(), // search bila tekan enter
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Matric, activity',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.black38),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('Filter by')),
                    DropdownMenuItem(
                        value: 'IN PROGRESS', child: Text('Pending')),
                    DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedFilter = value);
                    _fetchClaims(); // auto refetch lepas tukar filter
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () {
              // pass current loaded claims terus ke report page, takyah fetch lagi
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaimReportPage(claims: _claims),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Print Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A4DFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 3 kotak summary kat atas (pending / approved today / urgent)
  Widget _buildSummary() {
    return Row(
      children: [
        _SummaryCard(
          value: _summaryNumber('pending'),
          label: 'Pending',
          color: const Color(0xFFF2B500),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: _summaryNumber('approved_today'),
          label: 'Approved Today',
          color: const Color(0xFF10A35A),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: _summaryNumber('urgent'),
          label: 'Urgent Review',
          color: const Color(0xFFE51C2A),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 90),
        child: Text(
          'No credit claim submissions yet',
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

  // card untuk satu claim — info student, module, attendance, & action buttons
  Widget _buildClaimCard(Map<String, dynamic> claim, int index) {
    final statusLabel = _statusLabel(claim);
    final statusColor = _statusColor(statusLabel);
    final status = (claim['status'] ?? '').toString().toUpperCase();

    // button approve/reject only active kalau claim tu masih pending
    // (dah approved/rejected takleh review balik)
    final canReview = status == 'IN PROGRESS';
    final start = _formatTime(claim['start_time']?.toString());
    final end = _formatTime(claim['end_time']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  // selang seli warna avatar ikut index, just untuk variation visual
                  backgroundColor: index.isEven
                      ? const Color(0xFFE9C6D5)
                      : const Color(0xFFB8E4F2),
                  child: Icon(
                    Icons.person,
                    color: index.isEven
                        ? const Color(0xFF6D3048)
                        : const Color(0xFF0B5E78),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim['student_name']?.toString() ?? '--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        claim['matric_no']?.toString() ?? '--',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 3, color: const Color(0xFF9AA1AE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${claim['module_code'] ?? '--'} ${claim['module_name'] ?? ''}'
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pekan | ${claim['venue'] ?? '--'}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(claim['class_date']?.toString())}    $start - $end',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // default cats 2 & attendance 0% kalau API takde hantar value ni
                        'CATS : ${claim['cats'] ?? 2}        Result: ${claim['attendance_percentage'] ?? 0}%',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Attendance : ',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B050),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              claim['attendance_status']?.toString() ?? 'PRESENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              // kalau dah takleh review, tunjuk '--' je instead of button aktif
                              label: canReview ? 'Approve' : '--',
                              color: canReview
                                  ? const Color(0xFF00B050)
                                  : const Color(0xFF8A8A8A),
                              onTap: canReview
                                  ? () => _updateClaimStatus(claim['id'] as int, 'APPROVED')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _ActionButton(
                              label: canReview ? 'Reject' : '--',
                              color: canReview
                                  ? const Color(0xFFE51C2A)
                                  : const Color(0xFF8A8A8A),
                              onTap: canReview
                                  ? () => _updateClaimStatus(claim['id'] as int, 'REJECTED')
                                  : null,
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
                onRefresh: _fetchClaims, // pull to refresh
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
                  children: [
                    _buildToolbar(),
                    const SizedBox(height: 12),
                    _buildSummary(),
                    const SizedBox(height: 12),
                    // priority: loading -> error -> empty -> baru list claims
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
                    else if (_claims.isEmpty)
                      _buildEmptyState()
                    else
                      ..._claims.asMap().entries.map(
                            (entry) => _buildClaimCard(entry.value, entry.key),
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

// kad kecik untuk summary stats (pending / approved today / urgent)
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
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// button approve/reject kat dalam claim card, reusable je sebab dua-dua sama style
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap; // null = disabled (claim dah takleh diapprove/reject)

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color, // warna sama walaupun disabled, just takleh tekan
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
