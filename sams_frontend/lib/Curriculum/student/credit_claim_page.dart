import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CreditClaimPage extends StatefulWidget {
  const CreditClaimPage({super.key});

  @override
  State<CreditClaimPage> createState() => _CreditClaimPageState();
}

class _CreditClaimPageState extends State<CreditClaimPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  int? _studentId;
  List<dynamic> _claims = [];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getInt('student_id');
    await fetchClaims();
  }

  Future<void> fetchClaims() async {
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
        Uri.parse(
          'http://10.0.2.2:8000/api/modules/credit-claims?student_id=$_studentId',
        ),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _claims = decoded['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = decoded['message'] ?? 'Failed to load claim list';
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

  Future<void> submitClaim(int registrationId) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/modules/credit-claims/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'registration_id': registrationId,
          'student_id': _studentId,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && decoded['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Credit claim submitted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchClaims();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Unable to submit claim'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IN PROGRESS':
        return const Color(0xFFFFA726);
      case 'APPROVED':
        return const Color(0xFF20BF6B);
      case 'REJECTED':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF7D8797);
    }
  }

  String actionText(Map<String, dynamic> item) {
    final String status =
        (item['claim_status'] ?? '--').toString().toUpperCase();
    final bool canClaim = item['can_claim'] == true;

    if (status == 'APPROVED') return 'Successfully Claimed';
    if (status == 'IN PROGRESS') return 'In Progress';
    if (status == 'REJECTED') return 'Rejected';
    if (item['class_ended'] == false) return 'Available After Class Ends';
    if (!canClaim) return 'Not Eligible';

    return 'Claim Now';
  }
  
  Color actionColor(Map<String, dynamic> item) {
    final String status = (item['claim_status'] ?? '--').toString().toUpperCase();

    if (status == 'IN PROGRESS') {
      return const Color(0xFFFFA726);
    }
    if (status == 'REJECTED') {
      return const Color(0xFFEF4444);
    }
    if (canTapClaim(item)) return const Color(0xFF3FC7C4);

    return const Color(0xFF9AA4B2);
  }

  bool canTapClaim(Map<String, dynamic> item) {
    final String status =
        (item['claim_status'] ?? '--').toString().toUpperCase();

    return status == '--' && item['can_claim'] == true;
  }
  Widget _buildHeader() {
    const primaryColor = Color(0xFF3FC7C4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'List of Subject',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E2A9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📌 Reminder',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Please make sure your secondary email can receive emails.\n'
            'Claim updates will be sent to Notifications.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> item) {
    final String status = (item['claim_status'] ?? '--').toString().toUpperCase();

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
            '${item['code']} ${item['name']}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 2,
            color: Colors.black,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Status : ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canTapClaim(item)
                  ? () => submitClaim(item['registration_id'])
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor(item),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                actionText(item),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
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
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : RefreshIndicator(
                          onRefresh: fetchClaims,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildReminderCard(),
                              const SizedBox(height: 16),
                              if (_claims.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 60),
                                  child: Center(
                                    child: Text(
                                      'No module available for credit claim yet',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._claims.map(
                                  (item) => _buildClaimCard(
                                    item as Map<String, dynamic>,
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
