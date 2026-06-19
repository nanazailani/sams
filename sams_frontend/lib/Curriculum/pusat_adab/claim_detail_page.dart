import 'package:flutter/material.dart';

// Page untuk paparkan detail claim / tuntutan
class ClaimDetailPage extends StatelessWidget {
  const ClaimDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold sebagai struktur utama page
    return const Scaffold(
      // Background warna soft grey ikut design theme
      backgroundColor: Color(0xFFF4F2F2),

      body: SafeArea(
        // SafeArea elak content bertindih dengan notch / status bar
        child: Center(
          // Centerkan text di tengah screen
          child: Text(
            'Claim Detail',

            // Styling untuk tajuk page
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
