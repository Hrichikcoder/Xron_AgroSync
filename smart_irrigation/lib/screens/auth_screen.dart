import 'dart:developer';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'otp_screen.dart';
import '../core/app_config.dart';
import '../widgets/fade_in_slide.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  Offset _mousePosition = Offset.zero;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://${AppConfig.serverIp}:8000/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phone,
          'is_register': false 
        }),
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              phoneNumber: phone,
            ),
          ),
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    // 1. Check mandatory fields (Name and Phone only)
    if (phone.length < 10 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your Name and Phone Number')),
      );
      return;
    }

    // 2. Validate email syntax ONLY if it is provided
    if (email.isNotEmpty) {
      final bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
      if (!emailValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address (e.g., name@domain.com)')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://${AppConfig.serverIp}:8000/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phone,
          'name': name,
          'email': email, // this will pass an empty string if left blank
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please sign in.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        
        _nameController.clear();
        _emailController.clear();
        setState(() {
          _isLogin = true;
        });
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to register');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mousePosition = event.localPosition;
          });
        },
        child: Stack(
          children: [
            // 1. Animated Gradient Background
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
            // 2. Mouse Tracking Orb
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
            // 3. Glassmorphism Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 4. Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeInSlide(
                            index: 0,
                            child: Column(
                              children: [
                                Image.asset('assets/plant_icon.png', height: 80),
                                const SizedBox(height: 16),
                                Text(
                                  _isLogin ? 'Welcome Back' : 'Create Account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black87,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isLogin 
                                      ? 'Enter your phone number to sign in' 
                                      : 'Fill out the form below to register',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Segmented Control Toggle
                          FadeInSlide(
                            index: 1,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLogin = true),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: _isLogin ? (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: _isLogin 
                                              ? [BoxShadow(color: (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Sign In",
                                            style: TextStyle(
                                              fontSize: 15, 
                                              fontWeight: FontWeight.bold, 
                                              color: _isLogin ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLogin = false),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: !_isLogin ? (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: !_isLogin 
                                              ? [BoxShadow(color: (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Sign Up", 
                                            style: TextStyle(
                                              fontSize: 15, 
                                              fontWeight: FontWeight.bold, 
                                              color: !_isLogin ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Form Fields
                          if (!_isLogin) ...[
                            FadeInSlide(
                              index: 2,
                              child: _buildTextField(
                                label: 'Full Name',
                                hint: 'e.g. John Doe',
                                icon: Icons.person_rounded,
                                controller: _nameController,
                                isDark: isDark,
                                keyboardType: TextInputType.name,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeInSlide(
                              index: 3,
                              child: _buildTextField(
                                label: 'Email Address (Optional)',
                                hint: 'e.g. farmer@agrosync.com',
                                icon: Icons.email_rounded,
                                controller: _emailController,
                                isDark: isDark,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          FadeInSlide(
                            index: _isLogin ? 2 : 4,
                            child: _buildTextField(
                              label: 'Phone Number',
                              hint: '10-digit mobile number',
                              icon: Icons.phone_rounded,
                              controller: _phoneController,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ',
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Action Button
                          FadeInSlide(
                            index: _isLogin ? 3 : 5,
                            child: ElevatedButton(
                              onPressed: _isLoading 
                                  ? null 
                                  : (_isLogin ? _sendOtp : _registerUser), 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF064E3B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xFF064E3B).withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : Text(
                                      _isLogin ? 'Send OTP' : 'Create Account', 
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }
}