

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AttendanceRecord {
  final String id;
  final String matricNo;
  final String studentName;
  final String status;
  final String? submittedAt;

  const AttendanceRecord({
    required this.id,
    required this.matricNo,
    required this.studentName,
    required this.status,
    this.submittedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final verificationStatus = (json['verification_status'] ?? 'Pending').toString();
    final originalStatus = (json['status'] ?? 'Pending').toString();
    final displayStatus = verificationStatus == 'Rejected' ? 'Absent' : originalStatus;

    return AttendanceRecord(
      id: json['id'].toString(),
      matricNo: (json['matric'] ?? '-').toString(),
      studentName: (json['name'] ?? '-').toString(),
      status: displayStatus,
      submittedAt: json['time']?.toString(),
    );
  }
}

enum AttendanceSortOption {
  matricAsc,
  matricDesc,
  nameAsc,
  nameDesc,
  statusAsc,
  statusDesc,
}

class ViewAttendancePage extends StatefulWidget {
  final String classSessionId;
  final String subjectName;
  final String sessionLabel;
  final String timeRange;
  final String attendanceType;
  final List<AttendanceRecord> records;
  final ValueChanged<AttendanceRecord>? onEdit;
  final ValueChanged<AttendanceRecord>? onDelete;
  final VoidCallback? onPrint;

  const ViewAttendancePage({
    super.key,
    required this.classSessionId,
    required this.subjectName,
    required this.sessionLabel,
    required this.timeRange,
    required this.attendanceType,
    this.records = const [],
    this.onEdit,
    this.onDelete,
    this.onPrint,
  });

  @override
  State<ViewAttendancePage> createState() => _ViewAttendancePageState();
}

class _ViewAttendancePageState extends State<ViewAttendancePage> {
  String get _baseUrl {
    if (Platform.isAndroid) {
      //return 'http://127.0.0.1:8000/api';
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  bool _isLoading = true;
  bool _isPrinting = false;
  List<AttendanceRecord> _records = [];
  final TextEditingController _searchController = TextEditingController();
  AttendanceSortOption _sortOption = AttendanceSortOption.matricAsc;
  String _searchQuery = '';

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
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/attendance/${widget.classSessionId}/submissions'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load attendance records');
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      setState(() {
        _records = data
            .map((item) => AttendanceRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load attendance records: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editRecord(AttendanceRecord record) async {
    String selectedStatus = record.status;

    final updatedStatus = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Edit attendance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.studentName),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'Present', child: Text('Present')),
                      DropdownMenuItem(value: 'Late', child: Text('Late')),
                      DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selectedStatus),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedStatus == null) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/attendance/records/${record.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': updatedStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update attendance');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance updated successfully.')),
      );
      await _fetchRecords();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update attendance: $error')),
      );
    }
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/attendance/records/${record.id}'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete attendance');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance deleted successfully.')),
      );
      await _fetchRecords();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete attendance: $error')),
      );
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _records.where((record) {
      if (query.isEmpty) return true;
      return record.matricNo.toLowerCase().contains(query) ||
          record.studentName.toLowerCase().contains(query) ||
          record.status.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case AttendanceSortOption.matricAsc:
          return a.matricNo.toLowerCase().compareTo(b.matricNo.toLowerCase());
        case AttendanceSortOption.matricDesc:
          return b.matricNo.toLowerCase().compareTo(a.matricNo.toLowerCase());
        case AttendanceSortOption.nameAsc:
          return a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase());
        case AttendanceSortOption.nameDesc:
          return b.studentName.toLowerCase().compareTo(a.studentName.toLowerCase());
        case AttendanceSortOption.statusAsc:
          return a.status.toLowerCase().compareTo(b.status.toLowerCase());
        case AttendanceSortOption.statusDesc:
          return b.status.toLowerCase().compareTo(a.status.toLowerCase());
      }
    });

    return filtered;
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF21B66F);
      case 'late':
        return const Color(0xFFE39B00);
      case 'absent':
        return const Color(0xFFE05050);
      default:
        return const Color(0xFF7A8194);
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFFDDF7E9);
      case 'late':
        return const Color(0xFFFFF1CF);
      case 'absent':
        return const Color(0xFFFFE0E0);
      default:
        return const Color(0xFFF1F3F7);
    }
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<AttendanceSortOption>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF20242C),
                  ),
                ),
                const SizedBox(height: 16),
                _SortTile(
                  title: 'Matric No. (A-Z)',
                  selected: _sortOption == AttendanceSortOption.matricAsc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.matricAsc),
                ),
                _SortTile(
                  title: 'Matric No. (Z-A)',
                  selected: _sortOption == AttendanceSortOption.matricDesc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.matricDesc),
                ),
                _SortTile(
                  title: 'Student Name (A-Z)',
                  selected: _sortOption == AttendanceSortOption.nameAsc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.nameAsc),
                ),
                _SortTile(
                  title: 'Student Name (Z-A)',
                  selected: _sortOption == AttendanceSortOption.nameDesc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.nameDesc),
                ),
                _SortTile(
                  title: 'Status (A-Z)',
                  selected: _sortOption == AttendanceSortOption.statusAsc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.statusAsc),
                ),
                _SortTile(
                  title: 'Status (Z-A)',
                  selected: _sortOption == AttendanceSortOption.statusDesc,
                  onTap: () => Navigator.pop(context, AttendanceSortOption.statusDesc),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _sortOption = selected;
      });
    }
  }

  Future<void> _confirmDelete(AttendanceRecord record) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete attendance'),
        content: Text('Delete attendance record for ${record.studentName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteRecord(record);
    }
  }

  Future<void> _handlePrint() async {
    if (_records.isEmpty || _isPrinting) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      final pdf = pw.Document();
      final records = _filteredRecords;

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              widget.subjectName,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(widget.sessionLabel),
            pw.Text(widget.timeRange),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['Matric No', 'Student Name', 'Status', 'Time'],
              data: records
                  .map((record) => [
                        record.matricNo,
                        record.studentName,
                        record.status,
                        record.submittedAt ?? '-',
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print attendance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF244E99),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'View Record History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subjectName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F232B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.sessionLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF525A6A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.timeRange,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E3440),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE1E5EE)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search Matric ID / Name',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8A92A3),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(left: 12, right: 10),
                                  child: Icon(Icons.search, color: Color(0xFF6F7A8C), size: 24),
                                ),
                                prefixIconConstraints: BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                contentPadding: EdgeInsets.only(top: 12, bottom: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ActionIconButton(
                          icon: Icons.sort_rounded,
                          onTap: _showSortSheet,
                        ),
                        const SizedBox(width: 8),
                        _ActionIconButton(
                          icon: Icons.print_outlined,
                          onTap: _handlePrint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFDFE),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE9EDF4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'MATRIC NO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6F7A8C),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'STUDENT NAME',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6F7A8C),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Center(
                                    child: Text(
                                      'STATUS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF6F7A8C),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      'ACTION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF6F7A8C),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (records.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No attendance records found.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6F7A8C),
                                ),
                              ),
                            )
                          else
                            ...List.generate(records.length, (index) {
                              final record = records[index];

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: index == 0
                                          ? Colors.transparent
                                          : const Color(0xFFE9EDF4),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        record.matricNo,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF20242C),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: Text(
                                          record.studentName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF20242C),
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _statusBackgroundColor(record.status),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            record.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _statusTextColor(record.status),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _MiniActionButton(
                                            label: 'Edit',
                                            backgroundColor: const Color(0xFF14B85A),
                                            onTap: () => _editRecord(record),
                                          ),
                                          const SizedBox(height: 8),
                                          _MiniActionButton(
                                            label: 'Delete',
                                            backgroundColor: const Color(0xFFF44336),
                                            onTap: () => _confirmDelete(record),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
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

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E5EE)),
          ),
          child: Icon(icon, color: const Color(0xFF1F232B)),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF20242C),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF244E99),
                ),
            ],
          ),
        ),
      ),
    );
  }
}