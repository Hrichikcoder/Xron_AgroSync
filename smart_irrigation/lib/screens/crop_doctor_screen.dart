import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/translations.dart';
import '../core/app_config.dart';
import '../core/globals.dart'; // NEW IMPORT FOR LANGUAGE STATE
import '../widgets/agro_pulse_loader.dart';
import '../widgets/bouncing_button.dart';
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
  bool _isEvaluatingCrop = false;
  Map<String, dynamic>? _cropFeedbackData; 

  final TextEditingController _fertilizerIdeaController = TextEditingController();
  bool _isEvaluatingFertilizer = false;
  Map<String, dynamic>? _fertilizerFeedbackData; 

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Camera not directly supported on Web browser. Opening file picker."
                .tr,
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://${AppConfig.serverIp}:8000/predict'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'upload.jpg',
        ),
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
        setState(() {
          _diagnosisResult = "Error: Server returned ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _diagnosisResult = "Connection Error. Check server IP.";
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
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
      _cropFeedbackData = null; 
      _fertilizerFeedbackData = null; 
      _cropIdeaController.clear();
      _fertilizerIdeaController.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/recommendations'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "current_crop": crop,
          "language": languageNotifier.value, // SENDING LANGUAGE TO BACKEND
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nutrientAnalysis = data['nutrient_analysis']; 
          _cropRecommendations =
              List<Map<String, dynamic>>.from(data['next_crops'] ?? []);
          _fertilizerRecommendations =
              List<Map<String, dynamic>>.from(data['fertilizers'] ?? []);
        });
      }
    } catch (e) {
      print("CRITICAL NETWORK ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching recommendations".tr)),
      );
    } finally {
      setState(() {
        _isLoadingRecs = false;
      });
    }
  }

  Future<void> _evaluateIdea(String type) async {
    if (_searchedCrop == null) return;

    bool isCrop = type == 'crop';
    String query = isCrop
        ? _cropIdeaController.text.trim()
        : _fertilizerIdeaController.text.trim();

    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      if (isCrop) {
        _isEvaluatingCrop = true;
      } else {
        _isEvaluatingFertilizer = true;
      }
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/consult_ai'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "current_crop": _searchedCrop,
          "query_type": type,
          "user_query": query,
          "language": languageNotifier.value, // SENDING LANGUAGE TO BACKEND
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (isCrop) {
            _cropFeedbackData = data; 
            _cropIdeaController.clear();
          } else {
            _fertilizerFeedbackData = data; 
            _fertilizerIdeaController.clear();
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error consulting AI".tr)),
      );
    } finally {
      setState(() {
        if (isCrop) {
          _isEvaluatingCrop = false;
        } else {
          _isEvaluatingFertilizer = false;
        }
      });
    }
  }

  Widget _buildDetailSection(String title, dynamic content) {
    if (content == null) return const SizedBox.shrink();
    if (content is List && content.isEmpty) return const SizedBox.shrink();
    if (content is String && content.isEmpty) return const SizedBox.shrink();

    String textContent = "";
    if (content is List) {
      textContent = content.map((e) => "• $e").join("\n");
    } else {
      textContent = content.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            textContent,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilImpactCard(String analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.brown.withOpacity(0.2) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.brown.shade700 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.landscape_rounded,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Soil Nutrient Status".tr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  analysis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              ],
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
    required bool isEvaluating,
    required Map<String, dynamic>? aiFeedbackData,
    required VoidCallback onEvaluate,
    required String hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
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
                  color: isDark ? color.withOpacity(0.15) : color.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDark ? color.shade400 : color.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recommendations.isNotEmpty) ...[
            Text(
              "Initial AI Suggestions:".tr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...recommendations.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: color.shade400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  rec['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (rec['key_benefit'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rec['key_benefit'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec['desc'],
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).toList(),
            const Divider(height: 24),
          ],
          Text(
            "Ask a question or suggest an idea:".tr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ideaController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color:
                            isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onEvaluate(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onEvaluate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                child: isEvaluating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ],
          ),
          if (aiFeedbackData != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.05) : color.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? color.withOpacity(0.2) : color.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        aiFeedbackData['is_good'] == true 
                            ? Icons.thumb_up_rounded 
                            : Icons.warning_rounded,
                        color: aiFeedbackData['is_good'] == true 
                            ? Colors.green.shade600 
                            : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        aiFeedbackData['is_good'] == true 
                            ? "Good Strategy".tr 
                            : "Proceed with Caution".tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: aiFeedbackData['is_good'] == true 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  MarkdownBody(
                    data: aiFeedbackData['feedback'] ?? "",
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                      ),
                      listBullet: TextStyle(
                        color: color.shade600,
                      ),
                    ),
                  ),
                  if (aiFeedbackData['better_alternative'] != null && 
                      aiFeedbackData['better_alternative'].toString().isNotEmpty && 
                      aiFeedbackData['better_alternative'].toString().toLowerCase() != "null") ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Better Alternative:".tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  aiFeedbackData['better_alternative'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    index: 0,
                    child: Text(
                      "Crop Doctor & AI".tr,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInSlide(
                    index: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black38
                                : Colors.grey.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_imageBytes != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _imageBytes!,
                                      height: 180,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 180,
                                    child: _isAnalyzing
                                        ? Center(
                                            child: AgroPulseLoader(
                                              message: "Analyzing Leaf...".tr,
                                            ),
                                          )
                                        : SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Diagnosis:".tr,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _diagnosisResult ??
                                                      "Error".tr,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color:
                                                        (_diagnosisResult ?? "")
                                                                .toLowerCase()
                                                                .contains(
                                                                  "healthy",
                                                                )
                                                            ? Colors.green
                                                            : Colors.red,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                if (_diseaseDetails !=
                                                    null) ...[
                                                  _buildDetailSection(
                                                    "Type".tr,
                                                    _diseaseDetails!['type'],
                                                  ),
                                                  if (_diseaseDetails!['remedy'] !=
                                                      null) ...[
                                                    _buildDetailSection(
                                                      "Maintenance".tr,
                                                      _diseaseDetails!['remedy']
                                                          ['maintenance'],
                                                    ),
                                                    _buildDetailSection(
                                                      "Cultural Control".tr,
                                                      _diseaseDetails!['remedy']
                                                          ['cultural'],
                                                    ),
                                                    _buildDetailSection(
                                                      "Chemical Control".tr,
                                                      _diseaseDetails!['remedy']
                                                          ['chemical'],
                                                    ),
                                                    _buildDetailSection(
                                                      "Biological Control".tr,
                                                      _diseaseDetails!['remedy']
                                                          ['biological'],
                                                    ),
                                                    _buildDetailSection(
                                                      "Notes".tr,
                                                      _diseaseDetails!['remedy']
                                                          ['notes'],
                                                    ),
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
                            Column(
                              children: [
                                Container(
                                  height: 100,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.teal.shade900
                                          : Colors.teal.shade200,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      size: 36,
                                      color: isDark
                                          ? Colors.teal.shade500
                                          : Colors.teal.shade400,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  "Upload a photo of the affected leaf for instant ML diagnosis and remedies."
                                      .tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.teal.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: Text(
                                    "Camera".tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: Icon(
                                    Icons.image_rounded,
                                    color: isDark
                                        ? Colors.teal.shade300
                                        : Colors.teal.shade700,
                                    size: 16,
                                  ),
                                  label: Text(
                                    "Gallery".tr,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.teal.shade300
                                          : Colors.teal.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.teal.shade700
                                          : Colors.teal.shade200,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInSlide(
                    index: 2,
                    child: Text(
                      "Personalized Recommendations".tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInSlide(
                    index: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.green.shade200,
                        ),
                      ),
                      child: TextField(
                        controller: _currentCropController,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText:
                              "Type your current crop (e.g. Wheat, Potato)..."
                                  .tr,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.normal,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.search_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: _fetchRecommendations,
                          ),
                        ),
                        onSubmitted: (_) => _fetchRecommendations(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingRecs)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: AgroPulseLoader(),
                      ),
                    )
                  else if (_searchedCrop != null) ...[
                    if (_nutrientAnalysis != null && _nutrientAnalysis!.isNotEmpty)
                      FadeInSlide(
                        index: 4,
                        child: _buildSoilImpactCard(_nutrientAnalysis!),
                      ),
                    FadeInSlide(
                      index: 5,
                      child: _buildInteractiveSection(
                        title: "Next Crop Strategy".tr,
                        icon: Icons.grass_rounded,
                        color: Colors.purple,
                        recommendations: _cropRecommendations,
                        ideaController: _cropIdeaController,
                        isEvaluating: _isEvaluatingCrop,
                        aiFeedbackData: _cropFeedbackData, 
                        onEvaluate: () => _evaluateIdea('crop'),
                        hintText: "E.g., Can I plant Barley next?".tr,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInSlide(
                      index: 6,
                      child: _buildInteractiveSection(
                        title: "Fertilizer Strategy".tr,
                        icon: Icons.science_rounded,
                        color: Colors.teal,
                        recommendations: _fertilizerRecommendations,
                        ideaController: _fertilizerIdeaController,
                        isEvaluating: _isEvaluatingFertilizer,
                        aiFeedbackData: _fertilizerFeedbackData, 
                        onEvaluate: () => _evaluateIdea('fertilizer'),
                        hintText: "E.g., Will organic compost be enough?".tr,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}