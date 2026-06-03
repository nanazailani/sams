import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecordParticipationPage extends StatefulWidget {
  const RecordParticipationPage({super.key});

  @override
  State<RecordParticipationPage> createState() => _RecordParticipationPageState();
}

class _RecordParticipationPageState extends State<RecordParticipationPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _modules = [];

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

      final response = await http.get(
        Uri.https('darkgrey-lyrebird-505549.hostingersite.com', '/api/pusat-adab/module-registrations', query),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        final rows = decoded['data'] as List<dynamic>? ?? [];

        setState(() {
          _modules = rows
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
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
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return {
      'status': false,
      'message': 'Server returned an invalid response.',
    };
  }

  Widget _header() {
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
        'Record Participation',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '--';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _moduleDate(Map<String, dynamic> module) {
    return _formatDate(module['class_date']?.toString());
  }

  String _moduleVenue(Map<String, dynamic> module) {
    return module['venue']?.toString() ?? '--';
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

  String _moduleTime(Map<String, dynamic> module) {
    final start = _formatTime(module['start_time']?.toString());
    final end = _formatTime(module['end_time']?.toString());
    return '$start - $end';
  }

  Widget _search() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onSubmitted: (_) => _fetchRecords(),
        decoration: InputDecoration(
          hintText: 'Search module or student',
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

  Widget _moduleCard(Map<String, dynamic> module) {
    final records = (module['records'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
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
              Expanded(
                child: _InfoPill(
                  icon: Icons.calendar_today_outlined,
                  text: _moduleDate(module),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoPill(
                  icon: Icons.place_outlined,
                  text: _moduleVenue(module),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoPill(
            icon: Icons.schedule_outlined,
            text: _moduleTime(module),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${module['total_registered'] ?? 0} students registered',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: records.isEmpty
                      ? null
                      : () async {
                          final removed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParticipationDetailPage(
                                module: module,
                                records: records,
                              ),
                            ),
                          );
                          if (removed == true) {
                            _fetchRecords();
                          }
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
                    'View Students',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 90),
      child: Center(
        child: Text(
          'No participation records yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
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
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchRecords,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _search(),
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
                      _emptyState()
                    else
                      ..._modules.map(_moduleCard),
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

class ParticipationDetailPage extends StatefulWidget {
  final Map<String, dynamic> module;
  final List<Map<String, dynamic>> records;

  const ParticipationDetailPage({
    super.key,
    required this.module,
    required this.records,
  });

  @override
  State<ParticipationDetailPage> createState() => _ParticipationDetailPageState();
}

class _ParticipationDetailPageState extends State<ParticipationDetailPage> {
  late List<Map<String, dynamic>> _records;
  bool _hasRemovedStudent = false;
  int? _removingRegistrationId;

  @override
  void initState() {
    super.initState();
    _records = List<Map<String, dynamic>>.from(widget.records);
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
      case 'APPROVED':
        return const Color(0xFF00B050);
      case 'ABSENT':
      case 'REJECTED':
        return const Color(0xFFE51C2A);
      default:
        return const Color(0xFF8A8A8A);
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '--';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return {
      'status': false,
      'message': 'Server returned an invalid response.',
    };
  }

  Future<void> _removeStudent(Map<String, dynamic> record) async {
    final registrationId = int.tryParse(record['registration_id']?.toString() ?? '');
    if (registrationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          '${record['student_name'] ?? 'This student'} will be removed from this module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFE51C2A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingRegistrationId = registrationId);

    try {
      final response = await http.delete(
        Uri.parse(
          'https://darkgrey-lyrebird-505549.hostingersite.com/api/pusat-adab/module-registrations/$registrationId',
        ),
        headers: const {'Accept': 'application/json'},
      );
      final decoded = _decodeResponse(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decoded['message']?.toString() ?? 'Student removed from module',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (response.statusCode == 200 && decoded['status'] == true) {
        setState(() {
          _hasRemovedStudent = true;
          _records.removeWhere((item) {
            return item['registration_id']?.toString() ==
                registrationId.toString();
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _removingRegistrationId = null);
      }
    }
  }

  Widget _studentCard(Map<String, dynamic> record, int index) {
    final attendance = record['attendance_status']?.toString() ?? 'REGISTERED';
    final registrationId = int.tryParse(record['registration_id']?.toString() ?? '');
    final isRemoving =
        registrationId != null && _removingRegistrationId == registrationId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(attendance),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              attendance,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 32,
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Remove student',
              onPressed: isRemoving ? null : () => _removeStudent(record),
              icon: isRemoving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.person_remove_alt_1_outlined,
                      color: Color(0xFFE51C2A),
                      size: 20,
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
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.pop(context, _hasRemovedStudent),
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.module['module_code'] ?? '--'} Participation',
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
                    widget.module['module_name']?.toString() ?? '--',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatDate(widget.module['class_date']?.toString())} | '
                    '${_formatTime(widget.module['start_time']?.toString())} - '
                    '${_formatTime(widget.module['end_time']?.toString())} | '
                    '${widget.module['venue'] ?? '--'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 90),
                      child: Center(
                        child: Text(
                          'No students registered for this module',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._records.asMap().entries.map(
                          (entry) => _studentCard(entry.value, entry.key),
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5A4DFF)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
