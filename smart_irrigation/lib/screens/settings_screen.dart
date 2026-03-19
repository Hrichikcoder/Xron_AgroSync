import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/fade_in_slide.dart';
import '../core/translations.dart';
import '../core/globals.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  static final ValueNotifier<bool> pushNotificationsEnabled = ValueNotifier(true);

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Offset _mousePosition = Offset.zero;

  bool _autoIrrigationEnabled = true;
  bool _smsAlertsEnabled = false;

  String _userName = "Hrichik";
  String _userRole = "System Administrator";
  String _userEmail = "hrichik@agrosync.in";
  String _userPhone = "+91 98765 43210";
  String _userLocation = "Kolkata, West Bengal";

  final List<Map<String, String>> _fields = [
    {"name": "North Plot A", "area": "4.5 Acres"},
    {"name": "South Plot B", "area": "2.1 Acres"},
    {"name": "Greenhouse 1", "area": "800 sq.m"},
    {"name": "East Field", "area": "5.0 Acres"},
  ];

  final Map<String, List<String>> _languageGroups = {
    "Global": ["English"],
    "North": ["Hindi", "Punjabi", "Kashmiri", "Dogri", "Urdu"],
    "West": ["Marathi", "Gujarati", "Konkani"],
    "South": ["Tamil", "Telugu", "Kannada", "Malayalam"],
    "East & Northeast": ["Bengali", "Odia", "Assamese", "Manipuri", "Bodo"],
  };

  BoxDecoration _cardDecoration(bool isDark) {
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

  void _showEditProfileDialog(bool isDark) {
    TextEditingController nameController = TextEditingController(text: _userName);
    TextEditingController roleController = TextEditingController(text: _userRole);
    TextEditingController emailController = TextEditingController(text: _userEmail);
    TextEditingController phoneController = TextEditingController(text: _userPhone);
    TextEditingController locationController = TextEditingController(text: _userLocation);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : const Color(0xFFF1F5F9).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6)),
            ),
            title: Row(
              children: [
                Icon(Icons.manage_accounts_rounded, color: Colors.blueAccent.shade400),
                const SizedBox(width: 12),
                Text(
                  "Edit Profile".tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileTextField("Full Name".tr, Icons.person_rounded, nameController, isDark),
                  const SizedBox(height: 16),
                  _buildProfileTextField("Job Role".tr, Icons.work_rounded, roleController, isDark),
                  const SizedBox(height: 16),
                  _buildProfileTextField("Email Address".tr, Icons.email_rounded, emailController, isDark),
                  const SizedBox(height: 16),
                  _buildProfileTextField("Phone Number".tr, Icons.phone_rounded, phoneController, isDark),
                  const SizedBox(height: 16),
                  _buildProfileTextField("Farm Location".tr, Icons.location_on_rounded, locationController, isDark),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel".tr, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _userName = nameController.text;
                    _userRole = roleController.text;
                    _userEmail = emailController.text;
                    _userPhone = phoneController.text;
                    _userLocation = locationController.text;
                  });
                  Navigator.pop(context);
                },
                child: Text("Save Changes".tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileTextField(String label, IconData icon, TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blueAccent.shade400, size: 20),
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent.shade400, width: 2),
        ),
      ),
    );
  }

  void _showLanguageDialog(bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : const Color(0xFFF1F5F9).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6)),
            ),
            title: Row(
              children: [
                Icon(Icons.translate_rounded, color: Colors.blueAccent.shade400),
                const SizedBox(width: 12),
                Text(
                  "Select Language".tr,
                  style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _languageGroups.length,
                itemBuilder: (context, index) {
                  String region = _languageGroups.keys.elementAt(index);
                  List<String> languages = _languageGroups[region]!;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                        child: Text(
                          region.tr.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent.shade400,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...languages.map((lang) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: languageNotifier.value == lang 
                              ? Colors.blueAccent.withOpacity(0.1) 
                              : (isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: languageNotifier.value == lang 
                                ? Colors.blueAccent.shade400 
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            lang,
                            style: TextStyle(
                              fontWeight: languageNotifier.value == lang ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          trailing: languageNotifier.value == lang 
                              ? Icon(Icons.check_circle_rounded, color: Colors.blueAccent.shade400) 
                              : null,
                          onTap: () {
                            setState(() {
                              languageNotifier.value = lang;
                              translationTrigger.value++;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      )),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel".tr, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFieldManagementDialog(bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AlertDialog(
                backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : const Color(0xFFF1F5F9).withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6)),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Manage Fields".tr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_rounded, color: Colors.blueAccent.shade400, size: 32),
                      onPressed: () {
                        _showAddFieldDialog(isDark, setStateDialog);
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: _fields.isEmpty
                      ? Center(
                          child: Text(
                            "No fields available.".tr,
                            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _fields.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.landscape_rounded, color: Colors.blueAccent.shade400),
                                title: Text(
                                  _fields[index]["name"]!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  _fields[index]["area"]!,
                                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () {
                                    setStateDialog(() {
                                      _fields.removeAt(index);
                                    });
                                    setState(() {});
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Done".tr, style: TextStyle(color: Colors.blueAccent.shade400, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddFieldDialog(bool isDark, StateSetter setParentDialogState) {
    TextEditingController nameController = TextEditingController();
    TextEditingController areaController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
          ),
          title: Text("Add New Field".tr, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Field Name".tr,
                  labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent.shade400)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Mapped Area (e.g. 2.0 Acres)".tr,
                  labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent.shade400)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel".tr, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty && areaController.text.isNotEmpty) {
                  setParentDialogState(() {
                    _fields.add({
                      "name": nameController.text,
                      "area": areaController.text,
                    });
                  });
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: Text("Add".tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDocumentationDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.98) : const Color(0xFFF1F5F9).withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 24),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.eco_rounded, color: Colors.blueAccent.shade400, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        "AgroSync Official Documentation".tr,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDocSection(
                            "1. Overview",
                            "AgroSync Smart Irrigation is an IoT-powered precision agriculture system designed to automate and optimize irrigation using real-time environmental data and intelligent decision-making.\n\nThe system continuously monitors:\n• Soil moisture (capacitive sensor)\n• Temperature & humidity (DHT11)\n• Ambient light intensity (LDR)\n\nUsing these inputs, AgroSync ensures:\n• Efficient water usage\n• Improved crop health\n• Reduced manual intervention\n• Data-driven irrigation decisions\n\nThe system supports both:\n• Automatic irrigation mode (AI/threshold-based)\n• Manual override mode (user-controlled)",
                            isDark,
                          ),
                          _buildDocSection(
                            "2. System Architecture",
                            "Core Controller (ESP32 Microcontroller):\n• Handles sensor data acquisition\n• Executes irrigation logic\n• Communicates with backend server via WiFi\n• Controls relay module for pumps\n\nBackend System:\n• Processes incoming sensor data\n• Applies decision logic / ML thresholds\n• Sends control signals to ESP32\n• Stores historical data for analytics\n\nFrontend (Web/App Dashboard):\n• Displays live sensor readings\n• Shows irrigation status\n• Allows manual pump control\n• Visualizes trends and alerts",
                            isDark,
                          ),
                          _buildDocSection(
                            "3. Hardware Integration",
                            "Components Used:\n• ESP32 (Master Node)\n• Capacitive Soil Moisture Sensor\n• DHT11 Temperature & Humidity Sensor\n• LDR (Light Sensor)\n• Dual Relay Module (12V pump control)\n• Submersible Water Pumps\n\nPower System:\n• Solar Panel, Battery, Charge Controller\n• Buck Converter (Voltage regulation)\n\nSensor Connections:\n• Soil Moisture: GPIO 32\n• DHT11: GPIO 4\n• LDR: Analog Pin\n• Relay Pump 1: GPIO 13\n• Relay Pump 2: GPIO 14",
                            isDark,
                          ),
                          _buildDocSection(
                            "4. Auto-Irrigation Algorithm",
                            "Decision Logic:\nWhen system is in AUTO mode, irrigation is triggered based on:\n• Soil moisture level\n• Weather prediction\n• Crop-specific thresholds\n\nCore Rule:\nIf Soil moisture < 35% AND no rain predicted in next 2 hours, then Pump 1 is activated for 5 minutes.\n\nAlgorithm Flow:\n1. Read soil moisture value\n2. Normalize/calibrate data\n3. Compare with threshold\n4. Check weather condition\n5. Decide: Start, Delay, or Stop irrigation",
                            isDark,
                          ),
                          _buildDocSection(
                            "5. Intelligent Features",
                            "Adaptive Irrigation (ML Layer):\n• Learns crop water patterns\n• Adjusts thresholds dynamically\n• Reduces water wastage\n\nWeather Awareness:\n• Integrates weather APIs\n• Avoids irrigation before rainfall\n\nData Logging:\n• Stores moisture history, irrigation cycles, and environmental data for insights.",
                            isDark,
                          ),
                          _buildDocSection(
                            "6. User Features",
                            "Dashboard Capabilities:\n• Real-time sensor monitoring\n• Pump ON/OFF controls\n• Mode switching (Auto / Manual)\n• Alerts & notifications\n\nManual Mode:\n• User directly controls pumps\n• Overrides automatic logic\n• Useful for emergency watering",
                            isDark,
                          ),
                          _buildDocSection(
                            "7. Troubleshooting Guide",
                            "Sensors Offline:\n• Check ESP32 power supply\n• Verify WiFi connection\n• Ensure correct pin connections\n\nPump Not Starting:\n• Check relay module wiring\n• Verify GPIO output signal\n• Ensure power supply to pump\n\nContinuous Pump Operation:\n• Disable manual override mode\n• Check backend logic trigger\n\nIncorrect Moisture Readings:\n• Recalibrate sensor: Dry air → min value, Water → max value",
                            isDark,
                          ),
                          _buildDocSection(
                            "8. Safety & Reliability",
                            "• Overwatering protection\n• Pump timeout failsafe\n• Electrical isolation using relays\n• Stable power via regulated supply",
                            isDark,
                          ),
                          _buildDocSection(
                            "9. Future Enhancements",
                            "• AI-based crop recommendation\n• Multi-zone irrigation system\n• Mobile app with voice assistant\n• Integration with satellite/weather systems\n• Predictive irrigation using ML",
                            isDark,
                          ),
                          _buildDocSection(
                            "10. Summary",
                            "AgroSync Smart Irrigation transforms traditional farming into a smart, automated, and efficient system by combining IoT hardware, intelligent backend logic, and a user-friendly dashboard. It ensures optimal water usage, reduced manual effort, and better crop yield.",
                            isDark,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocSection(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Text(
              title.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.blueAccent.shade400,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.tr,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent.shade400, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Icon(
                Icons.person_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 48,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userRole.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent.shade400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.email_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _userEmail,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _userPhone,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _userLocation,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          BouncingButton(
            onTap: () => _showEditProfileDialog(isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.shade400.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: Colors.blueAccent.shade400),
                  const SizedBox(width: 6),
                  Text(
                    "Edit".tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700,
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

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0, left: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent.shade400, size: 20),
          const SizedBox(width: 12),
          Text(
            title.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(
      String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent.shade400, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeColor: Colors.blueAccent.shade400,
              inactiveThumbColor: Colors.grey.shade400,
              activeTrackColor: Colors.blueAccent.shade400.withOpacity(0.3),
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, bool isDark) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.blueAccent.shade400, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Preferences", Icons.tune_rounded, isDark),
          _buildToggleTile(
            "Dark Mode",
            "Switch to a dark UI theme",
            Icons.dark_mode_rounded,
            widget.isDarkMode,
            widget.onThemeChanged,
            isDark,
          ),
          _buildActionTile(
            "Language",
            "Current: ${languageNotifier.value}",
            Icons.language_rounded,
            () => _showLanguageDialog(isDark),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Notifications", Icons.notifications_rounded, isDark),
          _buildToggleTile(
            "Push Notifications",
            "Alerts for critical sensor events",
            Icons.notifications_active_rounded,
            SettingsScreen.pushNotificationsEnabled.value,
            (val) {
              setState(() {
                SettingsScreen.pushNotificationsEnabled.value = val;
              });
            },
            isDark,
          ),
          _buildToggleTile(
            "SMS Alerts",
            "Send text messages for hardware failures",
            Icons.sms_rounded,
            _smsAlertsEnabled,
            (val) => setState(() => _smsAlertsEnabled = val),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Farm Control", Icons.agriculture_rounded, isDark),
          _buildToggleTile(
            "Auto-Irrigation Override",
            "Allow manual control globally",
            Icons.water_drop_rounded,
            _autoIrrigationEnabled,
            (val) => setState(() => _autoIrrigationEnabled = val),
            isDark,
          ),
          _buildActionTile(
            "Field Management",
            "Add or configure mapped plots",
            Icons.landscape_rounded,
            () => _showFieldManagementDialog(isDark),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Support & About", Icons.help_outline_rounded, isDark),
          _buildActionTile(
            "Documentation",
            "View official system manuals",
            Icons.menu_book_rounded,
            () => _showDocumentationDialog(context, isDark),
            isDark,
          ),
          _buildActionTile(
            "System Diagnostics",
            "Run a full check on all modules",
            Icons.health_and_safety_rounded,
            () {},
            isDark,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Settings".tr,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
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
                      Colors.white.withOpacity(isDark ? 0.08 : 0.4),
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
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeInSlide(
                            index: 0,
                            child: _buildProfileCard(isDark),
                          ),
                          const SizedBox(height: 32),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      FadeInSlide(index: 1, child: _buildPreferencesSection(isDark)),
                                      const SizedBox(height: 24),
                                      FadeInSlide(index: 2, child: _buildSystemSection(isDark)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    children: [
                                      FadeInSlide(index: 3, child: _buildNotificationsSection(isDark)),
                                      const SizedBox(height: 24),
                                      FadeInSlide(index: 4, child: _buildSupportSection(isDark)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                FadeInSlide(index: 1, child: _buildPreferencesSection(isDark)),
                                const SizedBox(height: 24),
                                FadeInSlide(index: 2, child: _buildNotificationsSection(isDark)),
                                const SizedBox(height: 24),
                                FadeInSlide(index: 3, child: _buildSystemSection(isDark)),
                                const SizedBox(height: 24),
                                FadeInSlide(index: 4, child: _buildSupportSection(isDark)),
                              ],
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              "AgroSync v2.4.1",
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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