import 'dart:ui';
import 'package:flutter/material.dart';

import 'auth_screen.dart'; // Added import for the Login/Auth screen

class MarketModelScreen extends StatelessWidget {
  const MarketModelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge!.color),
        title: Text(
          "Pricing & Plans",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).textTheme.bodyLarge!.color,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
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
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHero(isDark, context),
                      const SizedBox(height: 64),
                      _buildHowToStart(isDark, context),
                      const SizedBox(height: 80),
                      _buildPricingSection(isDark, context),
                      const SizedBox(height: 80),
                      _buildBottomCTA(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO SECTION ───
  Widget _buildHero(bool isDark, BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            'Simple, Transparent Pricing',
            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Farming Smarter, Made Affordable",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).textTheme.bodyLarge!.color,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "No hidden fees. A one-time hardware setup gets you started, and our software plans are designed to scale with your farm's needs.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.5),
        ),
      ],
    );
  }

  // ─── HOW TO GET STARTED ───
  Widget _buildHowToStart(bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "How AgroSync Works",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final steps = [
            {
              'icon': Icons.memory,
              'title': '1. Get the Hardware',
              'desc': 'A one-time investment. We ship our custom IoT sensor kit directly to your farm. Easy plug-and-play installation with no recurring equipment rental fees.'
            },
            {
              'icon': Icons.phone_android,
              'title': '2. Connect the App',
              'desc': 'Download AgroSync and link your sensors. Instantly get access to our Free Tier, which includes the community forum, crop doctor, and basic sensor dashboard.'
            },
            {
              'icon': Icons.workspace_premium,
              'title': '3. Upgrade to Premium',
              'desc': 'When you are ready to automate irrigation, control shade nets, and get AI market predictions, upgrade to our low-cost yearly subscription to maximize profits.'
            },
          ];

          final stepWidgets = steps.map((step) => Expanded(
            flex: isWide ? 1 : 0,
            child: Container(
              margin: EdgeInsets.only(bottom: isWide ? 0 : 24, right: isWide ? 16 : 0, left: isWide ? 16 : 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(step['icon'] as IconData, color: const Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(step['title'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color)),
                  const SizedBox(height: 12),
                  Text(step['desc'] as String, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                ],
              ),
            ),
          )).toList();

          return isWide 
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: stepWidgets)
            : Column(children: stepWidgets);
        }),
      ],
    );
  }

  // ─── PRICING PLANS ───
  Widget _buildPricingSection(bool isDark, BuildContext context) {
    return Column(
      children: [
        Text(
          "Choose Your Software Plan",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
        ),
        const SizedBox(height: 16),
        Text(
          "Hardware kit required for both plans.",
          style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        const SizedBox(height: 40),
        
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          
          final freePlan = _buildPricingCard(
            isDark: isDark,
            title: "Essential",
            price: "Free",
            subtitle: "Forever",
            desc: "Everything you need to monitor your farm and learn from the community.",
            // Free Features (1, 3, 4, 5, 10)
            features: [
              "Live Sensor Monitoring",
              "Automated Irrigation Control",
              "Manual Irrigation Override",
              "Crop Doctor (Disease Prediction)",
              "Community Forum",
            ],
            isPremium: false,
            buttonText: "Start Free",
            // REDIRECT TO LOGIN PAGE
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
            },
          );

          final premiumPlan = _buildPricingCard(
            isDark: isDark,
            title: "AgroSync Pro",
            price: "₹999",
            subtitle: "/ year",
            desc: "Full AI insights and physical farm automation to maximize your profitability.",
            // Pro Features (2, 6, 7, 8, 9, 11)
            features: [
              "Everything in Essential, plus:",
              "ML-Predicted Water Requirements",
              "Cropping Pattern Recommendations",
              "Fertilizer Recommendations",
              "Predicted Future Market Prices",
              "Live Market Prices",
              "Automatic Shade Deployment",
            ],
            isPremium: true,
            buttonText: "Subscribe Now",
            onPressed: () {
              // Add checkout/payment navigation here in the future
            },
          );

          if (isWide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Expanded(child: freePlan),
                const SizedBox(width: 32),
                Expanded(child: premiumPlan),
              ],
            );
          } else {
            return Column(
              children: [
                freePlan,
                const SizedBox(height: 32),
                premiumPlan,
              ],
            );
          }
        }),
      ],
    );
  }

  Widget _buildPricingCard({
    required bool isDark,
    required String title,
    required String price,
    required String subtitle,
    required String desc,
    required List<String> features,
    required bool isPremium,
    required String buttonText,
    required VoidCallback onPressed, // Added this parameter
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isPremium 
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isPremium ? const Color(0xFF10B981) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          width: isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium ? const Color(0xFF10B981).withOpacity(0.1) : Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(100)),
              child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Conditionally blur ONLY if it is the premium price
              isPremium
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
                      child: Text(price, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                    )
                  : Text(price, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(width: 8),
              Text(subtitle, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(desc, style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed, // Using the new parameter here
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? const Color(0xFF10B981) : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100),
                foregroundColor: isPremium ? Colors.white : (isDark ? Colors.white : Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: isPremium ? const Color(0xFF10B981) : Colors.grey.shade400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f, 
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: f.startsWith("Everything in") ? FontWeight.bold : FontWeight.normal,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700
                    )
                  )
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // ─── BOTTOM CTA FOR HARDWARE ───
  Widget _buildBottomCTA(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF10B981)),
          const SizedBox(height: 24),
          const Text(
            "Ready to deploy AgroSync on your farm?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Order your IoT hardware kit today. It includes all necessary sensors (Soil, Temp, Humidity, Rain, LDR, Depth) and the main control hub.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart),
                const SizedBox(width: 8),
                const Text("Order Hardware Kit - ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                // Blurring the price figure in the CTA button using ImageFiltered
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: const Text("₹4,999", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}