import 'package:flutter/material.dart';
import '../core/translations.dart';
import '../widgets/agro_pulse_loader.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          // 1. We wrap the Column in a SingleChildScrollView
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(), 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/plant_icon.png',
                  width: 250, 
                  height: 250,
                  fit: BoxFit.contain,
                ),
                                
                // Name "AgroSync" below the image
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      letterSpacing: -0.8,
                    ),
                    children: [
                      const TextSpan(
                        text: "A",
                        style: TextStyle(fontSize: 60), 
                      ),
                      const TextSpan(
                        text: "gro",
                        style: TextStyle(fontSize: 48),
                      ),
                      TextSpan(
                        text: "Sync",
                        style: TextStyle(
                          fontSize: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reduced from 48 down to 4
                const SizedBox(height: 4),
                
                // The subtitle under the name
                Text(
                  "SMART FARM INTELLIGENCE".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                // Reduced from 60 down to 16
                const SizedBox(height: 16),
                
                // Loading icon
                const AgroPulseLoader(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}