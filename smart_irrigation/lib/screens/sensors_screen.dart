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

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  bool _isSystemOn = true;

  String _pumpMode = "auto";
  bool _pump1State = false;
  bool _pump2State = false;

  bool isShadeDeployed = false;
  bool isSprinklerActive = false;
  bool _shadeOverride = false;

  Set<String> disabledSensors = {};

  Timer? _timer;
  String _sensorTemperature = "28.7";
  String _sensorHumidity = "63";
  String _sensorSoilMoisture = "45";
  String _sensorWaterFlow = "7.0";
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

  List<Map<String, dynamic>> _waterFlowHistory = [];

  String _selectedField = "North Plot A";
  final Map<String, String> _userFields = {
    "North Plot A": "4.5 Acres",
    "South Plot B": "2.1 Acres",
    "Greenhouse 1": "800 sq.m",
    "East Field": "5.0 Acres",
  };

  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _fetchInitialHistory();
    _initLocationAndWeather();
    _fetchSensorData();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        if (_isSystemOn) _fetchSensorData();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

    if (value >= 3000) {
      return "No Rain (Dry)";
    } else if (value >= 2000 && value < 3000) {
      return "Light Rain";
    } else if (value >= 1000 && value < 2000) {
      return "Moderate Rain";
    } else {
      return "Heavy Rain";
    }
  }

  String _formatDate(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return "${date.day}/${date.month}/${date.year} $hour:$min $ampm";
  }

  void _showWaterFlowHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.grey.shade300,
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
                                color: Colors.cyan.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.water_drop,
                                color: Colors.cyan,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              "${(item['amount'] as double).toStringAsFixed(2)} mL".tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(item['time']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
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
                  child: Text("Close".tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchWeatherData(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m&daily=sunrise,sunset&timezone=auto');
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
    try {
      final ctrlRes =
          await http.get(Uri.parse('${AppConfig.baseUrl}/control/status'));
      if (ctrlRes.statusCode == 200) {
        final cData = json.decode(ctrlRes.body);
        if (mounted) {
          setState(() {
            _pumpMode = cData['mode'] ?? "auto";
            _pump1State = cData['pump1'] ?? false;
            _pump2State = cData['pump2'] ?? false;
            isShadeDeployed = cData['shade'] ?? isShadeDeployed;
            isSprinklerActive = cData['sprinkler'] ?? isSprinklerActive;
            _motorRunning = _pump1State || _pump2State;
          });
        }
      }

      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/sensors/current'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _sensorTemperature = data['temperature']?.toString() ?? "28.7";
            _sensorHumidity = data['humidity']?.toString() ?? "63";
            _sensorSoilMoisture = data['soil_moisture']?.toString() ?? "45";
            _sensorLight = data['ldr']?.toString() ?? "850";
            _sensorWaterFlow = data['water_flow']?.toString() ?? "7.0";
            _sensorRain = data['rain_level']?.toString() ?? "15";
            _sensorDepth = data['depth']?.toString() ?? "75";

            if (data['last_cycle_volume'] != null) {
              String newLcv = data['last_cycle_volume'].toString();
              double nLcv = double.tryParse(newLcv) ?? 0.0;
              double oLcv = double.tryParse(_lastCycleVolume) ?? 0.0;

              if (nLcv > 0 && nLcv != oLcv) {
                _waterFlowHistory
                    .insert(0, {'amount': nLcv, 'time': DateTime.now()});
              }
              _lastCycleVolume = newLcv;
            }

            if (_pumpMode == 'auto') {
              if (data['motor'] != null) {
                _motorRunning = data['motor'] == true || data['motor'] == "true";
              } else if (double.tryParse(_sensorWaterFlow)! > 0) {
                _motorRunning = true;
              } else {
                _motorRunning = false;
              }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to communicate with pump controller")),
        );
      }
    }
  }

  Future<void> _toggleSensorState(String sensorKey, bool turnOn) async {
    if (!turnOn) {
      if (disabledSensors.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Maximum 2 sensors can be disabled at once.".tr),
            backgroundColor: Colors.redAccent.shade400,
          ),
        );
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

  Widget _buildSensorHeader(String title, String sensorApiName, bool isDark) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
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
            activeColor: const Color(0xFF10B981),
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

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.3, 1.0],
        colors: [
          isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
          isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.3),
          isDark ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 10),
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
          Text(
            "Hi Hrichik,",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge!.color,
              letterSpacing: -0.5,
            ),
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

  Widget _buildSystemPowerCard(bool isDark) {
    return BouncingButton(
      onTap: () {
        setState(() {
          _isSystemOn = !_isSystemOn;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.3, 1.0],
            colors: _isSystemOn
                ? [
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.25 : 0.4),
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.15 : 0.2),
                    Colors.tealAccent.shade400.withOpacity(isDark ? 0.05 : 0.05)
                  ]
                : [
                    isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
                    isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.3),
                    isDark ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSystemOn
                ? Colors.greenAccent.withOpacity(0.6)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8)),
            width: _isSystemOn ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isSystemOn 
                  ? Colors.greenAccent.withOpacity(isDark ? 0.4 : 0.25)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: _isSystemOn ? 30 : 24,
              spreadRadius: _isSystemOn ? 2 : -4,
              offset: Offset(0, _isSystemOn ? 8 : 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isSystemOn
                      ? [Colors.greenAccent.shade400, Colors.tealAccent.shade400]
                      : [isDark ? Colors.grey.shade800 : Colors.grey.shade300, isDark ? Colors.grey.shade900 : Colors.grey.shade200],
                ),
                boxShadow: _isSystemOn
                    ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)]
                    : [],
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 32,
                color: _isSystemOn ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "SYSTEM POWER".tr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isSystemOn
                        ? Colors.greenAccent.shade700
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSystemOn ? "SYSTEM ON".tr : "SYSTEM OFF".tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _isSystemOn
                        ? Colors.greenAccent.shade700
                        : Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.landscape_rounded, color: Colors.greenAccent.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                "ACTIVE FIELD".tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedField,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF06180F) : Colors.white,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                items: _userFields.keys.map((String field) {
                  return DropdownMenuItem<String>(
                    value: field,
                    child: Text(field),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedField = newValue;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Mapped Area:".tr,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Text(
                _userFields[_selectedField] ?? "--",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.greenAccent.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationControlArea(bool isDark) {
    bool isAuto = _pumpMode == 'auto';
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "IRRIGATION".tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("AUTO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAuto ? Colors.greenAccent.shade700 : Colors.grey)),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: !isAuto,
                  activeColor: Colors.orangeAccent,
                  inactiveThumbColor: Colors.greenAccent.shade400,
                  activeTrackColor: Colors.orangeAccent.withOpacity(0.3),
                  inactiveTrackColor: Colors.greenAccent.withOpacity(0.3),
                  onChanged: (val) {
                    _updatePumpControl(val ? 'manual' : 'auto', false, false, isShadeDeployed, isSprinklerActive);
                  },
                ),
              ),
              Text("Manual", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: !isAuto ? Colors.orangeAccent : Colors.grey)),
            ],
          ),
          const Spacer(),
          if (!isAuto)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniPumpToggle("Irrigation Pump", _pump1State, () => _updatePumpControl('manual', !_pump1State, _pump2State, isShadeDeployed, isSprinklerActive)),
                _buildMiniPumpToggle("Reservoir Refill Pump", _pump2State, () => _updatePumpControl('manual', _pump1State, !_pump2State, isShadeDeployed, isSprinklerActive)),
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Auto mode active.\nSensors control pumps.".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state ? Colors.cyan.shade600 : Colors.grey.withOpacity(0.2),
              boxShadow: state ? [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 8)] : [],
            ),
            child: Icon(Icons.water_drop, color: state ? Colors.white : Colors.grey, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildShadeControlCard(bool isDark) {
    return BouncingButton(
      onTap: () {
        if (!_shadeOverride) {
          setState(() {
            _shadeOverride = true;
          });
        }
        _updatePumpControl(_pumpMode, _pump1State, _pump2State, !isShadeDeployed, isSprinklerActive);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.3, 1.0],
            colors: isShadeDeployed
                ? [
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.25 : 0.4),
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.15 : 0.2),
                    Colors.tealAccent.shade400.withOpacity(isDark ? 0.05 : 0.05)
                  ]
                : [
                    isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
                    isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.3),
                    isDark ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isShadeDeployed
                ? Colors.greenAccent.withOpacity(0.6)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8)),
            width: isShadeDeployed ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isShadeDeployed 
                  ? Colors.greenAccent.withOpacity(isDark ? 0.4 : 0.25)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: isShadeDeployed ? 30 : 24,
              spreadRadius: isShadeDeployed ? 2 : -4,
              offset: Offset(0, isShadeDeployed ? 8 : 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "FARM SHADE".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isShadeDeployed
                    ? Colors.greenAccent.shade700
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isShadeDeployed
                      ? [Colors.greenAccent.shade400, Colors.tealAccent.shade400]
                      : [isDark ? Colors.grey.shade800 : Colors.grey.shade300, isDark ? Colors.grey.shade900 : Colors.grey.shade200],
                ),
                boxShadow: isShadeDeployed
                    ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)]
                    : [],
              ),
              child: Icon(
                Icons.roofing_rounded,
                size: 32,
                color: isShadeDeployed
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
              ),
            ),
            const Spacer(),
            Text(
              isShadeDeployed ? "DEPLOYED".tr : "RETRACTED".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isShadeDeployed
                    ? Colors.greenAccent.shade700
                    : Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSprinklerControlCard(bool isDark) {
    return BouncingButton(
      onTap: () {
        _updatePumpControl(_pumpMode, _pump1State, _pump2State, isShadeDeployed, !isSprinklerActive);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.3, 1.0],
            colors: isSprinklerActive
                ? [
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.25 : 0.4),
                    Colors.greenAccent.shade400.withOpacity(isDark ? 0.15 : 0.2),
                    Colors.tealAccent.shade400.withOpacity(isDark ? 0.05 : 0.05)
                  ]
                : [
                    isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
                    isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.3),
                    isDark ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSprinklerActive
                ? Colors.greenAccent.withOpacity(0.6)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8)),
            width: isSprinklerActive ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSprinklerActive 
                  ? Colors.greenAccent.withOpacity(isDark ? 0.4 : 0.25)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: isSprinklerActive ? 30 : 24,
              spreadRadius: isSprinklerActive ? 2 : -4,
              offset: Offset(0, isSprinklerActive ? 8 : 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "SPRINKLER".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSprinklerActive
                    ? Colors.greenAccent.shade700
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSprinklerActive
                      ? [Colors.greenAccent.shade400, Colors.tealAccent.shade400]
                      : [isDark ? Colors.grey.shade800 : Colors.grey.shade300, isDark ? Colors.grey.shade900 : Colors.grey.shade200],
                ),
                boxShadow: isSprinklerActive
                    ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)]
                    : [],
              ),
              child: Icon(
                Icons.shower_rounded,
                size: 32,
                color: isSprinklerActive
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
              ),
            ),
            const Spacer(),
            Text(
              isSprinklerActive ? "ACTIVE".tr : "INACTIVE".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isSprinklerActive
                    ? Colors.greenAccent.shade700
                    : Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomShadeCard(bool isDark) {
    bool isAuto = !_shadeOverride;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge!.color;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FARM SHADE RETRACTOR".tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 50,
                child: Center(
                  child: _ShadeAnimation(isDeployed: isShadeDeployed),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isShadeDeployed ? "DEPLOYED".tr : "RETRACTED".tr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    "Status".tr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: !isAuto,
                      activeColor: Colors.orangeAccent,
                      inactiveThumbColor: Colors.greenAccent.shade400,
                      activeTrackColor: Colors.orangeAccent.withOpacity(0.3),
                      inactiveTrackColor: Colors.greenAccent.withOpacity(0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          _shadeOverride = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAuto ? "AUTO".tr : "MANUAL".tr,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isAuto ? Colors.greenAccent.shade700 : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              if (!isAuto)
                GestureDetector(
                  onTap: () {
                    _updatePumpControl(_pumpMode, _pump1State, _pump2State, !isShadeDeployed, isSprinklerActive);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isShadeDeployed ? Colors.greenAccent.shade700 : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isShadeDeployed ? Colors.transparent : Colors.grey.shade400,
                      ),
                      boxShadow: isShadeDeployed ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Text(
                      isShadeDeployed ? "RETRACT".tr : "DEPLOY".tr,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isShadeDeployed ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  isShadeDeployed ? "Sensors Deployed".tr : "Sensors Retracted".tr,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(bool isDark, bool isDay) {
    double lightValue = double.tryParse(_sensorLight) ?? 0.0;
    bool isCharging = isDay && lightValue > 500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: _cardDecoration(isDark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      "%",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCharging ? Colors.greenAccent.withOpacity(0.2) : Colors.greenAccent.shade400.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCharging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
              color: isCharging ? Colors.greenAccent.shade700 : Colors.greenAccent.shade700,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealWeatherCard(bool isDark, bool isDay) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? (isDay
                  ? [const Color(0xFF065F46).withOpacity(0.8), const Color(0xFF022C22).withOpacity(0.8)]
                  : [const Color(0xFF064E3B).withOpacity(0.8), const Color(0xFF020617).withOpacity(0.8)])
              : (isDay
                  ? [Colors.teal.shade400.withOpacity(0.9), Colors.greenAccent.shade400.withOpacity(0.9)]
                  : [const Color(0xFF0F766E).withOpacity(0.9), const Color(0xFF064E3B).withOpacity(0.9)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.tealAccent.withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
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
          const SizedBox(height: 24),
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
                    child: Icon(
                      isDay
                          ? Icons.wb_sunny_rounded
                          : Icons.nights_stay_rounded,
                      color: isDay
                          ? Colors.yellowAccent.shade400
                          : Colors.teal.shade100,
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
                  Text(
                    isDay ? "Sunny & Clear".tr : "Clear Night".tr,
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
          const SizedBox(height: 24),
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
                    _buildWeatherMiniItem(
                      Icons.water_drop_outlined,
                      "Humidity".tr,
                      _realHumidity,
                    ),
                    _buildWeatherMiniItem(
                      Icons.umbrella_outlined,
                      "Precipitation".tr,
                      _realPrecipitation,
                    ),
                    _buildWeatherMiniItem(
                      Icons.air_rounded,
                      "Wind".tr,
                      _realWind,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildWeatherMiniItem(
                      Icons.wb_twilight_rounded,
                      "Dawn".tr,
                      _sunrise,
                    ),
                    _buildWeatherMiniItem(
                      Icons.nights_stay_outlined,
                      "Dusk".tr,
                      _sunset,
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

  Widget _buildSoilCard(bool isDark) {
    double rawCap = double.tryParse(_sensorSoilMoisture) ?? 0.0;
    double capPercent = ((4095 - rawCap) / 4095) * 100;
    capPercent = capPercent.clamp(0, 100);
    String capCondition = rawCap > 2000 ? "DRY" : "WET";
    bool soilDisabled = disabledSensors.contains('soil_moisture');

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("CAPACITIVE SOIL", "soil_moisture", isDark),
          const Spacer(),
          Center(
            child: soilDisabled
                ? _buildDisabledState(isDark)
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: capPercent,
                    ),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: _GaugePainter(
                            percentage: value,
                            isDark: isDark,
                            primaryColor: capCondition == "WET" ? Colors.greenAccent.shade700 : Colors.orangeAccent,
                          ),
                          child: Center(
                            child: Text(
                              "${value.toInt()}%",
                              style: TextStyle(
                                fontSize: 24,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: capCondition == "WET" ? Colors.greenAccent.shade700 : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepthCard(bool isDark) {
    double rawDepth = double.tryParse(_sensorDepth) ?? 0.0;
    double depthPercent = (rawDepth / 4095) * 100;
    depthPercent = depthPercent.clamp(0, 100);
    bool depthDisabled = disabledSensors.contains('depth');

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSensorHeader("TANK DEPTH", "depth", isDark),
          const Spacer(),
          Center(
            child: depthDisabled
                ? _buildDisabledState(isDark)
                : _WaterTank(depthPercentage: depthPercent),
          ),
          const Spacer(),
          Center(
            child: Text(
              "${'Level:'.tr} ${depthDisabled ? '--' : depthPercent.toInt()}%",
              style: TextStyle(
                fontSize: 14,
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
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
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
                        Icon(
                          Icons.thermostat_rounded,
                          color: Colors.orangeAccent.shade400,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$_sensorTemperature°",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          color: Colors.cyan.shade400,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$_sensorHumidity%",
                          style: TextStyle(
                            fontSize: 20,
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
    if (lightValue < 300) {
      ldrDescription = "Dark / Night".tr;
    } else if (lightValue < 800) {
      ldrDescription = "Cloudy / Dim".tr;
    } else if (lightValue < 2000) {
      ldrDescription = "Normal Light".tr;
    } else {
      ldrDescription = "Bright Sun".tr;
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
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
                      tween: Tween<double>(
                        begin: 0.5,
                        end: 0.5 + (lightValue / 2000),
                      ),
                      duration: const Duration(seconds: 1),
                      builder: (context, val, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amberAccent.withOpacity(
                              val.clamp(0.0, 1.0) * 0.3,
                            ),
                          ),
                          child: Icon(
                            Icons.lightbulb,
                            color: Colors.amberAccent,
                            size: 24 * val.clamp(0.8, 1.5),
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "LUX".tr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ldrDescription,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent.shade700,
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

  Widget _buildRainCard(bool isDark) {
    double rainValue = double.tryParse(_sensorRain) ?? 0.0;
    bool rainDisabled = disabledSensors.contains('rain_level');

    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
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
                    SizedBox(
                      height: 60,
                      width: 80,
                      child: _RainIndicator(intensity: rainValue),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Rain Condition:".tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          getRainCondition(rainValue).tr,
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

  Widget _buildWaterFlowCard(bool isDark) {
    bool flowDisabled = disabledSensors.contains('water_flow');
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSensorHeader("WATER FLOW RATE", "water_flow", isDark),
              ),
              const SizedBox(width: 8),
              _SpinningMotor(isRunning: _motorRunning),
            ],
          ),
          const Spacer(),
          flowDisabled
              ? Center(child: _buildDisabledState(isDark))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: double.tryParse(_sensorWaterFlow) ?? 0.0,
                      ),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Text(
                          value.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.cyan.shade600,
                            height: 1.0,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "mL/sec",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          if (!flowDisabled)
            SizedBox(
              height: 30,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.2,
                      end: _motorRunning ? 1.0 : 0.2,
                    ),
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    curve: Curves.easeInOutSine,
                    builder: (context, val, child) {
                      return Container(
                        width: 8,
                        height: 30 * val,
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade400.withOpacity(val),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                    onEnd: () {
                      if (_motorRunning && mounted) setState(() {});
                    },
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlowSummaryCard(bool isDark) {
    double totalFlow = _waterFlowHistory.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );
    double lastVol = double.tryParse(_lastCycleVolume) ?? 0.0;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.3, 1.0],
          colors: [
            Colors.greenAccent.shade400.withOpacity(isDark ? 0.2 : 0.3),
            Colors.tealAccent.shade400.withOpacity(isDark ? 0.05 : 0.1),
            Colors.white.withOpacity(isDark ? 0.01 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(isDark ? 0.4 : 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.greenAccent.shade100 : Colors.greenAccent.shade700,
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
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "${totalFlow.toStringAsFixed(2)} mL",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          Text(
            "Overall Usage".tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Last Cycle Delivered:".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.greenAccent.shade100 : Colors.greenAccent.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "${lastVol.toStringAsFixed(2)} mL",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOffPlaceholder(bool isDark) {
    return Container(
      key: const ValueKey("sensor_panel_off"),
      height: 400,
      decoration: _cardDecoration(isDark),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_off_rounded,
              size: 80,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "System is Offline",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Power on the system from the left pane to view live data.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final hour = DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 1100;
    bool isTablet = screenWidth >= 750 && screenWidth < 1100;

    Widget leftPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSystemPowerCard(isDark),
        const SizedBox(height: 16),
        _buildFieldSelector(isDark),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildShadeControlCard(isDark)),
            const SizedBox(width: 16),
            Expanded(child: _buildSprinklerControlCard(isDark)),
          ],
        ),
        const SizedBox(height: 16),
        _buildBottomShadeCard(isDark),
        const SizedBox(height: 16),
        _buildIrrigationControlArea(isDark),
      ],
    );

    Widget centerPane = AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _isSystemOn
          ? Column(
              key: const ValueKey("sensor_panel_on"),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSoilCard(isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDepthCard(isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDhtCard(isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLdrCard(isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRainCard(isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildWaterFlowCard(isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFlowSummaryCard(isDark)),
                  ],
                ),
              ],
            )
          : _buildSystemOffPlaceholder(isDark),
    );

    Widget rightPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBatteryCard(isDark, isDay),
        const SizedBox(height: 16),
        _buildRealWeatherCard(isDark, isDay),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF021509) : const Color(0xFFEAF5EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              "Agro",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodyLarge!.color,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Sync",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.greenAccent.shade400,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.spa_rounded, color: Colors.greenAccent.shade400, size: 34),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_active_rounded,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.greenAccent.shade400, width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Icon(
                Icons.person_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                      ? [const Color(0xFF042F1A), const Color(0xFF011208)]
                      : [const Color(0xFFD1EAE0), const Color(0xFFB5DCC9)],
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
                      Colors.white.withOpacity(isDark ? 0.12 : 0.3),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInSlide(index: 0, child: _buildGreeting(isDark)),
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: FadeInSlide(index: 1, child: leftPane)),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: FadeInSlide(index: 2, child: centerPane)),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: FadeInSlide(index: 3, child: rightPane)),
                            ],
                          )
                        : isTablet
                            ? Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: FadeInSlide(index: 1, child: leftPane)),
                                      const SizedBox(width: 16),
                                      Expanded(child: FadeInSlide(index: 3, child: rightPane)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  FadeInSlide(index: 2, child: centerPane),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FadeInSlide(index: 1, child: leftPane),
                                  const SizedBox(height: 24),
                                  FadeInSlide(index: 3, child: rightPane),
                                  const SizedBox(height: 24),
                                  FadeInSlide(index: 2, child: centerPane),
                                ],
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
      width: 60,
      height: 100,
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
            height: 96 * clampedDepth,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.cyan.shade400.withOpacity(0.9),
              borderRadius: BorderRadius.only(
                bottomLeft: const Radius.circular(10),
                bottomRight: const Radius.circular(10),
                topLeft: Radius.circular(clampedDepth > 0.95 ? 10 : 0),
                topRight: Radius.circular(clampedDepth > 0.95 ? 10 : 0),
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
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
            ? Colors.greenAccent.withOpacity(0.2)
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
          color: widget.isRunning ? Colors.greenAccent.shade700 : Colors.grey,
          size: 20,
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
          size: 40,
          color: widget.intensity < 3000
              ? Colors.cyan.shade300
              : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
        ),
        if (widget.intensity < 3000)
          Positioned(
            top: 35,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    double delay = index * 0.3;
                    double yPos = ((_controller.value + delay) % 1.0) * 20;
                    double opacity = 1.0 - ((_controller.value + delay) % 1.0);
                    return Transform.translate(
                      offset: Offset(
                        index == 1 ? 0 : (index == 0 ? -10 : 10),
                        yPos,
                      ),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 2,
                          height: 8,
                          color: Colors.cyan.shade400,
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
    const strokeWidth = 10.0;
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

class _ShadeAnimation extends StatelessWidget {
  final bool isDeployed;
  const _ShadeAnimation({required this.isDeployed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final frameColor = isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3);
    final groundColor = isDark ? const Color(0xFF3F2A14).withOpacity(0.8) : const Color(0xFF8B5A2B).withOpacity(0.8);
    final shadeColor = isDark ? const Color(0xFF111111).withOpacity(0.9) : const Color(0xFF333333).withOpacity(0.9);

    return Container(
      width: 100,
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: frameColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 3,
                child: Container(color: isDark ? Colors.black26 : Colors.cyan.shade100.withOpacity(0.5)),
              ),
              Expanded(
                flex: 1,
                child: Container(color: groundColor),
              ),
            ],
          ),
          Positioned(
            bottom: 6,
            left: 40,
            child: Icon(
              Icons.yard_rounded,
              color: Colors.greenAccent.shade700,
              size: 24,
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            opacity: isDeployed ? 0.5 : 0.0,
            child: Positioned(
              bottom: 2,
              left: 10,
              right: 10,
              height: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            top: 0,
            bottom: 10,
            left: isDeployed ? 0 : -90,
            width: 85,
            child: Container(
              decoration: BoxDecoration(
                color: shadeColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  )
                ],
              ),
              child: Row(
                children: List.generate(5, (index) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 2,
            bottom: 10,
            width: 3,
            child: Container(color: frameColor),
          ),
          Positioned(
            right: 2,
            top: 2,
            bottom: 10,
            width: 3,
            child: Container(color: frameColor),
          ),
        ],
      ),
    );
  }
}