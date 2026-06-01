import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await AuthSession.load();
    if (!mounted) return;

    if (AuthSession.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: AuthSession.user!),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 72,
              color: Color(0xFF075DCC),
            ),
            SizedBox(height: 20),
            Text(
              'Container Inspection',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Inspection Management System',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF667085),
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Color(0xFF075DCC)),
          ],
        ),
      ),
    );
  }
}
