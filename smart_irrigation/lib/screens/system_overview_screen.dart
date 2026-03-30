import 'package:flutter/material.dart';
import '../core/translations.dart';
import '../widgets/fade_in_slide.dart';
import 'dashboard_screen.dart'; // Make sure this points to your dashboard

class SystemOverviewScreen extends StatelessWidget {
  const SystemOverviewScreen({super.key});

  Widget _buildWorkflowStep({
    required BuildContext context,
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Step $stepNumber".tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).iconTheme.color),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0), 
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    index: 0,
                    child: Text(
                      "System Workflow".tr,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInSlide(
                    index: 1,
                    child: Text(
                      "Welcome to your farm's digital companion. Here is how AgroSync works to maximize your yield.".tr,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  FadeInSlide(
                    index: 2,
                    child: _buildWorkflowStep(
                      context: context,
                      stepNumber: "1",
                      title: "Monitor & Automate",
                      description: "Track real-time data from your sensors and let the system automate irrigation.",
                      icon: Icons.dashboard_customize_rounded,
                      iconColor: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                  
                  FadeInSlide(
                    index: 3,
                    child: _buildWorkflowStep(
                      context: context,
                      stepNumber: "2",
                      title: "Diagnose Crop Health",
                      description: "Upload an image of a sick plant to the Crop Doctor for instant AI treatment recommendations.",
                      icon: Icons.medical_services_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                  ),

                  FadeInSlide(
                    index: 4,
                    child: _buildWorkflowStep(
                      context: context,
                      stepNumber: "3",
                      title: "Trade & Profit",
                      description: "Check live market prices and demand trends to sell your produce at the best time.",
                      icon: Icons.storefront_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation Button to the actual Dashboard
                  FadeInSlide(
                    index: 5,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Push replacement so the user can't "back" into the overview during normal app usage
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const DashboardScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Enter Dashboard".tr,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}