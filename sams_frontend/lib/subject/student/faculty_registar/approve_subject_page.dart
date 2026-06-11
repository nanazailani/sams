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

  //static const _apiBaseUrl = 'http://10.0.2.2:8000/api';
  static const _apiBaseUrl = 'https://darkgrey-lyrebird-505549.hostingersite.com/api';


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

  Future<void> _loadRequests({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
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
          if (status == 'Approved') {
            approved++;
          } else if (status == 'Rejected') rejected++;
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
      if (mounted && showLoading) setState(() => _isLoading = false);
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

  Future<_SubjectActionResult> _updateSubjectStatus(
    Map<String, dynamic> subject,
    String status,
  ) async {
    final registrationId = subject['registration_id'];
    if (registrationId == null) {
      _showSnack('Registration ID is missing for this subject', isError: true);
      return const _SubjectActionResult(success: false);
    }

    String? rejectionReason;
    if (status == 'Rejected') {
      rejectionReason = await _askRejectionReason();
      if (rejectionReason == null) {
        return const _SubjectActionResult(success: false);
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subject-approvals/registrations/$registrationId/status'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'status': status,
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return const _SubjectActionResult(success: false);

      if (response.statusCode == 200) {
        final code = subject['code']?.toString() ?? 'Subject';
        _showSnack('$code ${status.toLowerCase()} successfully');
        await _loadRequests(showLoading: false);
        return _SubjectActionResult(
          success: true,
          rejectionReason: rejectionReason,
        );
      }

      _showSnack(
        _responseMessage(response, 'Failed to update subject'),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return const _SubjectActionResult(success: false);
      _showSnack('Error: $e', isError: true);
    }

    return const _SubjectActionResult(success: false);
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Rejection Reason'),
              content: TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write the reason for rejection',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() => errorText = 'Reason is required');
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return reason;
  }

  Future<List<Map<String, dynamic>>?> _fetchStudentApprovalSubjects(
    Object? studentId,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/subject-approvals/$studentId/subjects'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List raw = data['subjects'] ?? [];
        return raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (mounted) {
        _showSnack(
          _responseMessage(response, 'Failed to load subjects'),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to load subjects', isError: true);
    }

    return null;
  }

  Future<void> _openStudentSubjectsDialog(Map<String, dynamic> student) async {
    final subjects = await _fetchStudentApprovalSubjects(student['student_id']);

    if (!mounted || subjects == null) {
      return;
    }

    // Show as a full Dialog (page popup) instead of bottom sheet
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StudentSubjectsDialog(
        student: student,
        subjects: subjects,
        onUpdateSubject: _updateSubjectStatus,
      ),
    );
  }

  String _responseMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}

    return fallback;
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

  const _StudentApprovalCard({
    required this.student,
    required this.onViewSubjects,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name']?.toString() ?? '-';
    final matricNo = student['matric_no']?.toString() ?? '-';
    final year = student['year']?.toString() ?? '-';
    final advisor = student['advisor']?.toString() ?? '-';
    final programme = student['programme']?.toString() ?? '-';
    final status = student['status']?.toString() ?? 'Pending';

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

class _SubjectActionResult {
  final bool success;
  final String? rejectionReason;

  const _SubjectActionResult({
    required this.success,
    this.rejectionReason,
  });
}

class _StudentSubjectsDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> subjects;
  final Future<_SubjectActionResult> Function(
    Map<String, dynamic> subject,
    String status,
  ) onUpdateSubject;

  const _StudentSubjectsDialog({
    required this.student,
    required this.subjects,
    required this.onUpdateSubject,
  });

  @override
  State<_StudentSubjectsDialog> createState() => _StudentSubjectsDialogState();
}

class _StudentSubjectsDialogState extends State<_StudentSubjectsDialog> {
  late final List<Map<String, dynamic>> _subjects;
  int? _updatingRegistrationId;

  @override
  void initState() {
    super.initState();
    _subjects = widget.subjects
        .map<Map<String, dynamic>>((subject) => Map<String, dynamic>.from(subject))
        .toList();
  }

  int? _registrationId(Map<String, dynamic> subject) {
    final value = subject['registration_id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _subjectStatus(Map<String, dynamic> subject) {
    return (subject['approval_status'] ?? subject['status'] ?? 'Pending').toString();
  }

  Future<void> _handleSubjectStatus(
    Map<String, dynamic> subject,
    String status,
  ) async {
    final registrationId = _registrationId(subject);
    if (registrationId == null) return;

    setState(() => _updatingRegistrationId = registrationId);
    final result = await widget.onUpdateSubject(subject, status);

    if (!mounted) return;

    if (result.success) {
      subject['approval_status'] = status;
      subject['status'] = status;
      subject['rejection_reason'] =
          status == 'Rejected' ? result.rejectionReason : null;
    }

    setState(() => _updatingRegistrationId = null);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.student['name']?.toString() ?? '-';
    final matricNo = widget.student['matric_no']?.toString() ?? '-';

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
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'ID: $matricNo',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
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
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: _subjects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No registered subjects.', style: TextStyle(color: Colors.black54)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _subjects.length,
                    itemBuilder: (context, i) {
                      final s = _subjects[i];
                      final code = s['code']?.toString() ?? '-';
                      final subName = s['name']?.toString() ?? '-';
                      final credit = s['credit_hour']?.toString() ?? '0';
                      final section = s['section']?.toString() ?? '-';
                      final tutorial = s['tutorial_lab']?.toString() ?? '-';
                      final time = s['time_summary']?.toString() ?? '-';
                      final status = _subjectStatus(s);
                      final isPending = status == 'Pending';
                      final registrationId = _registrationId(s);
                      final isUpdating =
                          registrationId != null && _updatingRegistrationId == registrationId;
                      final canUpdate = isPending &&
                          registrationId != null &&
                          _updatingRegistrationId == null;
                      final reason = s['rejection_reason']?.toString().trim() ?? '';

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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$code - ${subName.toUpperCase()}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusPill(status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Credit Hours: $credit', style: const TextStyle(fontSize: 12)),
                            Text('Section: $section', style: const TextStyle(fontSize: 12)),
                            Text('Tutorial/Lab: $tutorial', style: const TextStyle(fontSize: 12)),
                            Text('Time: $time', style: const TextStyle(fontSize: 12)),
                            if (status == 'Rejected' && reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: $reason',
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                            ],
                            if (isPending) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: canUpdate
                                            ? () => _handleSubjectStatus(s, 'Rejected')
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.red.withOpacity(0.35),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                        ),
                                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: canUpdate
                                            ? () => _handleSubjectStatus(s, 'Approved')
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2FC4C9),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(0xFF2FC4C9).withOpacity(0.35),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                        ),
                                        child: isUpdating
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Approve', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
