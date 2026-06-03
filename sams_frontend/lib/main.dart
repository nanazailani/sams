import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sams_frontend/student/mainNavigation.dart' as student_nav;
import 'package:sams_frontend/attendance/lecturer/class.dart';
import 'package:sams_frontend/tuition_fee/treasurer/dashboard_page.dart' as treasurer_page;
import 'package:sams_frontend/faculty_registrar/mainNavigation.dart' as faculty_reg_nav;
import 'package:sams_frontend/pusat_adab/mainNavigation.dart' as pusat_adab_nav;

void main() {
  runApp(const SAMSApp());
}

class SAMSApp extends StatelessWidget {
  const SAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAMS Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Nunito',
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? selectedRole;
  bool isLoading = false;
  bool rememberMe = false;
  bool obscurePassword = true;

  final List<String> roles = [
    'Student',
    'Lecturer',
    'Faculty Registrar',
    'Treasury',
    'Pusat Adab',
  ];

  Future<void> login() async {
    String id = idController.text.trim().toUpperCase();
    String password = passwordController.text.trim();

    String apiRole;
    switch ((selectedRole ?? '').trim().toLowerCase()) {
      case 'student':
        apiRole = 'student';
        break;
      case 'lecturer':
        apiRole = 'lecturer';
        break;
      case 'treasury':
        apiRole = 'treasury';
        break;
      case 'faculty registrar':
        apiRole = 'faculty_registrar';
        break;
      case 'pusat adab':
        apiRole = 'pusat_adab';
        break;
      default:
        apiRole = (selectedRole ?? '').trim().toLowerCase();
    }

    if (id.isEmpty || password.isEmpty || selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter ID, password and select role")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://darkgrey-lyrebird-505549.hostingersite.com/api/login'),
        //Uri.parse('http://127.0.0.1:8000/api/login'),
        //Uri.parse('http://10.62.79.61:8000/api/login'),
        //Uri.parse('http://10.0.2.2:8000/api/login'),

        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id_number': id,
          'password': password,
          'role': apiRole,
        }),
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> data = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('login_id', id);
        await prefs.setString('role', (data['role'] ?? apiRole).toString());

        if (data['user_id'] != null) {
          await prefs.setInt('user_id', int.tryParse(data['user_id'].toString()) ?? 0);
        }

        if (data['student_id'] != null) {
          final parsedStudentId = int.tryParse(data['student_id'].toString());
          if (parsedStudentId != null) {
            await prefs.setInt('student_id', parsedStudentId);
          }
        } else {
          await prefs.remove('student_id');
        }

        if (data['lecturer_id'] != null) {
          final parsedLecturerId = int.tryParse(data['lecturer_id'].toString());
          if (parsedLecturerId != null) {
            await prefs.setInt('lecturer_id', parsedLecturerId);
          }
        } else {
          await prefs.remove('lecturer_id');
        }

        if (data['treasurer_id'] != null) {
          final parsedTreasurerId = int.tryParse(data['treasurer_id'].toString());
          if (parsedTreasurerId != null) {
            await prefs.setInt('treasurer_id', parsedTreasurerId);
          }
        } else {
          await prefs.remove('treasurer_id');
        }

        if (data['pusat_adab_id'] != null) {
          final parsedPusatAdabId = int.tryParse(data['pusat_adab_id'].toString());
          if (parsedPusatAdabId != null) {
            await prefs.setInt('pusat_adab_id', parsedPusatAdabId);
          }
        } else {
          await prefs.remove('pusat_adab_id');
        }

        final resolvedRole = (data['role'] ?? apiRole).toString().trim();
        final normalizedRole = resolvedRole.toLowerCase();

        if (normalizedRole == 'lecturer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ClassPage(),
            ),
          );
        } else if (normalizedRole == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const student_nav.MainNavigation(),
            ),
          );
        } else if (normalizedRole == 'treasury' || normalizedRole == 'treasurer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const treasurer_page.DashboardPage(),
            ),
          );
        } else if (normalizedRole == 'faculty_registrar') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const faculty_reg_nav.MainNavigation(),
            ),
          );
        } else if (normalizedRole == 'pusat_adab' ||
            normalizedRole == 'pusat adab') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const pusat_adab_nav.MainNavigation(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? 'Login successful'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Login failed. Please check your credentials.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to connect to server: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B5BE6),
              Color(0xFF9B8FF5),
              Color(0xFFB8A0FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEAFA),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logoumpsa.png',
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A8C7E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.school, size: 60, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),

                    
                    const SizedBox(height: 6),
                    const Text(
                      'Student Academic Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ID Number field
                    _buildInputField(
                      controller: idController,
                      hintText: 'ID Number',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 14),

                    // Password field
                    _buildPasswordField(),
                    const SizedBox(height: 14),

                    // Category dropdown
                    _buildDropdown(),
                    const SizedBox(height: 14),

                    // Remember Me + Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Checkbox(
                                tristate: false, // ✅ FIXED
                                value: rememberMe,
                                onChanged: (bool? val) {
                                  setState(() {
                                    rememberMe = val == true; // ✅ FIXED
                                  });
                                },
                                activeColor: const Color(0xFF6B5BE6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                side: const BorderSide(color: Color(0xFF9B8FF5)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Remember Me',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B5BE6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B5BE6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF6B5BE6).withOpacity(0.5),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDDD8F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2D2D2D)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF9E9E9E), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDDD8F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2D2D2D)),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline,
              color: Color(0xFF9E9E9E), size: 20),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            child: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF9E9E9E),
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDDD8F5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: selectedRole,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.language,
                color: Color(0xFF9E9E9E), size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 4),
          ),
          hint: const Text(
            'Category',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF9E9E9E)),
          dropdownColor: const Color(0xFFEEEAFA),
          style: const TextStyle(fontSize: 14, color: Color(0xFF2D2D2D)),
          items: roles.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(role),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedRole = value;
            });
          },
        ),
      ),
    );
  }
}
