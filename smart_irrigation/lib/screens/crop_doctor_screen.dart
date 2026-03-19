import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/translations.dart';
import '../core/app_config.dart';
import '../core/globals.dart'; 
import '../widgets/agro_pulse_loader.dart';
import '../widgets/fade_in_slide.dart';

class CropDoctorScreen extends StatefulWidget {
  const CropDoctorScreen({super.key});

  @override
  State<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends State<CropDoctorScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  String? _diagnosisResult;
  Map<String, dynamic>? _diseaseDetails;

  final TextEditingController _currentCropController = TextEditingController();
  String? _searchedCrop;

  bool _isLoadingRecs = false;
  String? _nutrientAnalysis; 
  List<Map<String, dynamic>> _cropRecommendations = [];
  List<Map<String, dynamic>> _fertilizerRecommendations = [];

  final TextEditingController _cropIdeaController = TextEditingController();
  final TextEditingController _fertilizerIdeaController = TextEditingController();

  String _currentLocation = "Locating...";
  String _currentSeason = "Loading...";

  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _determineLocationAndSeason();
  }

  Future<void> _determineLocationAndSeason() async {
    setState(() {
      final month = DateTime.now().month;
      if (month == 2 || month == 3) {
        _currentSeason = "Spring";
      } else if (month >= 4 && month <= 6) {
        _currentSeason = "Summer";
      } else if (month >= 7 && month <= 9) {
        _currentSeason = "Monsoon";
      } else if (month >= 10 && month <= 11) {
        _currentSeason = "Autumn";
      } else {
        _currentSeason = "Winter";
      }
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentLocation = "GPS Disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentLocation = "Permission Denied");
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      if (kIsWeb) {
        try {
          final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1');
          final response = await http.get(url, headers: {'User-Agent': 'AgroPulseApp/1.0'});
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final address = data['address'] ?? {};
            String city = address['city'] ?? address['town'] ?? address['state_district'] ?? 'Unknown City';
            String state = address['state'] ?? '';
            
            if (mounted) {
              setState(() => _currentLocation = "$city, $state".replaceAll(RegExp(r',$'), '').trim());
            }
            return;
          }
        } catch (apiError) {
          debugPrint("OSM Web Geocoding error: $apiError");
        }
        
        if (mounted) {
          setState(() => _currentLocation = "Lat: ${position.latitude.toStringAsFixed(2)}, Lon: ${position.longitude.toStringAsFixed(2)}");
        }

      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          if (mounted) {
            setState(() {
              _currentLocation = "${place.locality ?? place.subLocality ?? 'Unknown'}, ${place.administrativeArea ?? ''}";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Location Error: $e");
      if (mounted) setState(() => _currentLocation = "Location Unavailable");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Camera not directly supported on Web browser. Opening file picker.".tr),
        ),
      );
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _diagnosisResult = null;
          _diseaseDetails = null;
        });
        await _analyzeImage(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() => _isAnalyzing = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://${AppConfig.serverIp}:8000/predict'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'upload.jpg'),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = json.decode(responseData);
        setState(() {
          _diagnosisResult = decoded['diagnosis'];
          _diseaseDetails = decoded['details'];
        });
      } else {
        setState(() => _diagnosisResult = "Error: Server returned ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _diagnosisResult = "Connection Error. Check server IP.");
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _fetchRecommendations() async {
    String crop = _currentCropController.text.trim();
    if (crop.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _searchedCrop = crop;
      _isLoadingRecs = true;
      _nutrientAnalysis = null; 
      _cropRecommendations = [];
      _fertilizerRecommendations = [];
      _cropIdeaController.clear();
      _fertilizerIdeaController.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/recommendations'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "current_crop": crop,
          "language": languageNotifier.value, 
          "location": _currentLocation,
          "season": _currentSeason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nutrientAnalysis = data['nutrient_analysis']; 
          _cropRecommendations = List<Map<String, dynamic>>.from(data['next_crops'] ?? []);
          _fertilizerRecommendations = List<Map<String, dynamic>>.from(data['fertilizers'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("CRITICAL NETWORK ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching recommendations".tr)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRecs = false);
      }
    }
  }

  Widget _buildDetailBox(String title, dynamic content, bool isDark) {
    if (content == null) return const SizedBox.shrink();
    if (content is List && content.isEmpty) return const SizedBox.shrink();
    if (content is String && content.isEmpty) return const SizedBox.shrink();

    String textContent = content is List ? content.map((e) => "• $e").join("\n") : content.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueAccent.withOpacity(0.05) : Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.blueAccent.withOpacity(0.15) : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr,
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 6),
          Text(
            textContent,
            style: TextStyle(
              fontSize: 14, 
              color: isDark ? Colors.grey.shade200 : Colors.black87, 
              height: 1.4
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilImpactCard(String analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFE65100).withOpacity(0.1) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFE65100).withOpacity(0.3) : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Color(0xFFE65100), size: 24),
              const SizedBox(width: 8),
              Text(
                "Soil Nutrient Status".tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: analysis,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
              strong: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSection({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required List<Map<String, dynamic>> recommendations,
    required TextEditingController ideaController,
    required String queryType,
    required String hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void triggerChatUI() {
      if (ideaController.text.trim().isNotEmpty) {
        String query = ideaController.text.trim();
        ideaController.clear();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AIChatBottomSheet(
            currentCrop: _searchedCrop!,
            queryType: queryType,
            initialQuery: query,
            themeColor: color,
            currentLocation: _currentLocation,
            currentSeason: _currentSeason,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title.tr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (recommendations.isNotEmpty) ...[
            Text(
              "Initial AI Suggestions:".tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.check_circle_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              rec['title'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                            if (rec['key_benefit'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  rec['key_benefit'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? color.shade200 : color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: rec['desc'],
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 8),
            Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            const SizedBox(height: 16),
          ],
          
          Text(
            "Ask a question or suggest an idea:".tr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: ideaController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => triggerChatUI(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  onPressed: triggerChatUI,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110.0), // Adjusted height
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0), // Added top margin for Title
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Crop".tr,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Doctor".tr,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueAccent.shade400,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "AI-powered disease prediction, cropping patterns, and fertilizer insights.".tr,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1.0), // Pulled downward slightly
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.blueAccent.shade400),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _currentLocation,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade500), // Increased font size
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentSeason,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.blueAccent.shade400), // Increased font size
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                      Colors.blueAccent.withOpacity(isDark ? 0.08 : 0.2),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      // Adjusted top padding to pull the Leaf Analysis Engine slightly upward
                      padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 50.0, bottom: 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeInSlide(
                            index: 1,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                              decoration: BoxDecoration(
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
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                                    child: Text(
                                      "Leaf Analysis Engine".tr,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).textTheme.bodyLarge!.color,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_imageBytes != null)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2, 
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16), 
                                            child: Image.memory(_imageBytes!, height: 350, fit: BoxFit.cover)
                                          )
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 3,
                                          child: SizedBox(
                                            height: 400,
                                            child: _isAnalyzing
                                                ? Center(child: AgroPulseLoader(message: "Analyzing Leaf...".tr))
                                                : SingleChildScrollView(
                                                    physics: const BouncingScrollPhysics(),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          "Diagnosis:".tr, 
                                                          style: TextStyle(
                                                            fontSize: 14, 
                                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, 
                                                            fontWeight: FontWeight.bold
                                                          )
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          _diagnosisResult ?? "Error".tr,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600, 
                                                            fontSize: 22, 
                                                            color: (_diagnosisResult ?? "").toLowerCase().contains("healthy") 
                                                                ? Colors.green.shade600 
                                                                : const Color(0xFFFF1744)
                                                          ),
                                                        ),
                                                        if (_diseaseDetails != null) ...[
                                                          _buildDetailBox("Type".tr, _diseaseDetails!['type'], isDark),
                                                          if (_diseaseDetails!['remedy'] != null) ...[
                                                            _buildDetailBox("Chemical Control".tr, _diseaseDetails!['remedy']['chemical'], isDark),
                                                            _buildDetailBox("Maintenance".tr, _diseaseDetails!['remedy']['maintenance'], isDark),
                                                            _buildDetailBox("Cultural Control".tr, _diseaseDetails!['remedy']['cultural'], isDark),
                                                            _buildDetailBox("Biological Control".tr, _diseaseDetails!['remedy']['biological'], isDark),
                                                            _buildDetailBox("Notes".tr, _diseaseDetails!['remedy']['notes'], isDark),
                                                          ],
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      height: 400, 
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.05), 
                                        borderRadius: BorderRadius.circular(20), 
                                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.2), width: 2)
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(28),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                            ),
                                            child: Icon(Icons.add_photo_alternate_rounded, size: 64, color: isDark ? Colors.grey.shade400 : Colors.blueAccent.shade400),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            "Upload a photo of the affected leaf\nfor an instant ML diagnosis.".tr, 
                                            textAlign: TextAlign.center, 
                                            style: TextStyle(
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, 
                                              fontSize: 14, 
                                              fontWeight: FontWeight.w600, 
                                              height: 1.5
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _pickImage(ImageSource.camera),
                                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                                          label: Text("Camera".tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent.shade400, 
                                            padding: const EdgeInsets.symmetric(vertical: 20), 
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _pickImage(ImageSource.gallery),
                                          icon: Icon(Icons.photo_library_rounded, color: isDark ? Colors.white : Colors.black87, size: 24),
                                          label: Text("Gallery".tr, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300, width: 1.5), 
                                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 20), 
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          FadeInSlide(
                            index: 2, 
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                "Personalized Recommendations".tr, 
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)
                              ),
                            )
                          ),
                          const SizedBox(height: 16),
                          FadeInSlide(
                            index: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white, 
                                  borderRadius: BorderRadius.circular(16), 
                                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF4CAF50).withOpacity(0.5))
                                ),
                                child: TextField(
                                  controller: _currentCropController,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "Search crop...".tr,
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.search_rounded, color: isDark ? Colors.grey.shade400 : const Color(0xFF2E7D32), size: 28), 
                                      onPressed: _fetchRecommendations
                                    ),
                                  ),
                                  onSubmitted: (_) => _fetchRecommendations(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_isLoadingRecs)
                            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: AgroPulseLoader()))
                          else if (_searchedCrop != null) ...[
                            if (_nutrientAnalysis != null && _nutrientAnalysis!.isNotEmpty)
                              FadeInSlide(index: 4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildSoilImpactCard(_nutrientAnalysis!))),
                            FadeInSlide(
                              index: 5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildInteractiveSection(
                                  title: "Next Crop Strategy".tr,
                                  icon: Icons.local_florist_rounded,
                                  color: Colors.purple,
                                  recommendations: _cropRecommendations,
                                  ideaController: _cropIdeaController,
                                  queryType: 'crop',
                                  hintText: "E.g., Can I plant Barley next?".tr,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FadeInSlide(
                              index: 6,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildInteractiveSection(
                                  title: "Fertilizer Strategy".tr,
                                  icon: Icons.science_rounded,
                                  color: Colors.teal,
                                  recommendations: _fertilizerRecommendations,
                                  ideaController: _fertilizerIdeaController,
                                  queryType: 'fertilizer',
                                  hintText: "E.g., Will organic compost be enough?".tr,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
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

// -----------------------------------------------------------------------------
// CHAT BOTTOM SHEET WIDGET (Handles Multi-Turn Conversational Memory)
// -----------------------------------------------------------------------------
class AIChatBottomSheet extends StatefulWidget {
  final String currentCrop;
  final String queryType;
  final String initialQuery;
  final MaterialColor themeColor;
  final String currentLocation;
  final String currentSeason;

  const AIChatBottomSheet({
    super.key,
    required this.currentCrop,
    required this.queryType,
    required this.initialQuery,
    required this.themeColor,
    required this.currentLocation,
    required this.currentSeason,
  });

  @override
  State<AIChatBottomSheet> createState() => _AIChatBottomSheetState();
}

class _AIChatBottomSheetState extends State<AIChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _sendMessage(widget.initialQuery);
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _chatHistory.add({'role': 'user', 'content': message});
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    List<Map<String, String>> historyToSend = _chatHistory
        .where((msg) => msg['role'] != 'error')
        .map((msg) => {
              'role': msg['role'] as String,
              'content': msg['role'] == 'user'
                  ? msg['content'] as String
                  : (msg['data'] != null ? msg['data']['feedback'] as String : '')
            })
        .toList();
    if (historyToSend.isNotEmpty) historyToSend.removeLast();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/consult_ai'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "current_crop": widget.currentCrop,
          "query_type": widget.queryType,
          "user_query": message,
          "chat_history": historyToSend,
          "language": languageNotifier.value,
          "location": widget.currentLocation,
          "season": widget.currentSeason,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _chatHistory.add({'role': 'model', 'data': data}));
      } else {
        setState(() => _chatHistory.add({'role': 'error', 'content': 'Server Error: ${response.statusCode}'}));
      }
    } catch (e) {
      setState(() => _chatHistory.add({'role': 'error', 'content': 'Connection Error. Please try again.'}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.queryType == 'crop' ? Icons.grass_rounded : Icons.science_rounded, color: widget.themeColor),
                    const SizedBox(width: 8),
                    Text(
                      "${widget.queryType == 'crop' ? 'Crop' : 'Fertilizer'} Strategy Chat".tr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _chatHistory.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _chatHistory.length) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: AgroPulseLoader()));
                }
                
                final msg = _chatHistory[index];
                final isUser = msg['role'] == 'user';
                final isError = msg['role'] == 'error';

                if (isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12, left: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.themeColor,
                        borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
                      ),
                      child: Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  );
                } else if (isError) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(msg['content'], textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade400)),
                  );
                } else {
                  final data = msg['data'];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12, right: 40),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: data['feedback'] ?? "",
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).textTheme.bodyMedium!.color),
                              strong: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                          ),
                          if (data['better_alternative'] != null && data['better_alternative'].toString().isNotEmpty && data['better_alternative'].toString().toLowerCase() != "null") ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Alternative Suggestion:".tr, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                  const SizedBox(height: 6),
                                  MarkdownBody(
                                    data: data['better_alternative'],
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(fontSize: 13, height: 1.3, color: Theme.of(context).textTheme.bodyMedium!.color),
                                      strong: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16, 
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a follow-up question...".tr,
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: isDark ? Colors.black12 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(_messageController.text),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: widget.themeColor,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}