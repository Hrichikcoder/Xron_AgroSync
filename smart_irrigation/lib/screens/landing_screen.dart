import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/translations.dart';
import '../widgets/fade_in_slide.dart';
import 'auth_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  Offset _mousePosition = Offset.zero;

  // --- UI Builders ---

  Widget _buildHeroSection(bool isDark) {
    return Container(
      width: double.infinity,
      height: 600,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        image: DecorationImage(
          image: const NetworkImage(
              'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?q=80&w=1200&auto=format&fit=crop'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.darken,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
              children: [
                const TextSpan(text: "Every Crop Has a Story - Hear It with AgroSync", style: TextStyle(fontSize: 60)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "AgroSync helps you make better decisions at every stage - from watering and crop health to choosing crops and selling for maximum profit.".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              "Get Started".tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutUsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            "Our Mission & Goals".tr,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge!.color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Our mission is to support farmers with a smart, easy-to-use digital companion that guides them through every step of farming with confidence. By combining AI and IoT, we aim to help farmers use water wisely, monitor crop health, and make better decisions without relying on guesswork. We strive to improve productivity while reducing effort and risk. At the same time, we focus on helping farmers earn more by providing timely market insights and better selling opportunities. Beyond technology, we want to build a strong, supportive community where farmers can share experiences, learn from each other, and grow together."
                .tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      String title, String subtitle, String description, IconData icon, String imageUrl, bool isDark) {
    return Container(
      width: 320, 
      height: 460, 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F4F8), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Icon(icon, color: Colors.white, size: 28), 
                ),
                const SizedBox(height: 16), 
                Text(
                  title.tr,
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle.tr,
                  style: const TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFF10B981)
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description.tr,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            // MODIFIED: Changed from Image.network to Image.asset
            child: Image.asset(
              imageUrl,
              height: 140, 
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "Platform Features".tr,
            style: TextStyle(
              fontSize: 36, 
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge!.color,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              const SizedBox(width: 8), 
              _buildFeatureCard(
                "Community Forum",
                "🌱 Learn Together, Grow Together",
                "Connect with farmers, share real problems, and discover practical solutions. Learn from others' experiences, get advice, and build a supportive network that helps you make better farming decisions.",
                Icons.forum_rounded,
                // MODIFIED: Replaced URL with asset path
                "assets/community_feature.jpg", 
                isDark,
              ),
              const SizedBox(width: 24),
              _buildFeatureCard(
                "Smart Automation",
                "🤖 Farming That Works for You",
                "Automate irrigation and farm operations using real-time sensor data. Save water, reduce manual effort, and ensure your crops receive the right care at the right time without constant monitoring.",
                Icons.memory_rounded,
                // MODIFIED: Replaced URL with asset path
                "assets/automation_feature.jpg", 
                isDark,
              ),
              const SizedBox(width: 24),
              _buildFeatureCard(
                "Crop Doctor",
                "🌿 Know Your Crop’s Health Instantly",
                "Upload crop images to detect diseases early and receive simple treatment guidance. Prevent damage, improve crop health, and take timely action with AI-powered insights tailored to your farm.",
                Icons.healing_rounded,
                // MODIFIED: Replaced URL with asset path
                "assets/crop_doctor_feature.jpg", 
                isDark,
              ),
              const SizedBox(width: 24),
              _buildFeatureCard(
                "Market Engine",
                "📈 Sell at the Right Time, Every Time",
                "Track live market prices and demand trends to make informed selling decisions. Choose the best time and place to sell your produce and maximize profits with data-driven insights.",
                Icons.trending_up_rounded,
                // MODIFIED: Replaced URL with asset path
                "assets/market_feature.jpg", 
                isDark,
              ),
              const SizedBox(width: 8), 
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJourneyStep(String stepNumber, String title, String description, IconData icon, bool isDark) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -10,
            top: -20,
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                height: 1.0,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF10B981)),
              const SizedBox(height: 24),
              Text(
                title.tr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description.tr,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "How AgroSync Works".tr,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).textTheme.bodyLarge!.color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "See how AgroSync transforms your farm step by step, turning real-time data into smarter decisions, better crop care, and higher profits.".tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _buildJourneyStep(
              "1",
              "Register & Setup",
              "Get started in minutes. Create your profile, add your farm location, and select your crops to unlock personalized insights from day one.",
              Icons.app_registration_rounded,
              isDark,
            ),
            _buildJourneyStep(
              "2",
              "Sync Hardware",
              "Connect your sensors seamlessly to start capturing real-time data on soil, weather, and field conditions - no technical hassle required.",
              Icons.wifi_tethering_rounded,
              isDark,
            ),
            _buildJourneyStep(
              "3",
              "Monitor & Automate",
              "Track your farm live and automate irrigation based on smart conditions - saving water, time, and effort while improving crop health.",
              Icons.dashboard_customize_rounded,
              isDark,
            ),
            _buildJourneyStep(
              "4",
              "Harvest & Profit",
              "Make smarter selling decisions with live market insights, demand trends, and community discussions to expand reach and maximize your earnings.",
              Icons.monetization_on_rounded,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSdgBox(String number, String title, IconData icon, Color color) {
    return Container(
      width: 150, 
      height: 150, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0), 
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1), 
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Icon(icon, color: Colors.white, size: 56), 
          ),
        ],
      ),
    );
  }

  Widget _buildSdgBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.public, color: Colors.white, size: 40), 
              const SizedBox(width: 16),
              Text(
                "Sustainable Development Goals".tr,
                style: const TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "AgroSync is committed to building a sustainable future aligned with the United Nations.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18, 
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 48),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSdgBox("2", "ZERO\nHUNGER", Icons.soup_kitchen_rounded, const Color(0xFFDDA63A)),
                const SizedBox(width: 16),
                _buildSdgBox("6", "CLEAN WATER\nAND SANITATION", Icons.water_drop_rounded, const Color(0xFF26BDE2)),
                const SizedBox(width: 16),
                _buildSdgBox("8", "DECENT WORK AND\nECONOMIC GROWTH", Icons.trending_up_rounded, const Color(0xFFA21942)),
                const SizedBox(width: 16),
                _buildSdgBox("9", "INDUSTRY, INNOVATION\n& INFRASTRUCTURE", Icons.precision_manufacturing_rounded, const Color(0xFFFD6925)),
                const SizedBox(width: 16),
                _buildSdgBox("13", "CLIMATE\nACTION", Icons.public_rounded, const Color(0xFF3F7E44)),
                const SizedBox(width: 16),
                _buildSdgBox("17", "PARTNERSHIPS\nFOR THE GOALS", Icons.handshake_rounded, const Color(0xFF19486A)),
              ],
            ),
          ),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/plant_icon.png', height: 48), 
            const SizedBox(width: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: -0.5,
                  fontSize: 42, 
                ),
                children: [
                  const TextSpan(text: "Agro"),
                  TextSpan(text: "Sync", style: TextStyle(color: Colors.greenAccent.shade700)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen()));
            },
            child: Text("Sign In".tr, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0), 
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Sign Up".tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mousePosition = event.localPosition;
          });
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                      : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOutQuad,
              left: _mousePosition.dx - 300,
              top: _mousePosition.dy - 300,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0), 
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400), 
                    child: Column(
                      children: [
                        FadeInSlide(index: 0, child: _buildHeroSection(isDark)),
                        const SizedBox(height: 80), 
                        FadeInSlide(index: 1, child: _buildAboutUsSection(isDark)),
                        const SizedBox(height: 100), 
                        FadeInSlide(index: 2, child: _buildFeaturesSection(isDark)),
                        const SizedBox(height: 120), 
                        FadeInSlide(index: 3, child: _buildJourneySection(isDark)), 
                        const SizedBox(height: 120), 
                        FadeInSlide(index: 4, child: _buildSdgBanner()), 
                        const SizedBox(height: 100), 
                        
                        Divider(color: isDark ? Colors.white24 : Colors.black12),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0), 
                          child: Text(
                            "© 2026 AgroSync by Team XRON. All rights reserved.",
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}