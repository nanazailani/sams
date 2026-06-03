import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'module_model.dart';
import 'available_classes_page.dart';

class BookNowPage extends StatefulWidget {
  const BookNowPage({super.key});

  @override
  State<BookNowPage> createState() => _BookNowPageState();
}

class _BookNowPageState extends State<BookNowPage> {
  final TextEditingController _searchController = TextEditingController();

  List<ModuleModel> _allModules = [];
  List<ModuleModel> _filteredModules = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _studentId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterModules);
    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getInt('student_id');
    await fetchModules();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterModules);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchModules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_studentId == null) {
        setState(() {
          _errorMessage = 'Student ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/modules').replace(
        
        
        // Uri.parse('http://10.0.2.2:8000 /api/modules').replace(
         
          queryParameters: {
            'student_id': _studentId.toString(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data = decoded['data'] ?? [];

        final modules = data
            .map((e) => ModuleModel.fromJson(e))
            .toList()
            .cast<ModuleModel>();

        setState(() {
          _allModules = modules;
          _filteredModules = _applySearch(_searchController.text, modules);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load modules (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<ModuleModel> _applySearch(String query, List<ModuleModel> modules) {
    final q = query.toLowerCase().trim();

    if (q.isEmpty) return modules;

    return modules.where((module) {
      return module.code.toLowerCase().contains(q) ||
          module.name.toLowerCase().contains(q) ||
          module.location.toLowerCase().contains(q) ||
          module.lecturer.toLowerCase().contains(q) ||
          module.category.toLowerCase().contains(q);
    }).toList();
  }

  void _filterModules() {
    setState(() {
      _filteredModules = _applySearch(_searchController.text, _allModules);
    });
  }

  Widget _bookingReminder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1B8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5D56A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.push_pin,
            size: 24,
            color: Color(0xFFD44220),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F2F2F),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Passed modules cannot be booked\n'
                  'Same core module: max 2 attempts\n'
                  'Only not taken / failed modules allowed\n'
                  'Maximum 2 modules per booking',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvailableClasses(ModuleModel module) async {
    if (module.booked) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableClassesPage(
          module: module,
          studentId: _studentId!,
        ),
      ),
    );

    if (result == true) {
      await fetchModules();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully booked class'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3FC7C4);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              color: primaryColor,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'KoQ Module Booking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const SizedBox(height: 16),
                            _bookingReminder(),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search module...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._filteredModules.map(
                              (module) => ModuleCard(
                                module: module,
                                studentId: _studentId,
                                onTap: () => _openAvailableClasses(module),
                              ),
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

class ModuleCard extends StatelessWidget {
  final ModuleModel module;
  final VoidCallback onTap;
  final int? studentId;

  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF43C7C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '${module.code} ${module.name}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📍 ${module.location}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('👤 ${module.lecturer}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('⚙ ${module.category}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: module.booked || studentId == null ? null : onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: module.booked
                    ? Colors.red
                    : (studentId == null ? Colors.grey : primaryColor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                module.booked
                    ? 'Booked class date: ${module.bookedClassDate ?? "-"}'
                    : (studentId == null ? 'Student session not found' : 'View Date Available'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
