import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/translations.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/fade_in_slide.dart';
import '../core/app_config.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/globals.dart'; 

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; 

  bool _isSystemOn = true;

  String _pumpMode = "auto";
  bool _pump1State = false;
  bool _pump2State = false;

  bool isShadeDeployed = false;
  bool isSprinklerActive = false;
  bool _shadeOverride = false;

  Set<String> disabledSensors = {};

  Timer? _timer;
  Timer? _flowTimer;
  String _sensorTemperature = "28.7";
  String _sensorHumidity = "63";
  String _sensorSoilMoisture = "45";
  
  String _sensorWaterFlow = "0.0"; 
  String _sensorWaterFlowRate = "0.00"; 

  String _lastCycleVolume = "0.0";
  String _sensorLight = "850";
  String _sensorRain = "15";
  String _sensorDepth = "75";

  bool _motorRunning = false;

  String _realTemp = "--°C";
  String _realHumidity = "--%";
  String _realPrecipitation = "-- mm";
  String _realWind = "-- km/h";
  String _sunrise = "--:--";
  String _sunset = "--:--";
  String _locationName = "Locating...";
  
  // --- NEW: Dynamic Weather State Variables ---
  String _realWeatherDesc = "--";
  IconData _weatherIcon = Icons.wb_sunny_rounded;
  Color _weatherIconColor = Colors.yellowAccent.shade400;

  List<Map<String, dynamic>> _waterFlowHistory = [];

  String? _selectedField; 
  Map<String, String> _userFields = {}; 

  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadPersistedState(); 
    _fetchFields(); 
    _fetchInitialHistory();
    _initLocationAndWeather();
    _fetchSensorData();
    _fetchLiveFlowData();
    
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        _syncSettings(); 
        if (_isSystemOn) {
          _fetchSensorData();
          _fetchFields(); 
        }
      },
    );
    _flowTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_isSystemOn) {
          _fetchLiveFlowData();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSystemOn = prefs.getBool('system_on') ?? true;
        _shadeOverride = prefs.getBool('shade_override') ?? false;
      });
    }
  }

  Future<void> _syncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shadeOverride = prefs.getBool('shade_override') ?? false;
      });
    }
  }

  Future<void> _fetchLiveFlowData() async {
    if (!_isSystemOn) return; 

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/sensors/live_flow'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _sensorWaterFlow = data['water_flow']?.toString() ?? "0.0";
            _sensorWaterFlowRate = data['flow_rate']?.toString() ?? "0.00";
            
            _motorRunning = (double.tryParse(_sensorWaterFlowRate) ?? 0.0) > 0;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _updateActiveFieldInBackend(String fieldName) async {
    String areaStr = _userFields[fieldName]!.replaceAll(" Acres", "");
    double areaAcres = double.tryParse(areaStr) ?? 0.0;

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/set_active_field'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'area_acres': areaAcres}),
      );
    } catch (e) {
      debugPrint("Failed to update active field: $e");
    }
  }

  Future<void> _fetchFields() async {
    if (!_isSystemOn) return; 
    
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
          final List fields = data['fields'];
          Map<String, String> fetchedFields = {};
          
          for (var field in fields) {
            fetchedFields[field['name'].toString()] = "${field['area']} Acres";
          }
          
          if (mounted) {
            setState(() {
              _userFields = fetchedFields;
              
              if (_userFields.isNotEmpty && (_selectedField == null || !_userFields.containsKey(_selectedField))) {
                 _selectedField = _userFields.keys.first;
              } else if (_userFields.isEmpty) {
                 _selectedField = null;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching fields for Dropdown: $e");
    }
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

  BoxDecoration _greenCardDecoration(bool isDark, bool isDay) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF047857), Color(0xFF064E3B)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF064E3B).withOpacity(isDark ? 0.3 : 0.2),
          blurRadius: 25,
          spreadRadius: -5,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Future<void> _initLocationAndWeather() async {
    double lat = 22.5726;
    double lon = 88.3639;
    String locName = "Kolkata, IN";

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
        lat = position.latitude;
        lon = position.longitude;

        final geoRes = await http.get(Uri.parse(
            'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en'));

        if (geoRes.statusCode == 200) {
          final geoData = json.decode(geoRes.body);
          locName =
              "${geoData['city'] ?? geoData['locality'] ?? 'Unknown'}, ${geoData['countryCode']}";
        }
      } else {
        final ipRes = await http.get(Uri.parse('http://ip-api.com/json/'));
        if (ipRes.statusCode == 200) {
          final ipData = json.decode(ipRes.body);
          lat = ipData['lat'];
          lon = ipData['lon'];
          locName = "${ipData['city']}, ${ipData['countryCode']}";
        }
      }
    } catch (e) {
      try {
        final ipRes = await http.get(Uri.parse('http://ip-api.com/json/'));
        if (ipRes.statusCode == 200) {
          final ipData = json.decode(ipRes.body);
          lat = ipData['lat'];
          lon = ipData['lon'];
          locName = "${ipData['city']}, ${ipData['countryCode']}";
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _locationName = locName;
      });
    }

    _fetchWeatherData(lat, lon);
  }

  String getRainCondition(num rawValue) {
    int value = rawValue.toInt();
    if (value >= 3000) return "No Rain (Dry)";
    if (value >= 2000 && value < 3000) return "Light Rain";
    if (value >= 1000 && value < 2000) return "Moderate Rain";
    return "Heavy Rain";
  }

  String _formatDate(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return "${date.day}/${date.month}/${date.year} $hour:$min $ampm";
  }

  // --- NEW: Map Weather Code to Human Readable Status ---
  void _updateWeatherCondition(int code, int isDayNum) {
    bool isDaytime = isDayNum == 1;
    String desc = "Clear";
    IconData icon = isDaytime ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
    Color iconCol = isDaytime ? Colors.yellowAccent.shade400 : Colors.teal.shade100;

    if (code == 0) {
      desc = isDaytime ? "Sunny & Clear" : "Clear Night";
    } else if (code == 1 || code == 2) {
      desc = "Partly Cloudy";
      icon = isDaytime ? Icons.cloud_queue_rounded : Icons.nights_stay_rounded;
      iconCol = Colors.white70;
    } else if (code == 3) {
      desc = "Overcast";
      icon = Icons.cloud_rounded;
      iconCol = Colors.grey.shade300;
    } else if (code == 45 || code == 48) {
      desc = "Foggy";
      icon = Icons.foggy;
      iconCol = Colors.grey.shade400;
    } else if (code >= 51 && code <= 57) {
      desc = "Drizzle";
      icon = Icons.grain_rounded;
      iconCol = Colors.lightBlueAccent;
    } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      desc = "Rain";
      icon = Icons.water_drop_rounded;
      iconCol = Colors.blueAccent.shade100;
    } else if (code >= 71 && code <= 86) {
      desc = "Snow";
      icon = Icons.ac_unit_rounded;
      iconCol = Colors.white;
    } else if (code >= 95 && code <= 99) {
      desc = "Thunderstorm";
      icon = Icons.thunderstorm_rounded;
      iconCol = Colors.amberAccent.shade100;
    }

    if (mounted) {
      setState(() {
        _realWeatherDesc = desc;
        _weatherIcon = icon;
        _weatherIconColor = iconCol;
      });
    }
  }

  void _showWaterFlowHistory() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : const Color(0xFFF1F5F9).withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                title: Text(
                  "Water Flow History".tr,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: _waterFlowHistory.isEmpty
                      ? Center(
                          child: Text(
                            "No records found".tr,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _waterFlowHistory.length,
                          itemBuilder: (context, index) {
                            final item = _waterFlowHistory[index];
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.water_drop, color: Colors.blueAccent.shade400, size: 20),
                              ),
                              title: Text(
                                "${(item['amount'] as double).toStringAsFixed(2)} mL".tr,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                _formatDate(item['time']),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () {
                                  setStateDialog(() {
                                    _waterFlowHistory.removeAt(index);
                                  });
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close".tr, style: TextStyle(color: Colors.blueAccent.shade400, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchWeatherData(double lat, double lon) async {
    try {
      // --- UPDATED: Added weather_code and is_day to the API Request ---
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code,is_day&daily=sunrise,sunset&timezone=auto');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        final daily = data['daily'];

        if (mounted) {
          setState(() {
            _realTemp = "${current['temperature_2m']}°C";
            _realHumidity = "${current['relative_humidity_2m']}%";
            _realPrecipitation = "${current['precipitation']} mm";
            _realWind = "${current['wind_speed_10m']} km/h";

            // Parse newly added weather_code
            int wCode = current['weather_code'] ?? 0;
            int isDayApi = current['is_day'] ?? 1;
            _updateWeatherCondition(wCode, isDayApi);

            if (daily != null &&
                daily['sunrise'] != null &&
                daily['sunrise'].isNotEmpty) {
              DateTime sr = DateTime.parse(daily['sunrise'][0]);
              DateTime ss = DateTime.parse(daily['sunset'][0]);

              String formatTime(DateTime dt) {
                int h = dt.hour;
                String m = dt.minute.toString().padLeft(2, '0');
                String ampm = h >= 12 ? 'PM' : 'AM';
                h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
                return "$h:$m $ampm";
              }

              _sunrise = formatTime(sr);
              _sunset = formatTime(ss);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Weather API error: $e");
    }
  }

  Future<void> _fetchInitialHistory() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/sensors/history?hours=24'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['last_cycle_volume'] != null) {
          List<dynamic> lcvHistory = data['last_cycle_volume'];
          List<Map<String, dynamic>> loadedHistory = [];
          double previousValue = 0.0;

          for (var record in lcvHistory) {
            double val = (record['value'] as num).toDouble();
            if (val > 0.0 && val != previousValue) {
              loadedHistory.insert(0,
                  {'amount': val, 'time': DateTime.parse(record['time']).toLocal()});
              previousValue = val;
            }
          }

          if (mounted) {
            setState(() {
              _waterFlowHistory = loadedHistory;
              if (_waterFlowHistory.isNotEmpty) {
                _lastCycleVolume = _waterFlowHistory.first['amount'].toString();
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to load history: $e");
    }
  }

  Future<void> _fetchSensorData() async {
    if (!_isSystemOn) return; 

    try {
      final ctrlRes = await http.get(Uri.parse('${AppConfig.baseUrl}/control/status'));
      if (ctrlRes.statusCode == 200) {
        final cData = json.decode(ctrlRes.body);
        if (mounted) {
          setState(() {
            _pumpMode = cData['mode'] ?? "auto";
            _pump1State = cData['pump1'] ?? false;
            _pump2State = cData['pump2'] ?? false;
            isShadeDeployed = cData['shade'] ?? isShadeDeployed;
            isSprinklerActive = cData['sprinkler'] ?? isSprinklerActive;
          });
        }
      }

      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/sensors/current'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _sensorTemperature = data['temperature']?.toString() ?? "28.7";
            String rawHumStr = data['humidity']?.toString() ?? "63";
            double parsedHum = double.tryParse(rawHumStr) ?? 0.0;
            
            if (parsedHum > 100.0) {
              _sensorHumidity = "95";
            } else {
              _sensorHumidity = rawHumStr;
            }
            _sensorSoilMoisture = data['soil_moisture']?.toString() ?? "45";
            _sensorLight = data['ldr']?.toString() ?? "850";
            _sensorRain = data['rain_level']?.toString() ?? "15";
            _sensorDepth = data['depth']?.toString() ?? "75";
            
            if (data['last_cycle_volume'] != null) {
              String newLcv = data['last_cycle_volume'].toString();
              double nLcv = double.tryParse(newLcv) ?? 0.0;
              double oLcv = double.tryParse(_lastCycleVolume) ?? 0.0;

              if (nLcv > 0 && nLcv != oLcv) {
                _waterFlowHistory.insert(0, {'amount': nLcv, 'time': DateTime.now()});
              }
              _lastCycleVolume = newLcv;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching sensor data: $e");
    }
  }

  Future<void> _updatePumpControl(
      String mode, bool p1, bool p2, bool shade, bool sprinkler) async {
    setState(() {
      _pumpMode = mode;
      _pump1State = p1;
      _pump2State = p2;
      isShadeDeployed = shade;
      isSprinklerActive = sprinkler;
    });

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/control/pump'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mode': mode,
          'pump1': p1,
          'pump2': p2,
          'shade': shade,
          'sprinkler': sprinkler
        }),
      );
    } catch (e) {
      if (mounted && SettingsScreen.pushNotificationsEnabled.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to communicate with pump controller")),
        );
      }
    }
  }

  Future<void> _updateShadeControl(bool deploy) async {
    setState(() {
      isShadeDeployed = deploy;
    });

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/control/shade'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'shade': deploy}),
      );
    } catch (e) {
      if (mounted && SettingsScreen.pushNotificationsEnabled.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to communicate with shade controller".tr)),
        );
      }
    }
  }

  Future<void> _toggleSensorState(String sensorKey, bool turnOn) async {
    if (!turnOn) {
      if (disabledSensors.length >= 2) {
        if (SettingsScreen.pushNotificationsEnabled.value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Maximum 2 sensors can be disabled at once.".tr),
              backgroundColor: Colors.redAccent.shade400,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      if (turnOn) {
        disabledSensors.remove(sensorKey);
      } else {
        disabledSensors.add(sensorKey);
      }
    });

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/sensors/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sensor': sensorKey,
          'state': turnOn ? 'on' : 'off',
        }),
      );
    } catch (e) {
      debugPrint("Toggle sensor error: $e");
    }
  }

  Widget _buildSensorHeader(String title, String sensorApiName, bool isDark, {bool useBlue = true}) {
    bool isSensorDisabled = disabledSensors.contains(sensorApiName);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title.tr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSensorDisabled) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "OFF".tr,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.redAccent.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: !isSensorDisabled,
            activeColor: useBlue ? Colors.blueAccent.shade400 : const Color(0xFF1E6B52),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) {
              _toggleSensorState(sensorApiName, val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledState(bool isDark, {bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.sensors_off_rounded,
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          size: compact ? 24 : 32,
        ),
        if (!compact) const SizedBox(height: 8),
        Text(
          "DISABLED".tr,
          style: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<String>(
            valueListenable: currentUserName,
            builder: (context, userName, child) {
              final firstName = userName.split(' ').first;
              return Text(
                "Hi $firstName,",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            "Ready to monitor and manage your farm today?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealWeatherCard(bool isDark, bool isDay) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _greenCardDecoration(isDark, isDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WEATHER OVERVIEW".tr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _locationName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                child: Icon(
                  Icons.satellite_alt_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.elasticOut,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    // --- UPDATED: Dynamic icon and color ---
                    child: Icon(
                      _weatherIcon,
                      color: _weatherIconColor,
                      size: 56,
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _realTemp,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // --- UPDATED: Dynamic weather description ---
                  Text(
                    _realWeatherDesc.tr,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherMiniItem(Icons.water_drop_outlined, "Humidity".tr, _realHumidity),
                    _buildWeatherMiniItem(Icons.umbrella_outlined, "Precipitation".tr, _realPrecipitation),
                    _buildWeatherMiniItem(Icons.air_rounded, "Wind".tr, _realWind),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildWeatherMiniItem(Icons.wb_twilight_rounded, "Dawn".tr, _sunrise),
                    _buildWeatherMiniItem(Icons.nights_stay_outlined, "Dusk".tr, _sunset),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMiniItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildSystemPowerCard(bool isDark, bool isDay) {
    return BouncingButton(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isSystemOn = !_isSystemOn;
        });
        await prefs.setBool('system_on', _isSystemOn);

        if (_isSystemOn) {
          _fetchSensorData();
          _fetchLiveFlowData();
          _fetchFields();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(20),
        decoration: _isSystemOn ? _greenCardDecoration(isDark, isDay) : _glassCardDecoration(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSystemOn ? const Color(0xFF064E3B) : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                boxShadow: _isSystemOn ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)] : [],
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 28,
                color: _isSystemOn ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "SYSTEM POWER".tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isSystemOn ? Colors.white.withOpacity(0.8) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSystemOn ? "SYSTEM ON".tr : "SYSTEM OFF".tr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _isSystemOn ? Colors.white : Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSelector(bool isDark, bool isDay) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _greenCardDecoration(isDark, isDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.landscape_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "ACTIVE FIELD".tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedField != null && _userFields.containsKey(_selectedField) ? _selectedField : null,
                hint: Text("Select Field".tr, style: const TextStyle(color: Colors.white54)),
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF15803D),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                items: _userFields.keys.map((String field) {
                  return DropdownMenuItem<String>(
                    value: field,
                    child: Text(
                      field, 
                      style: const TextStyle(color: Colors.white)
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedField = newValue;
                    });
                    _updateActiveFieldInBackend(newValue);
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Mapped Area:".tr,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
              ),
              Text(
                _selectedField != null ? _userFields[_selectedField] ?? "--" : "--",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Soil Type:".tr,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
              ),
              Text(
                _selectedField != null ? "Loamy".tr : "--", 
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildShadeControlCard(bool isDark, bool isDay) {
    bool isAutoMode = !_shadeOverride; 

    return BouncingButton(
      onTap: () {
        if (isAutoMode) {
          if (SettingsScreen.pushNotificationsEnabled.value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Auto-Shade is ON in Settings. Manual control disabled.".tr),
                backgroundColor: Colors.orangeAccent.shade400,
              ),
            );
          }
          return;
        }

        _updateShadeControl(!isShadeDeployed);
      },
      child: Opacity(
        opacity: isAutoMode ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(20),
          decoration: isShadeDeployed 
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFA7F3D0), Color.fromARGB(255, 144, 202, 179)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6EE7B7).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ) 
              : _glassCardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "FARM SHADE".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isShadeDeployed ? const Color(0xFF064E3B) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isShadeDeployed ? const Color(0xFF022C22) : (isDark ? Colors.grey.shade800 : Colors.white),
                  boxShadow: isShadeDeployed ? [BoxShadow(color: const Color(0xFF022C22).withOpacity(0.2), blurRadius: 10)] : [],
                ),
                child: Icon(
                  Icons.roofing_rounded,
                  size: 36,
                  color: isShadeDeployed ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                ),
              ),
              const Spacer(),
              Text(
                isShadeDeployed ? "DEPLOYED".tr : "RETRACTED".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isShadeDeployed ? const Color(0xFF064E3B) : Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSprinklerControlCard(bool isDark, bool isDay) {
    return BouncingButton(
      onTap: () {
        _updatePumpControl(_pumpMode, _pump1State, _pump2State, isShadeDeployed, !isSprinklerActive);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(20),
        decoration: isSprinklerActive 
            ? BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA7F3D0), Color.fromARGB(255, 144, 202, 179)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6EE7B7).withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ) 
            : _glassCardDecoration(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "SPRINKLER".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSprinklerActive ? const Color(0xFF064E3B) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSprinklerActive ? const Color(0xFF022C22) : (isDark ? Colors.grey.shade800 : Colors.white),
                boxShadow: isSprinklerActive ? [BoxShadow(color: const Color(0xFF022C22).withOpacity(0.2), blurRadius: 10)] : [],
              ),
              child: Icon(
                Icons.shower_rounded,
                size: 36,
                color: isSprinklerActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
              ),
            ),
            const Spacer(),
            Text(
              isSprinklerActive ? "ACTIVE".tr : "INACTIVE".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isSprinklerActive ? const Color(0xFF064E3B) : Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrrigationControlArea(bool isDark, bool isDay) {
    bool isAuto = _pumpMode == 'auto';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _greenCardDecoration(isDark, isDay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "IRRIGATION CONTROL".tr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("AUTO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAuto ? Colors.white : Colors.white54)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: !isAuto,
                  activeColor: const Color.fromARGB(255, 255, 242, 224),
                  inactiveThumbColor: const Color(0xFF064E3B),
                  activeTrackColor: const Color.fromARGB(255, 250, 241, 218).withOpacity(0.3),
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  onChanged: (val) {
                    _updatePumpControl(val ? 'manual' : 'auto', false, false, isShadeDeployed, isSprinklerActive);
                  },
                ),
              ),
              Text("Manual", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !isAuto ? const Color.fromARGB(255, 253, 253, 253) : Colors.white54)),
            ],
          ),
          const Spacer(),
          if (!isAuto)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniPumpToggle("Crop Pump", _pump1State, () => _updatePumpControl('manual', !_pump1State, _pump2State, isShadeDeployed, isSprinklerActive)),
                _buildMiniPumpToggle("Refill Pump", _pump2State, () => _updatePumpControl('manual', _pump1State, !_pump2State, isShadeDeployed, isSprinklerActive)),
              ],
            )
          else
            Center(
              child: Text(
                "Auto mode active.\nSensors manage pumps.".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPumpToggle(String label, bool state, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state ? Colors.cyan.shade400 : Colors.black.withOpacity(0.2),
              boxShadow: state ? [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 8)] : [],
            ),
            child: Icon(Icons.water_drop, color: state ? Colors.white : Colors.white54, size: 16),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSoilCard(bool isDark) {
    double rawCap = double.tryParse(_sensorSoilMoisture) ?? 0.0;
    double capPercent = ((4095 - rawCap) / 4095) * 100;
    capPercent = capPercent.clamp(0, 100);
    String capCondition = rawCap > 2000 ? "DRY" : "WET";
    bool soilDisabled = disabledSensors.contains('soil_moisture');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("CAPACITIVE SOIL", "soil_moisture", isDark),
          const Spacer(),
          Center(
            child: soilDisabled
                ? _buildDisabledState(isDark)
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: capPercent),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return SizedBox(
                        width: 80,
                        height: 80,
                        child: CustomPaint(
                          painter: _GaugePainter(
                            percentage: value,
                            isDark: isDark,
                            primaryColor: capCondition == "WET" ? Colors.blueAccent.shade400 : Colors.orangeAccent,
                          ),
                          child: Center(
                            child: Text(
                              "${value.toInt()}%",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Spacer(),
          Center(
            child: Text(
              "Condition: $capCondition".tr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: capCondition == "WET" ? Colors.blueAccent.shade400 : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepthCard(bool isDark) {
    double rawDepth = double.tryParse(_sensorDepth) ?? 0.0;
    double depthPercent = ((rawDepth) / 4095) * 100;
    depthPercent = depthPercent.clamp(0, 100);
    bool depthDisabled = disabledSensors.contains('depth');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("TANK DEPTH", "depth", isDark),
          const Spacer(),
          Center(
            child: depthDisabled ? _buildDisabledState(isDark) : _WaterTank(depthPercentage: depthPercent),
          ),
          const Spacer(),
          Center(
            child: Text(
              "${'Level:'.tr} ${depthDisabled ? '--' : depthPercent.toInt()}%",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDhtCard(bool isDark) {
    bool dhtDisabled = disabledSensors.contains('temperature');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("DHT11 DATA", "temperature", isDark),
          const Spacer(),
          dhtDisabled
              ? Center(child: _buildDisabledState(isDark))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.thermostat_rounded, color: Colors.orangeAccent.shade400, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          "$_sensorTemperature°",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                    Column(
                      children: [
                        Icon(Icons.water_drop_outlined, color: Colors.blueAccent.shade400, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          "$_sensorHumidity%",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLdrCard(bool isDark) {
    double lightValue = double.tryParse(_sensorLight) ?? 0.0;
    bool ldrDisabled = disabledSensors.contains('ldr');

    String ldrDescription = "Normal Light".tr;
    if (lightValue < 300) ldrDescription = "Dark / Night".tr;
    else if (lightValue < 800) ldrDescription = "Cloudy / Dim".tr;
    else if (lightValue < 2000) ldrDescription = "Normal Light".tr;
    else ldrDescription = "Bright Sun".tr;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("LDR LIGHT", "ldr", isDark),
          const Spacer(),
          ldrDisabled
              ? Center(child: _buildDisabledState(isDark))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.5, end: 0.5 + (lightValue / 2000)),
                      duration: const Duration(seconds: 1),
                      builder: (context, val, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amberAccent.withOpacity(val.clamp(0.0, 1.0) * 0.3),
                          ),
                          child: Icon(
                            Icons.lightbulb,
                            color: Colors.amberAccent,
                            size: 20 * val.clamp(0.8, 1.5),
                          ),
                        );
                      },
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _sensorLight,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text("LUX".tr, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ldrDescription,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(bool isDark, bool isDay) {
    double lightValue = double.tryParse(_sensorLight) ?? 0.0;
    String chargeStatus = "Not Charging".tr;
    
    if (lightValue >= 2000) {
      chargeStatus = "Fast Charging".tr;
    } else if (lightValue >= 300) {
      chargeStatus = "Charging".tr;
    } else {
      chargeStatus = "Not Charging".tr;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: _glassCardDecoration(isDark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "SYSTEM BATTERY".tr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "98",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color, height: 1.0),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text("%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                chargeStatus,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: chargeStatus == "Not Charging".tr ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600) : Colors.blueAccent.shade400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: chargeStatus != "Not Charging".tr ? Colors.blueAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              chargeStatus != "Not Charging".tr ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
              color: chargeStatus != "Not Charging".tr ? Colors.blueAccent.shade400 : Colors.blueAccent.shade400,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainCard(bool isDark) {
    double rainValue = double.tryParse(_sensorRain) ?? 0.0;
    bool rainDisabled = disabledSensors.contains('rain_level');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("RAIN SENSOR", "rain_level", isDark),
          const Spacer(),
          rainDisabled
              ? Center(child: _buildDisabledState(isDark))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 50, width: 60, child: _RainIndicator(intensity: rainValue)),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Rain Condition:".tr,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        Text(
                          getRainCondition(rainValue).tr,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
                        ),
                      ],
                    ),
                  ],
                ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWaterFlowCard(bool isDark) {
    bool flowDisabled = disabledSensors.contains('water_flow');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildSensorHeader("WATER FLOW RATE", "water_flow", isDark)),
              const SizedBox(width: 8),
              _SpinningMotor(isRunning: _motorRunning),
            ],
          ),
          if (flowDisabled)
            Center(child: _buildDisabledState(isDark))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: double.tryParse(_sensorWaterFlowRate) ?? 0.0),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Text(
                      value.toStringAsFixed(2),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.blueAccent.shade400, height: 1.0),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "mL/sec",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.2, end: _motorRunning ? 1.0 : 0.2),
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    curve: Curves.easeInOutSine,
                    builder: (context, val, child) {
                      return Container(
                        width: 6,
                        height: 20 * val,
                        decoration: BoxDecoration(color: Colors.blueAccent.shade400.withOpacity(val), borderRadius: BorderRadius.circular(4)),
                      );
                    },
                    onEnd: () {
                      if (_motorRunning && mounted) setState(() {});
                    },
                  );
                }),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFlowSummaryCard(bool isDark) {
    double totalFlow = _waterFlowHistory.fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble()) / 10.0;
    double lastVol = (double.tryParse(_lastCycleVolume) ?? 0.0) / 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  "TOTAL RECORDED FLOW".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blueAccent.shade200 : Colors.blueAccent.shade700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showWaterFlowHistory,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blueAccent.shade700, shape: BoxShape.circle),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Overall".tr, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    "${totalFlow.toStringAsFixed(1)} mL",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Last Cycle".tr, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    "${lastVol.toStringAsFixed(1)} mL",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSystemOffPlaceholder(bool isDark) {
    return Container(
      key: const ValueKey("sensor_panel_off"),
      height: 200,
      decoration: _glassCardDecoration(isDark),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_off_rounded, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text("System is Offline", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text("Power on the system from the control panel to view live data.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 1100;
    bool isTablet = screenWidth >= 750 && screenWidth < 1100;

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
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInSlide(index: 0, child: _buildGreeting(isDark)),
                    
                    FadeInSlide(
                      index: 1,
                      child: isDesktop || isTablet 
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      SizedBox(height: 200, child: _buildSystemPowerCard(isDark, isDay)),
                                      const SizedBox(height: 16),
                                      SizedBox(height: 200, child: _buildFieldSelector(isDark, isDay)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: SizedBox(height: 200, child: _buildShadeControlCard(isDark, isDay))),
                                          const SizedBox(width: 16),
                                          Expanded(child: SizedBox(height: 200, child: _buildSprinklerControlCard(isDark, isDay))),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(height: 200, child: _buildIrrigationControlArea(isDark, isDay)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(height: 416, child: _buildRealWeatherCard(isDark, isDay)),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SizedBox(height: 200, child: _buildSystemPowerCard(isDark, isDay)),
                                const SizedBox(height: 16),
                                SizedBox(height: 200, child: _buildFieldSelector(isDark, isDay)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: SizedBox(height: 200, child: _buildShadeControlCard(isDark, isDay))),
                                    const SizedBox(width: 16),
                                    Expanded(child: SizedBox(height: 200, child: _buildSprinklerControlCard(isDark, isDay))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(height: 200, child: _buildIrrigationControlArea(isDark, isDay)),
                                const SizedBox(height: 16),
                                _buildRealWeatherCard(isDark, isDay), 
                              ],
                            ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: FadeInSlide(
                        index: 2,
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12, thickness: 1.5)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "SENSOR DATAS".tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12, thickness: 1.5)),
                          ],
                        ),
                      ),
                    ),

                    FadeInSlide(
                      index: 3,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _isSystemOn 
                          ? Column(
                              children: [
                                if (isDesktop || isTablet) ...[
                                  Row(
                                    children: [
                                      Expanded(child: SizedBox(height: 220, child: _buildSoilCard(isDark))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 220, child: _buildDepthCard(isDark))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 220, child: _buildDhtCard(isDark))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 220, child: _buildLdrCard(isDark))),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(child: SizedBox(height: 160, child: _buildBatteryCard(isDark, isDay))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 160, child: _buildRainCard(isDark))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 160, child: _buildWaterFlowCard(isDark))),
                                      const SizedBox(width: 16),
                                      Expanded(child: SizedBox(height: 160, child: _buildFlowSummaryCard(isDark))),
                                    ],
                                  ),
                                ] else ...[
                                  SizedBox(height: 220, child: _buildSoilCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 220, child: _buildDepthCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildDhtCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildLdrCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildBatteryCard(isDark, isDay)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildRainCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildWaterFlowCard(isDark)),
                                  const SizedBox(height: 16),
                                  SizedBox(height: 180, child: _buildFlowSummaryCard(isDark)),
                                ]
                              ],
                            )
                          : _buildSystemOffPlaceholder(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterTank extends StatelessWidget {
  final double depthPercentage;
  const _WaterTank({required this.depthPercentage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clampedDepth = depthPercentage.clamp(0.0, 100.0) / 100.0;

    return Container(
      width: 50,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            height: 76 * clampedDepth,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueAccent.shade400.withOpacity(0.9),
              borderRadius: BorderRadius.only(
                bottomLeft: const Radius.circular(10),
                bottomRight: const Radius.circular(10),
                topLeft: Radius.circular(clampedDepth > 0.95 ? 10 : 0),
                topRight: Radius.circular(clampedDepth > 0.95 ? 10 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinningMotor extends StatefulWidget {
  final bool isRunning;
  const _SpinningMotor({required this.isRunning});

  @override
  State<_SpinningMotor> createState() => _SpinningMotorState();
}

class _SpinningMotorState extends State<_SpinningMotor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SpinningMotor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !oldWidget.isRunning) {
      _controller.repeat();
    } else if (!widget.isRunning && oldWidget.isRunning) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: widget.isRunning
            ? Colors.blueAccent.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: child,
          );
        },
        child: Icon(
          Icons.settings,
          color: widget.isRunning ? Colors.blueAccent.shade400 : Colors.grey,
          size: 16,
        ),
      ),
    );
  }
}

class _RainIndicator extends StatefulWidget {
  final double intensity;
  const _RainIndicator({required this.intensity});

  @override
  State<_RainIndicator> createState() => _RainIndicatorState();
}

class _RainIndicatorState extends State<_RainIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkStatus();
  }

  @override
  void didUpdateWidget(covariant _RainIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkStatus();
  }

  void _checkStatus() {
    if (widget.intensity < 3000) {
      int durationMs = 800;
      if (widget.intensity >= 2000) {
        durationMs = 1200;
      } else if (widget.intensity >= 1000) {
        durationMs = 800;
      } else {
        durationMs = 400;
      }
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          widget.intensity < 3000 ? Icons.cloud : Icons.cloud_off_rounded,
          size: 32,
          color: widget.intensity < 3000
              ? Colors.blueAccent.shade200
              : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
        ),
        if (widget.intensity < 3000)
          Positioned(
            top: 28,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    double delay = index * 0.3;
                    double yPos = ((_controller.value + delay) % 1.0) * 15;
                    double opacity = 1.0 - ((_controller.value + delay) % 1.0);
                    return Transform.translate(
                      offset: Offset(
                        index == 1 ? 0 : (index == 0 ? -8 : 8),
                        yPos,
                      ),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 2,
                          height: 6,
                          color: Colors.blueAccent.shade400,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final bool isDark;
  final Color primaryColor;

  _GaugePainter({
    required this.percentage,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;
    const startAngle = 2.5;
    const sweepAngle = 4.4;

    final backgroundPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    final foregroundPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressAngle = sweepAngle * (percentage.clamp(0, 100) / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.isDark != isDark;
  }
}