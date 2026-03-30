import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:geocoding/geocoding.dart';   

import '../widgets/bouncing_button.dart';
import '../widgets/fade_in_slide.dart';
import '../core/translations.dart';
import '../core/globals.dart';
import 'system_diagnostics_dialog.dart';
import '../core/app_config.dart';
import 'auth_screen.dart'; 

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
  bool _isLoadingProfile = true;

  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String _userPhone = "Loading...";
  String _userLocation = "Loading...";

  List<Map<String, dynamic>> _fields = [];

  final Map<String, List<String>> _languageGroups = {
    "Global": ["English"],
    "North": ["Hindi", "Punjabi", "Kashmiri", "Dogri", "Urdu"],
    "West": ["Marathi", "Gujarati", "Konkani"],
    "South": ["Tamil", "Telugu", "Kannada", "Malayalam"],
    "East & Northeast": ["Bengali", "Odia", "Assamese", "Manipuri", "Bodo"],
  };

  @override
  void initState() {
    super.initState();
    _fetchProfileFromDatabase(); 
    _fetchFieldsFromDatabase(); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (openEditProfileNotifier.value) {
        openEditProfileNotifier.value = false;
        _showEditProfileDialog(widget.isDarkMode);
      }
    });
  }

  Future<void> _fetchDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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
              setState(() {
                _userLocation = "$city, $state".replaceAll(RegExp(r',$'), '').trim();
                currentUserLocation.value = _userLocation;
              });
            }
          }
        } catch (apiError) {
          debugPrint("OSM Web Geocoding error: $apiError");
        }
      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          List<String> addressParts = [];
          if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);

          if (addressParts.isEmpty) {
            if (place.street != null && place.street!.isNotEmpty) {
              addressParts.add(place.street!);
            } else if (place.administrativeArea != null) {
              addressParts.add(place.administrativeArea!);
            }
          }

          if (mounted && addressParts.isNotEmpty) {
            setState(() {
              _userLocation = addressParts.join(", ");
              currentUserLocation.value = _userLocation;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Location fetch error: $e");
    }
  }

  Future<void> _fetchProfileFromDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/get_profile'),
        headers: {'Authorization': 'Bearer $token'}, 
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final user = data['user'];
          if (mounted) {
            setState(() {
              _userName = user['name'] ?? "Unknown";
              _userEmail = user['email'] ?? "Unknown";
              _userPhone = user['phone'] ?? "Unknown";
              _userLocation = user['location'] ?? "Unknown";
              
              // NEW: Load SMS preference
              _smsAlertsEnabled = user['sms_alerts'] == true || user['sms_alerts'] == 'true'; 

              _isLoadingProfile = false;
            });

            if (_userLocation == "Unknown" || _userLocation.isEmpty) {
              _fetchDeviceLocation();
            }
            
            if (user['profile_pic_base64'] != null) {
              userProfileImageNotifier.value = base64Decode(user['profile_pic_base64']);
            }
          }
        }
      } else {
        debugPrint("Failed to fetch profile: ${response.statusCode}");
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) {
        setState(() {
          _userName = "Offline Mode";
          _userEmail = "No Connection";
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _saveProfileToDatabase(Uint8List? imageBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${AppConfig.baseUrl}/update_profile') 
      );

      request.headers['Authorization'] = 'Bearer $token'; 

      request.fields['name'] = _userName;
      request.fields['email'] = _userEmail;
      request.fields['phone'] = _userPhone;
      request.fields['location'] = _userLocation;
      request.fields['sms_alerts'] = _smsAlertsEnabled.toString(); // Keep current SMS state

      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('profile_pic', imageBytes, filename: 'dp.jpg'),
        );
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        debugPrint("Profile saved to PostgreSQL successfully");
      } else {
        debugPrint("Failed to save profile: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("API Connection Error: $e");
    }
  }

  // --- NEW: Optimistic UI update and backend sync for SMS toggling ---
  Future<void> _toggleSMSAlerts(bool newValue) async {
    setState(() {
      _smsAlertsEnabled = newValue;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${AppConfig.baseUrl}/update_profile') 
      );
      request.headers['Authorization'] = 'Bearer $token'; 

      request.fields['name'] = _userName;
      request.fields['email'] = _userEmail;
      request.fields['phone'] = _userPhone;
      request.fields['location'] = _userLocation;
      request.fields['sms_alerts'] = newValue.toString();

      // Only add image if exists
      if (userProfileImageNotifier.value != null) {
        request.files.add(
          http.MultipartFile.fromBytes('profile_pic', userProfileImageNotifier.value!, filename: 'dp.jpg'),
        );
      }

      var response = await request.send();
      
      if (response.statusCode != 200) {
        // Revert UI if update fails
        setState(() => _smsAlertsEnabled = !newValue);
        debugPrint("Failed to update SMS preference: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _smsAlertsEnabled = !newValue);
      debugPrint("API Error updating SMS preference: $e");
    }
  }

  Future<void> _fetchFieldsFromDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/get_fields'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _fields = List<Map<String, dynamic>>.from(data['fields']);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching fields: $e");
    }
  }

  Future<void> _updateFieldInBackend(int id, String newName, String newArea) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/update_field/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: json.encode({'name': newName, 'area': newArea}),
      );

      if (response.statusCode == 200) {
        _fetchFieldsFromDatabase(); 
      }
    } catch (e) {
      debugPrint("Error updating field: $e");
    }
  }

  void _showEditFieldDialog(int id, String currentName, String currentArea) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: currentName);
    final areaController = TextEditingController(text: currentArea.replaceAll(" Acres", ""));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Text("Edit Field", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Field Name",
                  labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Area (Acres)",
                  labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.shade400),
              onPressed: () {
                if (nameController.text.isNotEmpty && areaController.text.isNotEmpty) {
                  _updateFieldInBackend(id, nameController.text, areaController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

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
    TextEditingController emailController = TextEditingController(text: _userEmail);
    TextEditingController phoneController = TextEditingController(text: _userPhone);
    TextEditingController locationController = TextEditingController(text: _userLocation);
    
    Uint8List? tempImageBytes = userProfileImageNotifier.value;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setStateDialog(() => tempImageBytes = bytes);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                backgroundImage: tempImageBytes != null ? MemoryImage(tempImageBytes!) : null,
                                child: tempImageBytes == null ? Icon(Icons.person, size: 50, color: Colors.grey.shade500) : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.blueAccent.shade400, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileTextField("Full Name".tr, Icons.person_rounded, nameController, isDark),
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
                        _userEmail = emailController.text;
                        _userPhone = phoneController.text;
                        _userLocation = locationController.text;
                        userProfileImageNotifier.value = tempImageBytes; 
                        
                        currentUserName.value = nameController.text;
                        currentUserEmail.value = emailController.text;
                        currentUserPhone.value = phoneController.text;
                        currentUserLocation.value = locationController.text;
                      });
                      _saveProfileToDatabase(tempImageBytes); 
                      Navigator.pop(context);
                    },
                    child: Text("Save Changes".tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
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
                                  _fields[index]["name"].toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  _fields[index]["area"].toString(),
                                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded, color: Colors.blueAccent.shade400),
                                      onPressed: () {
                                        Navigator.pop(context); 
                                        _showEditFieldDialog(
                                          _fields[index]["id"],
                                          _fields[index]["name"].toString(),
                                          _fields[index]["area"].toString(),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                      onPressed: () async {
                                        final fieldId = _fields[index]["id"];
                                        
                                        setStateDialog(() {
                                          _fields.removeAt(index);
                                        });
                                        setState(() {});

                                        try {
                                          final prefs = await SharedPreferences.getInstance();
                                          final token = prefs.getString('jwt_token') ?? '';

                                          await http.delete(
                                            Uri.parse('${AppConfig.baseUrl}/delete_field/$fieldId'),
                                            headers: {'Authorization': 'Bearer $token'},
                                          );
                                        } catch (e) {
                                          debugPrint("Failed to delete field: $e");
                                          _fetchFieldsFromDatabase(); 
                                        }
                                      },
                                    ),
                                  ],
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
              onPressed: () async {
                if (nameController.text.isNotEmpty && areaController.text.isNotEmpty) {
                  final newName = nameController.text;
                  final newArea = areaController.text;
                  Navigator.pop(context); 

                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('jwt_token') ?? '';

                    final response = await http.post(
                      Uri.parse('${AppConfig.baseUrl}/add_field'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token'
                      },
                      body: json.encode({'name': newName, 'area': newArea}),
                    );

                    if (response.statusCode == 200) {
                      final data = json.decode(response.body);
                      setParentDialogState(() {
                        _fields.add({
                          "id": data['field']['id'],
                          "name": newName,
                          "area": newArea,
                        });
                      });
                      setState(() {});
                    }
                  } catch (e) {
                    debugPrint("Error saving field: $e");
                  }
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
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.only(top: 12, bottom: 24), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(4))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded, color: Colors.greenAccent.shade400, size: 28),
                      const SizedBox(width: 8),
                      Text("User Manual & Guide".tr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDocSection("👋 Welcome to AgroSync!", "AgroSync makes farming easier by tracking weather, soil moisture, and crop health for you. It automatically decides when your fields need water and takes care of it, saving you time and money.", isDark, Icons.waving_hand_rounded),
                          _buildDocSection("💧 Auto vs. Manual Watering", "• Auto Mode: The system waters your crops automatically when the soil is dry and no rain is expected.\n• Manual Mode: Flip the switch on the 'Overview' page to turn your water pumps and sprinklers on or off yourself at any time.", isDark, Icons.water_drop_rounded),
                          _buildDocSection("🌱 Crop Doctor", "Got a sick plant? Go to the 'Crop Doctor' tab, snap a picture of the affected leaf, and our AI will tell you what the disease is and exactly how to cure it.", isDark, Icons.medical_services_rounded),
                          _buildDocSection("📈 Market Prices", "The 'Market' tab helps you sell your crops for the best price. Add the crops you grow, and AgroSync will tell you which nearby market will pay you the most today.", isDark, Icons.storefront_rounded),
                          _buildDocSection("⚠️ Handling Alerts", "If a pump fails or water levels drop too low, you will get a notification. Tap the bell icon in the top right corner of the overview page to read your alerts.", isDark, Icons.warning_rounded),
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

  Widget _buildDocSection(String title, String content, bool isDark, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent.shade400, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(title.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87))),
              ],
            ),
            const SizedBox(height: 12),
            Text(content.tr, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  // --- UPDATED PROFILE CARD (Edit & Sign Out buttons are now safely structured here) ---
  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(isDark),
      child: _isLoadingProfile 
        ? Center(child: CircularProgressIndicator(color: Colors.blueAccent.shade400))
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.shade400, width: 2),
                ),
                child: ValueListenableBuilder<Uint8List?>(
                  valueListenable: userProfileImageNotifier,
                  builder: (context, imageBytes, child) {
                    return CircleAvatar(
                      radius: 40,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                      child: imageBytes == null 
                          ? Icon(Icons.person_rounded, color: isDark ? Colors.white : Colors.black87, size: 48)
                          : null,
                    );
                  }
                ),
              ),
              const SizedBox(width: 40), // Increased gap between photo and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- NAME & BUTTONS ROW ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BouncingButton(
                              onTap: () => _showEditProfileDialog(isDark),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.shade400.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blueAccent.shade400.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 16, color: Colors.blueAccent.shade400),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Edit".tr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            BouncingButton(
                              onTap: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('jwt_token');

                                currentUserName.value = "Loading...";
                                currentUserEmail.value = "Loading...";
                                currentUserPhone.value = "Loading...";
                                currentUserLocation.value = "Loading...";
                                userProfileImageNotifier.value = null;

                                if (!mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => AuthScreen()),
                                  (Route<dynamic> route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent.shade400),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Sign Out".tr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // --- CONTACT INFO ---
                    Row(
                      children: [
                        Icon(Icons.email_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _userEmail,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _userPhone,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _userLocation,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
            (val) => _toggleSMSAlerts(val), // NEW: Bound to the async backend call
            isDark,
          ),
        ],
      ),
    );
  }
  Widget _buildSystemControlMode(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_rounded, color: Colors.blueAccent.shade400, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("System Control Mode", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color)),
                    const SizedBox(height: 4),
                    Text(
                      _autoIrrigationEnabled 
                          ? "AI is actively managing water delivery." 
                          : "Manual override active. You control the pumps.",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _autoIrrigationEnabled = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _autoIrrigationEnabled ? (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _autoIrrigationEnabled 
                            ? [BoxShadow(color: (isDark ? const Color(0xFF10B981) : const Color(0xFF064E3B)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 18, color: _autoIrrigationEnabled ? Colors.white : Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text("Smart AI", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _autoIrrigationEnabled ? Colors.white : Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _autoIrrigationEnabled = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_autoIrrigationEnabled ? Colors.orangeAccent.shade400 : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_autoIrrigationEnabled 
                            ? [BoxShadow(color: Colors.orangeAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.back_hand_rounded, size: 18, color: !_autoIrrigationEnabled ? Colors.white : Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text("Manual", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: !_autoIrrigationEnabled ? Colors.white : Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
            () => showDiagnosticsDialog(context, isDark), 
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
        title: Text(
          "Settings".tr,
          style: TextStyle(
            fontSize: 34,
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
                                      // Log out button moved to profile card
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
                                // Log out button moved to profile card
                              ],
                            ),
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              "AgroSync - Developed by Team XRON",
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