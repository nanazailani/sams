import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApproveSubjectPage extends StatefulWidget {
  const ApproveSubjectPage({super.key});

  @override
  State<ApproveSubjectPage> createState() => _ApproveSubjectPageState();
}

class _ApproveSubjectPageState extends State<ApproveSubjectPage> {
  static const _primaryColor = Color(0xFF3FC7C4);
  static const _secondaryColor = Color(0xFFE6D36F);
  static const _apiBaseUrl = 'http://10.0.2.2:8000/api';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _statusFilter = 'All';

  // Counts are per-student, not per-subject
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$_apiBaseUrl/subject-approvals');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List students = data['students'] ?? [];
        final List<Map<String, dynamic>> parsed = students
            .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
            .toList();

        // Count by student status (not subject status)
        int pending = 0, approved = 0, rejected = 0;
        for (final s in parsed) {
          final status = (s['status'] ?? 'Pending').toString();
          if (status == 'Approved') approved++;
          else if (status == 'Rejected') rejected++;
          else pending++;
        }

        setState(() {
          _students = parsed;
          _pendingCount = pending;
          _approvedCount = approved;
          _rejectedCount = rejected;
        });
      } else {
        _showSnack('Failed to load approval list', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _searchController.text.trim().toLowerCase();
    return _students.where((student) {
      final matchesSearch = query.isEmpty ||
          (student['name'] ?? '').toString().toLowerCase().contains(query) ||
          (student['matric_no'] ?? '').toString().toLowerCase().contains(query);
      final matchesFilter = _statusFilter == 'All' ||
          (student['status'] ?? 'Pending').toString() == _statusFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  // Approve or reject ALL subjects of a student at once
  Future<void> _updateStudentStatus(Map<String, dynamic> student, String status) async {
    final studentId = student['student_id'];
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subject-approvals/student/$studentId/status'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnack('All subjects ${status.toLowerCase()} successfully');
        await _loadRequests();
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to update', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _openStudentSubjectsDialog(Map<String, dynamic> student) async {
    // Fetch subjects for this student
    List<Map<String, dynamic>> subjects = [];
    bool loadError = false;

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/subject-approvals/${student['student_id']}/subjects'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List raw = data['subjects'] ?? [];
        subjects = raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        loadError = true;
      }
    } catch (_) {
      loadError = true;
    }

    if (!mounted) return;

    if (loadError) {
      _showSnack('Failed to load subjects', isError: true);
      return;
    }

    // Show as a full Dialog (page popup) instead of bottom sheet
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StudentSubjectsDialog(
        student: student,
        subjects: subjects,
        onApproveAll: () async {
          Navigator.pop(ctx);
          await _updateStudentStatus(student, 'Approved');
        },
        onRejectAll: () async {
          Navigator.pop(ctx);
          await _updateStudentStatus(student, 'Rejected');
        },
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Text(
              'Subjects Approval',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        children: [
                          // Search + Filter
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search by Name / ID',
                                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9AA3AF)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _statusFilter,
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text('Filter by')),
                                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                      DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                                      DropdownMenuItem(value: 'Rejected', child: Text('Reject')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) setState(() => _statusFilter = value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Status counts — per student
                          Row(
                            children: [
                              _CountTile(count: _pendingCount, label: 'Pending', color: const Color(0xFFFFC536)),
                              const SizedBox(width: 6),
                              _CountTile(count: _approvedCount, label: 'Approved', color: Colors.green),
                              const SizedBox(width: 6),
                              _CountTile(count: _rejectedCount, label: 'Reject', color: Colors.red),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Student list
                          if (_filteredStudents.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                              child: const Text('No subject registration found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                            )
                          else
                            ..._filteredStudents.map(
                              (student) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _StudentApprovalCard(
                                  student: student,
                                  onViewSubjects: () => _openStudentSubjectsDialog(student),
                                  onApprove: () => _updateStudentStatus(student, 'Approved'),
                                  onReject: () => _updateStudentStatus(student, 'Rejected'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── COUNT TILE ──────────────────────────────────────────────────────────────

class _CountTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CountTile({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 64,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count.toString(), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── STUDENT CARD ─────────────────────────────────────────────────────────────

class _StudentApprovalCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onViewSubjects;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _StudentApprovalCard({
    required this.student,
    required this.onViewSubjects,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name']?.toString() ?? '-';
    final matricNo = student['matric_no']?.toString() ?? '-';
    final year = student['year']?.toString() ?? '-';
    final advisor = student['advisor']?.toString() ?? '-';
    final programme = student['programme']?.toString() ?? '-';
    final status = student['status']?.toString() ?? 'Pending';
    final isPending = status == 'Pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFE9D4E7),
                child: Icon(Icons.person, color: Color(0xFF6B4E71), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('ID: $matricNo    Year: $year',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _StatusPill(status),
            ],
          ),
          const Divider(color: Color(0xFF9AA3AF), thickness: 1.5, height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Academic Advisor:\n$advisor',
                        style: const TextStyle(fontSize: 10, height: 1.3)),
                    const SizedBox(height: 6),
                    Text('Programme: $programme',
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // View Subjects button
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: onViewSubjects,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF2FC4C9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('View Subjects', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),

          // Show Approve/Reject buttons only if still Pending
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2FC4C9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Approve All'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── STATUS PILL ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final color = status == 'Approved'
        ? Colors.green
        : status == 'Rejected'
            ? Colors.red
            : const Color(0xFFFFC536);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
      child: Text(
        status == 'Rejected' ? 'Reject' : status,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── SUBJECTS DIALOG (page popup, not bottom sheet) ──────────────────────────

class _StudentSubjectsDialog extends StatelessWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> subjects;
  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;

  const _StudentSubjectsDialog({
    required this.student,
    required this.subjects,
    required this.onApproveAll,
    required this.onRejectAll,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name']?.toString() ?? '-';
    final matricNo = student['matric_no']?.toString() ?? '-';
    final status = student['status']?.toString() ?? 'Pending';
    final isPending = status == 'Pending';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dialog header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3FC7C4), Color(0xFFE6D36F)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('ID: $matricNo',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Subject list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: subjects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No registered subjects.', style: TextStyle(color: Colors.black54)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: subjects.length,
                    itemBuilder: (context, i) {
                      final s = subjects[i];
                      final code = s['code']?.toString() ?? '-';
                      final subName = s['name']?.toString() ?? '-';
                      final credit = s['credit_hour']?.toString() ?? '0';
                      final section = s['section']?.toString() ?? '-';
                      final tutorial = s['tutorial_lab']?.toString() ?? '-';
                      final time = s['time_summary']?.toString() ?? '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$code - ${subName.toUpperCase()}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Credit Hours: $credit', style: const TextStyle(fontSize: 12)),
                            Text('Section: $section', style: const TextStyle(fontSize: 12)),
                            Text('Tutorial/Lab: $tutorial', style: const TextStyle(fontSize: 12)),
                            Text('Time: $time', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Approve All / Reject All buttons
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRejectAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reject All'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApproveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2FC4C9),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Approve All'),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _StatusPill(status),
            ),
        ],
      ),
    );
  }
}
