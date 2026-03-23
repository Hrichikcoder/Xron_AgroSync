import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/translations.dart';
import '../core/app_config.dart'; // Added AppConfig import

void showDiagnosticsDialog(BuildContext context, bool isDark) {
  // Use the global baseUrl from AppConfig
  final String apiUrl = AppConfig.baseUrl; 

  bool _isTesting = false;
  String _testMessage = "Select a test to begin.";
  List<int> _testResults = [0, 0, 0, 0, 0, 0]; // 0: Pending, 1: Pass, 2: Fail

  final List<Map<String, dynamic>> _tests = [
    {
      "name": "DHT11 (Temp & Humidity)",
      "icon": Icons.thermostat_rounded,
      "instruction": "Tap 'Run Test'. System will verify if ambient temperature and humidity readings are valid (not 0).",
    },
    {
      "name": "LDR (Light Sensor)",
      "icon": Icons.light_mode_rounded,
      "instruction": "Tap 'Run Test'. Wait for the baseline, then cover the LDR with your hand when prompted.",
    },
    {
      "name": "Rain Sensor",
      "icon": Icons.water_drop_outlined,
      "instruction": "Tap 'Run Test'. Wait for baseline, then place a drop of water on the rain plate when prompted.",
    },
    {
      "name": "Soil Moisture",
      "icon": Icons.grass_rounded,
      "instruction": "Tap 'Run Test'. Wait for baseline, then sprinkle water near the soil sensor when prompted.",
    },
    {
      "name": "Flow Sensor & Pump 1",
      "icon": Icons.water_rounded,
      "instruction": "Ensure water is connected. Tap 'Run Test' to briefly run Pump 1 and check for flow.",
    },
    {
      "name": "Pump 2 (Manual Check)",
      "icon": Icons.power_settings_new_rounded,
      "instruction": "Tap 'Run Test' to turn on Pump 2 for 3 seconds. Verify physically.",
    }
  ];

  Future<void> _stopAllPumps() async {
    try {
      await http.post(
        Uri.parse('$apiUrl/control/pump'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"mode": "auto", "pump1": false, "pump2": false, "shade": false, "sprinkler": false}),
      );
    } catch (e) {
      debugPrint("Error stopping pumps: $e");
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      // --- NEW: Trigger hardware to print to Serial Monitor ---
      http.post(Uri.parse('$apiUrl/control/trigger_diagnostics')).catchError((e) {
        debugPrint("Failed to trigger ESP32 hardware diagnostics: $e");
      });
      // --------------------------------------------------------

      return StatefulBuilder(
        builder: (context, setStateDialog) {

          Future<void> _runTest(int index) async {
            setStateDialog(() {
              _isTesting = true;
              _testMessage = "Running test...";
              _testResults[index] = 0;
            });

            try {
              // TEST 0: DHT11
              if (index == 0) {
                setStateDialog(() => _testMessage = "Fetching DHT11 data...");
                final res = await http.get(Uri.parse('$apiUrl/sensors/live'));
                if (res.statusCode == 200) {
                  final data = json.decode(res.body);
                  double temp = data['temperature'] ?? 0.0;
                  double hum = data['humidity'] ?? 0.0;

                  if (temp > 0 && hum > 0) {
                    setStateDialog(() { _testResults[0] = 1; _testMessage = "Pass: Temp $temp°C, Hum $hum%"; });
                  } else {
                    setStateDialog(() { _testResults[0] = 2; _testMessage = "Fail: Invalid readings ($temp°C, $hum%)"; });
                  }
                }
              }

              // TEST 1, 2, 3: Interactive ADC Sensors (LDR, Rain, Soil)
              else if (index >= 1 && index <= 3) {
                String sensorKey = index == 1 ? 'ldr' : (index == 2 ? 'rain_level' : 'soil_moisture');
                String actionPrompt = index == 1 ? "COVER THE LDR NOW!" : (index == 2 ? "PUT WATER ON RAIN SENSOR NOW!" : "SPRINKLE WATER ON SOIL NOW!");
                
                setStateDialog(() => _testMessage = "Reading baseline value...");
                await Future.delayed(const Duration(seconds: 2));
                
                final res1 = await http.get(Uri.parse('$apiUrl/sensors/live'));
                int baseline = json.decode(res1.body)[sensorKey] ?? 4095;

                setStateDialog(() => _testMessage = "$actionPrompt (Waiting 12 seconds...)");
                await Future.delayed(const Duration(seconds: 12));

                setStateDialog(() => _testMessage = "Reading new value...");
                final res2 = await http.get(Uri.parse('$apiUrl/sensors/live'));
                int newValue = json.decode(res2.body)[sensorKey] ?? 4095;

                // If ADC value changes by more than 300, it proves the sensor is responding
                if ((baseline - newValue).abs() > 300) {
                  setStateDialog(() { _testResults[index] = 1; _testMessage = "Pass: Value shifted from $baseline to $newValue."; });
                } else {
                  setStateDialog(() { _testResults[index] = 2; _testMessage = "Fail: No significant change ($baseline -> $newValue)."; });
                }
              }

              // TEST 4: Flow & Pump 1
              else if (index == 4) {
                setStateDialog(() => _testMessage = "Starting Pump 1...");
                await http.post(
                  Uri.parse('$apiUrl/control/pump'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({"mode": "manual", "pump1": true, "pump2": false, "shade": false, "sprinkler": false}),
                );

                setStateDialog(() => _testMessage = "Waiting 5 seconds for flow data...");
                await Future.delayed(const Duration(seconds: 5));

                final res = await http.get(Uri.parse('$apiUrl/sensors/live_flow'));
                double flowRate = 0.0;
                if (res.statusCode == 200) {
                  flowRate = (json.decode(res.body)['flow_rate'] ?? 0.0).toDouble();
                }

                await _stopAllPumps();

                if (flowRate > 0) {
                  setStateDialog(() { _testResults[4] = 1; _testMessage = "Pass: Flow detected ($flowRate L/min)."; });
                } else {
                  setStateDialog(() { _testResults[4] = 2; _testMessage = "Fail: Pump ran but no flow detected."; });
                }
              }

              // TEST 5: Pump 2 Manual
              else if (index == 5) {
                setStateDialog(() => _testMessage = "Starting Pump 2 for 3 seconds...");
                await http.post(
                  Uri.parse('$apiUrl/control/pump'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({"mode": "manual", "pump1": false, "pump2": true, "shade": false, "sprinkler": false}),
                );

                await Future.delayed(const Duration(seconds: 3));
                await _stopAllPumps();

                setStateDialog(() {
                  _isTesting = false;
                  _testMessage = "Did Pump 2 turn on successfully?";
                });
                
                bool? userConfirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    title: Text("Manual Confirmation", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    content: Text("Did you hear or see Pump 2 turn on?", style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: Colors.redAccent))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes", style: TextStyle(color: Colors.green))),
                    ],
                  )
                );

                setStateDialog(() {
                  if (userConfirmed == true) {
                    _testResults[5] = 1;
                    _testMessage = "Pass: User confirmed Pump 2 operation.";
                  } else {
                    _testResults[5] = 2;
                    _testMessage = "Fail: User reported Pump 2 did not start.";
                  }
                });
                return; 
              }

            } catch (e) {
              setStateDialog(() {
                _testResults[index] = 2;
                _testMessage = "Error: $e";
              });
              await _stopAllPumps();
            }

            setStateDialog(() {
              _isTesting = false;
            });
          }

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : const Color(0xFFF1F5F9).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6), width: 1),
              ),
              title: Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Colors.blueAccent.shade400),
                  const SizedBox(width: 12),
                  Text(
                    "System Diagnostics".tr,
                    style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        _testMessage,
                        style: TextStyle(
                          color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _tests.length,
                        itemBuilder: (context, index) {
                          final test = _tests[index];
                          final status = _testResults[index];
                          return Card(
                            elevation: 0,
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300, width: 1)
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(test["icon"], color: Colors.blueAccent.shade400, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          test["name"],
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)
                                        )
                                      ),
                                      if (status == 1) const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
                                      else if (status == 2) const Icon(Icons.cancel_rounded, color: Colors.redAccent)
                                      else Icon(Icons.help_outline_rounded, color: Colors.grey.shade500),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    test["instruction"],
                                    style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _isTesting ? null : () => _runTest(index),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent.shade400,
                                        disabledBackgroundColor: Colors.grey.shade600,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        status == 0 ? "Run Test" : "Retest",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            )
                          );
                        }
                      )
                    )
                  ]
                )
              ),
              actions: [
                TextButton(
                  onPressed: _isTesting ? null : () {
                    _stopAllPumps();
                    Navigator.pop(context);
                  },
                  child: Text("Close".tr, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      );
    }
  );
}