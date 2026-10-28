import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_toolkit/screen/home_screen.dart';
import 'package:pdf_toolkit/screen/onboarding_screen.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // গুগলের গাইডলাইন মেনে সিস্টেম বারগুলো স্বচ্ছ রাখা
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _startApp();
  }

  Future<void> _startApp() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    await Future.wait([
      AdHelper.preLoadAds(),
      Future.delayed(const Duration(seconds: 2)), // Flutter Splash Duration: 2s
    ]);

    if (mounted) {
      if (hasSeenOnboarding) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121216)
          : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "PDF Quant",
              style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 64),
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              "Loading resources...",
              style: TextStyle(
                color: theme.hintColor.withAlpha(150),
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
