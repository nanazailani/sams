import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManageCoursesPage extends StatefulWidget {
  final VoidCallback onAddCoursesTap;

  const ManageCoursesPage({
    super.key,
    required this.onAddCoursesTap,
  });

  @override
  State<ManageCoursesPage> createState() => _ManageCoursesPageState();
}

class _ManageCoursesPageState extends State<ManageCoursesPage> {
  List<dynamic> allSubjects = [];
  List<dynamic> filteredSubjects = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredSubjects = allSubjects.where((s) {
        final code = (s['code'] ?? '').toString().toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        return code.contains(query) || name.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchSubjects() async {
    setState(() => isLoading = true);
    try {
      final res = await http
          .get(Uri.parse('http://10.0.2.2:8000/api/subjects'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List subjects = data is List ? data : (data['data'] ?? []);
        setState(() {
          allSubjects = subjects;
          filteredSubjects = List.from(subjects);
        });
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  Future<void> _deleteSubject(dynamic subject) async {
    final id = subject['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Subject'),
        content: Text(
            'Are you sure you want to delete "${subject['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse('http://10.0.2.2:8000/api/subjects/$id'),
        headers: {'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject deleted successfully'),
            backgroundColor: Color(0xFF3FC7C4),
          ),
        );
        await _fetchSubjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showViewDialog(dynamic subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          subject['code'] ?? '',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF3FC7C4)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _viewRow('Course Name', subject['name'] ?? '-'),
            const SizedBox(height: 8),
            _viewRow('Credit Hours',
                (subject['credit_hour'] ?? subject['credits'] ?? '-').toString()),
            const SizedBox(height: 8),
            _viewRow('Code', subject['code'] ?? '-'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3FC7C4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _viewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black54,
                fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3FC7C4), Color(0xFFE6D36F)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: const Text(
                'Manage Courses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'SEARCH',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Add Courses button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onAddCoursesTap,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ Add Courses'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3FC7C4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 75,
                            child: Text('Code',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          Expanded(
                            child: Text('Course Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text('Credit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text('Action',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.black87)),
                          ),
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF3FC7C4)))
                          : filteredSubjects.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.menu_book_outlined,
                                          size: 60,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No subject listed',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ListView.separated(
                                      itemCount: filteredSubjects.length,
                                      separatorBuilder: (_, __) => Divider(
                                          color: Colors.grey.shade100,
                                          height: 1),
                                      itemBuilder: (context, i) {
                                        final s = filteredSubjects[i];
                                        final code = s['code'] ?? '';
                                        final name = s['name'] ?? '';
                                        final credit = (s['credit_hour'] ??
                                                s['credits'] ??
                                                '-')
                                            .toString();

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              // Code
                                              SizedBox(
                                                width: 75,
                                                child: Text(
                                                  code,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87),
                                                ),
                                              ),
                                              // Name
                                              Expanded(
                                                child: Text(
                                                  name.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              // Credit
                                              SizedBox(
                                                width: 48,
                                                child: Text(
                                                  credit,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87),
                                                ),
                                              ),
                                              // Actions
                                              SizedBox(
                                                width: 80,
                                                child: Column(
                                                  children: [
                                                    // View button
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _showViewDialog(s),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                            colors: [
                                                              Color(0xFF3FC7C4),
                                                              Color(0xFFE6D36F),
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: const Center(
                                                          child: Text(
                                                            'View',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Delete button
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _deleteSubject(s),
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFFF4D4D),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: const Center(
                                                          child: Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
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
