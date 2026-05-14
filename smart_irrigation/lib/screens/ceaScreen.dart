import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/translations.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/fade_in_slide.dart';
import '../core/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/globals.dart';

class CeaScreen extends StatefulWidget {
  const CeaScreen({super.key});

  @override
  State<CeaScreen> createState() => _CeaScreenState();
}

class _CeaScreenState extends State<CeaScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; 

  bool _isSystemOn = true;
  String _ceaMode = "auto"; // 'auto' or 'manual'

  // Primary Actuator States
  bool _peltierCoolerState = false;
  bool _dehumidifierState = false;
  bool _growLightsState = false;

  // Newly added placeholders for CEA V2 hardware.
  bool _mistMakerActive = false; 
  bool _fan1Active = false;
  bool _fan2Active = false;

  // Sensor Data (Hardcoded for now)
  String _currentTemp = "26.5";
  String _currentHumidity = "68";
  String _currentLight = "450";
  String _currentGas = "410"; // ppm value for air quality / CO2

  // Target Biome Data
  String? _selectedCrop;
  final Map<String, Map<String, double>> _cropBiomes = {
    "Sharbati Wheat (Simulated)": {"temp": 22.0, "humidity": 45.0, "light": 2000.0},
    "Hydroponic Lettuce": {"temp": 18.0, "humidity": 60.0, "light": 1500.0},
    "Saffron Crocus": {"temp": 15.0, "humidity": 40.0, "light": 1800.0},
  };

  Timer? _timer;
  WebSocketChannel? _channel;
  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _selectedCrop = _cropBiomes.keys.first;
    _loadPersistedState();
    _fetchCeaData();
    _initWebSocket();
    
    // Polling backup
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        if (_isSystemOn) _fetchCeaData(); 
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _initWebSocket() {
    // --- HARDCODED MODE: WebSocket connection temporarily disabled ---
    /*
    final wsUrl = AppConfig.baseUrl.replaceFirst('http', 'ws') + '/cea/ws';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen(
      (message) {
        if (!_isSystemOn) return;
        final data = json.decode(message);
        
        if (mounted) {
          setState(() {
            if (data['type'] == 'cea_update') {
              _currentTemp = data['temperature']?.toString() ?? _currentTemp;
              _currentHumidity = data['humidity']?.toString() ?? _currentHumidity;
              _currentLight = data['light_lux']?.toString() ?? _currentLight;
              _currentGas = data['gas_ppm']?.toString() ?? _currentGas;
              
              _peltierCoolerState = data['peltier_active'] ?? _peltierCoolerState;
              _dehumidifierState = data['dehumidifier_active'] ?? _dehumidifierState;
              _growLightsState = data['grow_lights_active'] ?? _growLightsState;
            }
          });
        }
      },
      onError: (error) {
        Future.delayed(const Duration(seconds: 5), _initWebSocket);
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 5), _initWebSocket);
      },
    );
    */
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSystemOn = prefs.getBool('cea_system_on') ?? true;
      });
    }
  }

  Future<void> _fetchCeaData() async {
    // --- HARDCODED MODE: Backend fetching temporarily disabled ---
    /*
    if (!_isSystemOn) return; 
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/cea/current'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _currentTemp = data['temperature']?.toString() ?? _currentTemp;
            _currentHumidity = data['humidity']?.toString() ?? _currentHumidity;
            _ceaMode = data['mode'] ?? "auto";
          });
        }
      }
    } catch (e) {
      // log error or ignore quietly
    }
    */
  }

  Future<void> _updateCeaActuators(String mode, bool peltier, bool dehumidifier, bool lights) async {
    // Only update the local UI state
    setState(() {
      _ceaMode = mode;
      _peltierCoolerState = peltier;
      _dehumidifierState = dehumidifier;
      _growLightsState = lights;
    });

    // --- HARDCODED MODE: Backend POST request temporarily disabled ---
    /*
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/control/cea'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mode': mode,
          'peltier': peltier,
          'dehumidifier': dehumidifier,
          'grow_lights': lights
        }),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to communicate with CEA controller".tr)),
        );
      }
    }
    */
  }

  // Visual styling helpers
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

  BoxDecoration _purpleCardDecoration(bool isDark) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B21A8), Color(0xFF3B0764)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3B0764).withOpacity(isDark ? 0.3 : 0.2),
          blurRadius: 25,
          spreadRadius: -5,
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
          ValueListenableBuilder<String>(
            valueListenable: currentUserName,
            builder: (context, userName, child) {
              return Text(
                "Controlled Env,".tr,
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
            "Simulating ideal biomes for non-native crops.".tr,
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
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        setState(() => _isSystemOn = !_isSystemOn);
        await prefs.setBool('cea_system_on', _isSystemOn);

        if (_isSystemOn) _fetchCeaData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(20),
        decoration: _isSystemOn ? _purpleCardDecoration(isDark) : _glassCardDecoration(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSystemOn ? const Color(0xFF4C1D95) : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
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
                mainAxisSize: MainAxisSize.min, // Added for safety
                children: [
                  Text(
                    "CEA POWER".tr,
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

  Widget _buildBiomeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _purpleCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // FIX: Shrink-wrap to content
        children: [
          Row(
            children: [
              const Icon(Icons.biotech_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "TARGET BIOME".tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24), // FIX: Replaced Spacer()
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCrop,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF2E1065) : const Color(0xFF6B21A8),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                items: _cropBiomes.keys.map((String crop) {
                  return DropdownMenuItem<String>(
                    value: crop,
                    child: Text(crop, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedCrop = newValue);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32), // FIX: Replaced Spacer()
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Target Temp:".tr, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
              Text("${_cropBiomes[_selectedCrop!]!["temp"]}°C", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Target Humidity:".tr, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
              Text("${_cropBiomes[_selectedCrop!]!["humidity"]}%", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareControlArea(bool isDark) {
    bool isAuto = _ceaMode == 'auto';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // FIX: Shrink-wrap to content
        children: [
          Text(
            "HARDWARE OVERRIDE".tr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("AUTO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAuto ? Colors.blueAccent.shade400 : Colors.grey)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: !isAuto,
                  activeColor: Colors.deepPurpleAccent,
                  inactiveThumbColor: Colors.blueAccent,
                  onChanged: (val) {
                    _updateCeaActuators(val ? 'manual' : 'auto', _peltierCoolerState, _dehumidifierState, _growLightsState);
                  },
                ),
              ),
              Text("Manual", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !isAuto ? Colors.deepPurpleAccent : Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          if (!isAuto)
            Wrap( // FIX: Removed Expanded and SingleChildScrollView wrappers here
              spacing: 16,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildMiniActuatorToggle("Peltier", Icons.ac_unit, _peltierCoolerState, () => _updateCeaActuators('manual', !_peltierCoolerState, _dehumidifierState, _growLightsState)),
                _buildMiniActuatorToggle("Silica", Icons.air, _dehumidifierState, () => _updateCeaActuators('manual', _peltierCoolerState, !_dehumidifierState, _growLightsState)),
                _buildMiniActuatorToggle("Lights", Icons.light_mode, _growLightsState, () => _updateCeaActuators('manual', _peltierCoolerState, _dehumidifierState, !_growLightsState)),
                
                // Local state updates for placeholders
                _buildMiniActuatorToggle("Mist Maker", Icons.water_drop, _mistMakerActive, () => setState(() => _mistMakerActive = !_mistMakerActive)),
                _buildMiniActuatorToggle("Fan 1", Icons.toys, _fan1Active, () => setState(() => _fan1Active = !_fan1Active)),
                _buildMiniActuatorToggle("Fan 2", Icons.toys, _fan2Active, () => setState(() => _fan2Active = !_fan2Active)),
              ],
            )
          else
            Padding( // FIX: Replaced Expanded with Padding
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "Auto mode active.\nSystem simulating $_selectedCrop.".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildMiniActuatorToggle(String label, IconData icon, bool state, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70, // keeps wrap items nicely aligned
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state ? Colors.deepPurpleAccent : Colors.black.withOpacity(0.05),
                boxShadow: state ? [BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.5), blurRadius: 8)] : [],
              ),
              child: Icon(icon, color: state ? Colors.white : Colors.grey, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentOverview(bool isDark) {
    double tTemp = _cropBiomes[_selectedCrop!]!["temp"]!;
    double tHum = _cropBiomes[_selectedCrop!]!["humidity"]!;
    double cTemp = double.tryParse(_currentTemp) ?? 0.0;
    double cHum = double.tryParse(_currentHumidity) ?? 0.0;

    bool tempMatch = (cTemp - tTemp).abs() <= 1.5;
    bool humMatch = (cHum - tHum).abs() <= 5.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _glassCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // FIX: Shrink-wrap to content
        children: [
          Text(
            "ENVIRONMENTAL DRIFT".tr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 24), // FIX: Replaced Spacer()
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDiffDial("Temp", cTemp, tTemp, tempMatch, "°C", isDark),
              Container(width: 1, height: 60, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              _buildDiffDial("Humidity", cHum, tHum, humMatch, "%", isDark),
              Container(width: 1, height: 60, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              
              Column(
                children: [
                  Text("Air/Gas", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text(
                    _currentGas,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("ppm", style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                ],
              )
            ],
          ),
          const SizedBox(height: 32), // FIX: Replaced Spacer()
          Row(
            children: [
              Icon(tempMatch && humMatch ? Icons.check_circle : Icons.warning_amber_rounded, 
                   color: tempMatch && humMatch ? Colors.greenAccent.shade400 : Colors.orangeAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tempMatch && humMatch 
                      ? "Simulation conditions optimal for $_selectedCrop.".tr
                      : "System actively adjusting to target biome parameters.".tr,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDiffDial(String label, double current, double target, bool isOptimal, String unit, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text(
          "$current$unit",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isOptimal ? Colors.greenAccent.shade400 : Colors.orangeAccent.shade400,
          ),
        ),
        const SizedBox(height: 4),
        Text("Target: $target$unit", style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildSystemOffPlaceholder(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: _glassCardDecoration(isDark),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_off_rounded, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text("CEA is Offline".tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text("Power on the system to simulate biomes.".tr, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      Colors.deepPurpleAccent.withOpacity(isDark ? 0.08 : 0.2),
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
                          ? Row( // FIX: Removed SizedBox height wrappers
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      _buildSystemPowerCard(isDark),
                                      const SizedBox(height: 16),
                                      _buildBiomeSelector(isDark),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 4,
                                  child: _buildEnvironmentOverview(isDark),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: _buildHardwareControlArea(isDark),
                                ),
                              ],
                            )
                          : Column( // FIX: Removed SizedBox height wrappers
                              children: [
                                _buildSystemPowerCard(isDark),
                                const SizedBox(height: 16),
                                _buildBiomeSelector(isDark),
                                const SizedBox(height: 16),
                                _buildEnvironmentOverview(isDark),
                                const SizedBox(height: 16),
                                _buildHardwareControlArea(isDark), 
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
                                "CEA SUBSYSTEMS".tr,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: _glassCardDecoration(isDark),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min, // FIX
                                              children: [
                                                Text("PELTIER COOLING".tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                                                const SizedBox(height: 8),
                                                Text(_peltierCoolerState ? "ACTIVE" : "IDLE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _peltierCoolerState ? Colors.blueAccent : Theme.of(context).textTheme.bodyLarge!.color)),
                                              ],
                                            ),
                                            Icon(Icons.ac_unit, size: 48, color: _peltierCoolerState ? Colors.blueAccent : Colors.grey.withOpacity(0.3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: _glassCardDecoration(isDark),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min, // FIX
                                              children: [
                                                Text("SILICA DEHUMIDIFIER".tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                                                const SizedBox(height: 8),
                                                Text(_dehumidifierState ? "EXTRACTING" : "IDLE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _dehumidifierState ? Colors.orangeAccent : Theme.of(context).textTheme.bodyLarge!.color)),
                                              ],
                                            ),
                                            Icon(Icons.air, size: 48, color: _dehumidifierState ? Colors.orangeAccent : Colors.grey.withOpacity(0.3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: _glassCardDecoration(isDark),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min, // FIX
                                              children: [
                                                Text("MIST MAKER".tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                                                const SizedBox(height: 8),
                                                Text(_mistMakerActive ? "SPRAYING" : "DRY", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _mistMakerActive ? Colors.cyanAccent.shade400 : Theme.of(context).textTheme.bodyLarge!.color)),
                                              ],
                                            ),
                                            Icon(Icons.water_drop, size: 48, color: _mistMakerActive ? Colors.cyanAccent.shade400 : Colors.grey.withOpacity(0.3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: _glassCardDecoration(isDark),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min, // FIX
                                              children: [
                                                Text("VENTILATION".tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                                                const SizedBox(height: 8),
                                                Text((_fan1Active || _fan2Active) ? "BLOWING" : "OFF", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: (_fan1Active || _fan2Active) ? Colors.tealAccent.shade400 : Theme.of(context).textTheme.bodyLarge!.color)),
                                                if (_fan1Active || _fan2Active)
                                                  Text(
                                                    "Fans running: ${[_fan1Active, _fan2Active].where((e) => e).length}/2", 
                                                    style: TextStyle(fontSize: 12, color: Colors.tealAccent.shade700)
                                                  )
                                              ],
                                            ),
                                            Icon(Icons.toys, size: 48, color: (_fan1Active || _fan2Active) ? Colors.tealAccent.shade400 : Colors.grey.withOpacity(0.3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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