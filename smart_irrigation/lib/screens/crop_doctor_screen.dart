import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/translations.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/fade_in_slide.dart';

class CropDoctorScreen extends StatefulWidget {
  const CropDoctorScreen({super.key});

  @override
  State<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends State<CropDoctorScreen> {
  Offset _mousePosition = Offset.zero;

  // Primary Blue Theme for this page
  final Color _primaryBlue = Colors.blueAccent.shade400;

  // Image Picker Data
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isAnalyzing = false;
  bool _hasResults = false;

  // Chat Controllers
  final TextEditingController _croppingController = TextEditingController();
  final TextEditingController _fertilizerController = TextEditingController();

  @override
  void dispose() {
    _croppingController.dispose();
    _fertilizerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
          _hasResults = false; // Reset results when a new image is picked
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _hasResults = false;
    });
  }

  void _runAnalysis() {
    setState(() {
      _isAnalyzing = true;
    });
    
    // Simulate network delay for AI analysis
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _hasResults = true;
        });
      }
    });
  }

  BoxDecoration _glassCardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
      borderRadius: BorderRadius.circular(24),
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
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.biotech_rounded, color: _primaryBlue, size: 36),
              const SizedBox(width: 12),
              Text(
                "Crop Doctor".tr,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "AI-powered disease prediction, cropping patterns, and fertilizer insights.".tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile == null) return const SizedBox.shrink();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: kIsWeb
          ? Image.network(_imageFile!.path, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
          : Image.file(File(_imageFile!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
    );
  }

  Widget _buildLeafAnalysisCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: _primaryBlue, size: 24),
              const SizedBox(width: 12),
              Text(
                "Leaf Analysis Engine".tr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Modern Dropzone / Preview Area
          Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : _primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : _primaryBlue.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_imageFile != null)
                  Positioned.fill(child: _buildImagePreview())
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 48,
                          color: isDark ? Colors.grey.shade400 : _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Upload a photo of the affected leaf\nfor an instant ML diagnosis.".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                
                if (_imageFile != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: _clearImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Camera and Gallery Buttons (or Analyze Button)
          if (_imageFile == null)
            Row(
              children: [
                Expanded(
                  child: BouncingButton(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Camera".tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: BouncingButton(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Gallery".tr,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge!.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            BouncingButton(
              onTap: _isAnalyzing ? () {} : _runAnalysis,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _isAnalyzing ? Colors.grey.shade500 : Colors.greenAccent.shade700,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isAnalyzing ? [] : [
                    BoxShadow(
                      color: Colors.greenAccent.shade700.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isAnalyzing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    else
                      const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _isAnalyzing ? "Analyzing Leaf Data...".tr : "Analyze Image".tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          const SizedBox(height: 32),
          Divider(color: isDark ? Colors.white24 : Colors.black12, thickness: 1),
          const SizedBox(height: 24),
          
          // Dedicated space for the reply from the analysis engine
          Text(
            "Diagnosis Results".tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              ),
            ),
            child: _hasResults
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent.shade400),
                          const SizedBox(width: 8),
                          Text(
                            "Early Blight Detected".tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Confidence Score: 92%\n\nRecommendation: Apply a copper-based fungicide and ensure proper spacing between plants to improve air circulation. Avoid overhead watering to keep foliage dry.".tr,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 32,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Awaiting image upload for analysis.\nResults and treatments will appear here.".tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultantCard(bool isDark, String title, String hintText, IconData icon, TextEditingController controller) {
    return Container(
      height: 450, // Fixed height so they align perfectly side-by-side
      padding: const EdgeInsets.all(24),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryBlue, size: 24),
              const SizedBox(width: 12),
              Text(
                title.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Chat Placeholder Area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum_rounded,
                      size: 40,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Provide your farm details below.\nThe AI consultant is ready to assist you.".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Modern Text Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.4) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText.tr,
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      // TODO: Implement AI Chat logic
                    },
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _mousePosition = event.localPosition;
          });
        },
        child: Stack(
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
            
            // Dynamic Mouse Glow Effect
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
                      Colors.blueAccent.withOpacity(isDark ? 0.08 : 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Frosted Glass Layer over the background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeInSlide(index: 0, child: _buildHeader(isDark)),
                        
                        FadeInSlide(
                          index: 1,
                          child: _buildLeafAnalysisCard(isDark),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        FadeInSlide(
                          index: 2,
                          child: isDesktop
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _buildConsultantCard(
                                        isDark, 
                                        "Cropping Pattern", 
                                        "Describe soil, season, and climate...", 
                                        Icons.grid_view_rounded,
                                        _croppingController
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildConsultantCard(
                                        isDark, 
                                        "Fertilizer Recommendation", 
                                        "Enter crop type and soil conditions...", 
                                        Icons.science_rounded,
                                        _fertilizerController
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildConsultantCard(
                                      isDark, 
                                      "Cropping Pattern", 
                                      "Describe soil, season, and climate...", 
                                      Icons.grid_view_rounded,
                                      _croppingController
                                    ),
                                    const SizedBox(height: 24),
                                    _buildConsultantCard(
                                      isDark, 
                                      "Fertilizer Recommendation", 
                                      "Enter crop type and soil conditions...", 
                                      Icons.science_rounded,
                                      _fertilizerController
                                    ),
                                  ],
                                ),
                        ),
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