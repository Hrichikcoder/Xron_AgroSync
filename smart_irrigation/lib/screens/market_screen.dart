import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart'; // REQUIRED FOR kIsWeb
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/translations.dart';
import '../widgets/agro_pulse_loader.dart';
import '../widgets/fade_in_slide.dart';
import 'osm_search_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<Map<String, dynamic>> allCrops = [];
  List<Map<String, dynamic>> displayedCrops = [];
  List<Map<String, dynamic>> userAddedCrops = [];
  Set<String> starredCrops = {'Wheat'};

  double farmerLat = 22.5726;
  double farmerLon = 88.3639;
  String currentLocation = "Locating...".tr;

  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  
  // NEW VARIABLES FOR LIVE SEARCH
  bool isSearchingLive = false;
  Map<String, dynamic>? liveSearchResult;
  String? liveSearchError;

  bool isHubLoading = false;
  String? selectedHubCrop;
  Map<String, dynamic>? optimalHub;

  Offset _mousePosition = Offset.zero;

  BoxDecoration _cardDecoration(bool isDark, {double radius = 24}) {
    return BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
      borderRadius: BorderRadius.circular(radius),
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

  @override
  void initState() {
    super.initState();
    _initializeLocationAndData();
  }

  Future<void> _initializeLocationAndData() async {
    await _fetchDeviceLocation();
    await _loadData();
  }

  Future<void> _openOSMSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OSMSearchScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        farmerLat = result['lat'];
        farmerLon = result['lng'];

        String rawAddress = result['address'];
        List<String> parts = rawAddress.split(",");
        currentLocation = parts.length > 2
            ? "${parts[0].trim()}, ${parts[1].trim()}"
            : rawAddress;
      });

      _fetchOptimalHubForSelectedCrop();
    }
  }

  // Uses the robust logic from the uploaded code (including Web Fallback)
  Future<void> _fetchDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => currentLocation = "GPS Disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => currentLocation = "Permission Denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => currentLocation = "Permission Denied Forever");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          farmerLat = position.latitude;
          farmerLon = position.longitude;
        });
      }

      if (kIsWeb) {
        // WEB FALLBACK: Use OpenStreetMap API
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
                currentLocation = "$city, $state".replaceAll(RegExp(r',$'), '').trim();
              });
            }
            return;
          }
        } catch (apiError) {
          debugPrint("OSM Web Geocoding error: $apiError");
        }
        
        // If OSM fails, show raw coordinates
        if (mounted) {
          setState(() => currentLocation = "Lat: ${position.latitude.toStringAsFixed(2)}, Lon: ${position.longitude.toStringAsFixed(2)}");
        }

      } else {
        // MOBILE LOGIC: Standard Geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          List<String> addressParts = [];
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }

          if (addressParts.isEmpty) {
            if (place.street != null && place.street!.isNotEmpty) {
              addressParts.add(place.street!);
            } else if (place.administrativeArea != null) {
              addressParts.add(place.administrativeArea!);
            }
          }

          if (mounted) {
            setState(() {
              currentLocation = addressParts.isNotEmpty
                  ? addressParts.join(", ")
                  : "Location Found";
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => currentLocation = "Location Unavailable");
    }
  }

  Future<void> _fetchOptimalHubForSelectedCrop() async {
    if (selectedHubCrop == null) return;

    setState(() => isHubLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/predict_markets'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "crop": selectedHubCrop!.toUpperCase(),
          "lat": farmerLat,
          "lon": farmerLon,
          "transport_rate": 2.5,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['recommendations'] != null &&
            data['recommendations'].isNotEmpty) {
          
          var hubData = data['recommendations'][0];
          hubData['target_crop'] = data['target_crop'];

          List<dynamic> top3 = (data['recommendations'] as List).take(3).toList();
          double avgPrice = top3.map((m) => m['Expected Price (Rs/Q)'] as num)
                                .reduce((a, b) => a + b) / top3.length;
          
          hubData['AvgPricePer10Kg'] = avgPrice / 10;

          setState(() {
            optimalHub = hubData;
          });
        } else {
          setState(() => optimalHub = null);
        }
      }
    } catch (_) {
      setState(() => optimalHub = null);
    } finally {
      setState(() => isHubLoading = false);
    }
  }

  Future<void> _performLiveSearch(String cropName) async {
    setState(() {
      isSearchingLive = true;
      liveSearchError = null;
      liveSearchResult = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/predict_markets'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "crop": cropName.toUpperCase(),
          "lat": farmerLat,
          "lon": farmerLon,
          "transport_rate": 2.5,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['recommendations'] != null && data['recommendations'].isNotEmpty) {
          
          List<dynamic> top3 = (data['recommendations'] as List).take(3).toList();
          double avgPrice = top3.map((m) => m['Expected Price (Rs/Q)'] as num)
                                .reduce((a, b) => a + b) / top3.length;
          
          String displayCrop = cropName.substring(0, 1).toUpperCase() + cropName.substring(1).toLowerCase();
          
          setState(() {
            liveSearchResult = {
              "crop": displayCrop,
              "price": avgPrice.round(),
              "trend": "Live Search",
              "color": Colors.blueAccent,
              "detail": "Live search result. Not saved to tracking list.",
              "markets": data['recommendations'] // Pre-populate to save an API call
            };
          });
        } else {
          setState(() => liveSearchError = "No market data found for '$cropName'.");
        }
      } else {
         setState(() => liveSearchError = "API Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => liveSearchError = "Network error. Backend unreachable.");
    } finally {
      setState(() => isSearchingLive = false);
    }
  }

  Future<void> _trackLiveSearchResult() async {
    if (liveSearchResult == null) return;
    setState(() => isLoading = true); 
    
    String cropName = liveSearchResult!['crop'];
    String currentUserId = '1';
    
    // Save to PostgreSQL DB
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:8000/api/user/crops/add'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": currentUserId,
          "crop_name": cropName,
        }),
      );
    } catch (e) {
      debugPrint("Failed to save to DB: $e");
    }
    
    // Update local UI
    setState(() {
      liveSearchResult!['trend'] = "+0.0%"; // Reset to standard trend text
      liveSearchResult!['detail'] = "Custom user tracked crop.";
      
      userAddedCrops.add(liveSearchResult!);
      allCrops.insert(0, liveSearchResult!);
      selectedHubCrop = cropName;
      
      liveSearchResult = null;
      searchController.clear();
      _filterCrops("");
      isLoading = false;
    });
    
    _fetchOptimalHubForSelectedCrop();
  }

  Future<void> _addNewCrop(String cropName) async {
    setState(() => isLoading = true);
    String currentUserId = '1';
    int newPrice = 2000;

    try {
      await http.post(
        Uri.parse('http://127.0.0.1:8000/api/user/crops/add'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": currentUserId,
          "crop_name": cropName,
        }),
      );
    } catch (e) {
      debugPrint("Failed to save to DB: $e");
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/predict_markets'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "crop": cropName.toUpperCase(),
          "lat": farmerLat,
          "lon": farmerLon,
          "transport_rate": 2.5,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['recommendations'] != null &&
            data['recommendations'].isNotEmpty) {
          
          List<dynamic> top3 = (data['recommendations'] as List).take(3).toList();
          double avgPrice = top3.map((m) => m['Expected Price (Rs/Q)'] as num)
                                .reduce((a, b) => a + b) / top3.length;
          newPrice = avgPrice.round();
        }
      }
    } catch (_) {}

    String displayCrop =
        cropName.substring(0, 1).toUpperCase() +
        cropName.substring(1).toLowerCase();

    final newCropData = {
      "crop": displayCrop,
      "price": newPrice,
      "trend": "+0.0%",
      "color": Colors.blueAccent,
      "detail": "Custom crop added by user. Real-time API tracked.",
    };

    setState(() {
      userAddedCrops.add(newCropData);
      allCrops.insert(0, newCropData);
      selectedHubCrop = displayCrop;
      _filterCrops(searchController.text);
      isLoading = false;
    });

    _fetchOptimalHubForSelectedCrop();
  }

  void _deleteCrop(Map<String, dynamic> item) async{
    String currentUserId = '1';
    String cropToRemove = item['crop'];

    try {
      await http.delete(
        Uri.parse('http://127.0.0.1:8000/api/user/$currentUserId/crops/$cropToRemove'),
      );
    } catch (e) {
      debugPrint("Failed to delete from DB");
    }

    setState(() {
      allCrops.remove(item);
      userAddedCrops.remove(item);
      starredCrops.remove(item['crop']);

      if (selectedHubCrop == item['crop']) {
        selectedHubCrop = allCrops.isNotEmpty ? allCrops.first['crop'] : null;
        if (selectedHubCrop != null) {
          _fetchOptimalHubForSelectedCrop();
        } else {
          optimalHub = null;
        }
      }
      _filterCrops(searchController.text);
    });
  }

  void _showAddCropDialog() {
    final TextEditingController cropInputController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : const Color(0xFFF1F5F9).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6)),
            ),
            title: Text(
              "Add Custom Crop".tr,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: cropInputController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "e.g., Barley, Brinjal...".tr,
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.blueAccent.shade400),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel".tr,
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (cropInputController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    _addNewCrop(cropInputController.text.trim());
                  }
                },
                child: Text(
                  "Add".tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    String currentUserId = '1';
     try {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:8000/api/user/$currentUserId/markets/summary')
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> summary = data['summary'] ?? [];
          
          List<Map<String, dynamic>> apiData = summary.map((item) {
            return {
              "crop": item["crop"],
              "price": (item["price"] * 100).round(), 
              "trend": item["trend"],
              "color": Colors.blueAccent,
              "detail": item["detail"],
            };
          }).toList();

          setState(() {
            allCrops = apiData;
            selectedHubCrop ??= (allCrops.isNotEmpty ? allCrops.first['crop'] : null);
            _filterCrops(searchController.text);
            isLoading = false;
          });

        if (selectedHubCrop != null) {
          _fetchOptimalHubForSelectedCrop();
        }
        return;
      }
    } catch (_) {}
    
    setState(() => isLoading = false);
  }

  void _filterCrops(String query) {
    if (query.isEmpty) {
      displayedCrops = List.from(allCrops);
    } else {
      displayedCrops = allCrops.where((crop) {
        return crop['crop'].toString().toLowerCase().contains(
          query.toLowerCase(),
        );
      }).toList();
    }

    displayedCrops.sort((a, b) {
      bool aStarred = starredCrops.contains(a['crop']);
      bool bStarred = starredCrops.contains(b['crop']);
      if (aStarred && !bStarred) return -1;
      if (!aStarred && bStarred) return 1;
      return 0;
    });
  }

  void _launchGoogleMaps(double destLat, double destLng) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch Maps');
    }
  }

  void _showMarketBreakdown(BuildContext context, dynamic market) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasLocation = market['market_lat'] != null && market['market_lon'] != null;
    
    // Logic for Loss vs Profit
    double netProfit = market['Net Profit (Rs)'] / 10;
    bool isLoss = netProfit < 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : const Color(0xFFF1F5F9).withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${market['Market']}${' Hub'.tr}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                Text(
                  "${market['State']} • ${market['Distance (km)']} km away • ⏱ ${market['Travel Time'] ?? 'Unknown'}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBreakdownRow(
                  "Expected Price (per 10 kg)".tr,
                  "₹${(market['Expected Price (Rs/Q)'] / 10).toStringAsFixed(2)}",
                  isDark,
                  isPositive: true,
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  "Est. Transport (per 10 kg)".tr,
                  "- ₹${(market['Transport Cost (Rs)'] / 10).toStringAsFixed(2)}",
                  isDark,
                  isPositive: false,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                _buildBreakdownRow(
                  isLoss ? "Net Loss (per 10 kg)".tr : "Net Profit (per 10 kg)".tr,
                  "${isLoss ? '-' : ''}₹${netProfit.abs().toStringAsFixed(2)}",
                  isDark,
                  isTotal: true,
                  isLoss: isLoss,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withOpacity(0.1) : const Color(0xFF064E3B).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFF064E3B).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.blueAccent.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "AI Confidence Score".tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "${market['Confidence Score']}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.blueAccent.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_car),
                      label: Text(
                        "Navigate in Maps".tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _launchGoogleMaps(market['market_lat'], market['market_lon']);
                      },
                    ),
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close".tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value,
    bool isDark, {
    bool isPositive = true,
    bool isTotal = false,
    bool isLoss = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 14 : 13,
            color: isTotal
                ? (isLoss ? Colors.redAccent.shade400 : (isDark ? Colors.white : Colors.black87))
                : Colors.grey.shade500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
            fontSize: isTotal ? 16 : 14,
            color: isTotal
                ? (isLoss ? Colors.redAccent.shade400 : const Color(0xFF064E3B))
                : (isPositive
                      ? (isDark ? Colors.grey.shade300 : Colors.black87)
                      : Colors.red.shade400),
          ),
        ),
      ],
    );
  }

  void _showCropDetails(Map<String, dynamic> crop) {
    bool isFetching = false;
    String fetchError = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            List<dynamic> recommendedMarkets = crop['markets'] ?? [];

            void fetchMarkets() async {
              if (crop['markets'] != null) return;

              setModalState(() {
                isFetching = true;
                fetchError = "";
              });
              try {
                final response = await http.post(
                  Uri.parse('http://127.0.0.1:8000/api/predict_markets'),
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({
                    "crop": crop['crop'].toUpperCase(),
                    "lat": farmerLat,
                    "lon": farmerLon,
                    "transport_rate": 2.5,
                  }),
                );
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  setModalState(() {
                    recommendedMarkets = data['recommendations'] ?? [];
                    crop['markets'] = recommendedMarkets;
                  });
                } else {
                  setModalState(() {
                    fetchError = "API Error: ${response.statusCode}";
                    crop['markets'] = [];
                  });
                }
              } catch (e) {
                setModalState(() {
                  fetchError = "Could not connect to ML Backend.";
                  crop['markets'] = [];
                });
              } finally {
                setModalState(() => isFetching = false);
              }
            }

            if (crop['markets'] == null && !isFetching && fetchError.isEmpty) {
              Future.microtask(() => fetchMarkets());
            }

            double avgPrice = 0;
            if (recommendedMarkets.isNotEmpty) {
              avgPrice = recommendedMarkets
                  .map((m) => m['Expected Price (Rs/Q)'] as num)
                  .reduce((a, b) => a + b) / recommendedMarkets.length;
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.9) : const Color(0xFFF1F5F9).withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          crop['crop'],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₹${(avgPrice / 10).toStringAsFixed(2)} / 10 kg",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF064E3B) ,
                              ),
                            ),
                            Text(
                              "Top 3 Local Avg".tr,
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueAccent.withOpacity(0.15)
                            : Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        "${'Trend: '.tr}${crop['trend']}",
                        style: TextStyle(
                          color: isDark
                              ? Colors.blueAccent.shade100
                              : Colors.blueAccent.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "AI Predicted Top Markets".tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isFetching)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: AgroPulseLoader()),
                      )
                    else if (fetchError.isNotEmpty)
                      Text(fetchError, style: const TextStyle(color: Colors.red))
                    else if (recommendedMarkets.isEmpty)
                      Text(
                        "No optimal markets found for this crop currently.".tr,
                        style: TextStyle(color: Colors.grey.shade500),
                      )
                    else
                      ...recommendedMarkets
                          .map(
                            (m) {
                              // Loss vs Profit Check for each recommended market
                              double marketProfit = m['Net Profit (Rs)'] / 10;
                              bool isMarketLoss = marketProfit < 0;

                              return GestureDetector(
                                onTap: () => _showMarketBreakdown(context, m),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "${m['Market']}, ${m['State']}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "₹${(m['Expected Price (Rs/Q)'] / 10).toStringAsFixed(2)} / 10 kg",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 14,
                                                color: Colors.blueAccent.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Tap for cost breakdown".tr,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: const Color(0xFF064E3B) ,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "${isMarketLoss ? 'Net Loss:'.tr : 'Net Profit:'.tr} ${isMarketLoss ? '-' : ''}₹${marketProfit.abs().toStringAsFixed(2)} / 10 kg",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isMarketLoss ? Colors.redAccent.shade400 : const Color(0xFF064E3B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          )
                          .toList(),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E3B) ,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Close".tr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInSlide(
                            index: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Market",
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Text(
                                          "Analytics",
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueAccent.shade400,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Icon(
                                            Icons.my_location,
                                            size: 14,
                                            color: Colors.blueAccent.shade400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Current Location".tr,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: _openOSMSearch,
                                            child: Icon(
                                              Icons.edit_location_alt,
                                              size: 18,
                                              color: Colors.blueAccent.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentLocation,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blueAccent.shade400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        "${farmerLat.toStringAsFixed(4)}, ${farmerLon.toStringAsFixed(4)}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeInSlide(
                            index: 1,
                            child: _buildMarketHubCard(isDark),
                          ),
                          const SizedBox(height: 32),
                          FadeInSlide(
                            index: 2,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Live Exchange".tr,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "* Global Average per 10 Kilograms (10 kg)".tr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.add_circle_outline,
                                            color: const Color(0xFF064E3B),
                                            size: 28,
                                          ),
                                          onPressed: _showAddCropDialog,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.refresh,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            size: 26,
                                          ),
                                          onPressed: _loadData,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: searchController,
                                  textInputAction: TextInputAction.search,
                                  onChanged: (val) {
                                    setState(() {
                                      _filterCrops(val);
                                      liveSearchResult = null; 
                                      liveSearchError = null;
                                    });
                                  },
                                  onSubmitted: (val) {
                                    if (displayedCrops.isEmpty && val.trim().isNotEmpty) {
                                      _performLiveSearch(val.trim());
                                    }
                                  },
                                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge!.color),
                                  decoration: InputDecoration(
                                    hintText: "Search any crop...".tr,
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      size: 22,
                                    ),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.blueAccent.shade400),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (isLoading)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: AgroPulseLoader(
                                  message: "Fetching Live Markets...".tr,
                                ),
                              ),
                            )
                          else if (displayedCrops.isEmpty)
                            if (isSearchingLive)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: AgroPulseLoader(message: "Searching Live Markets for '${searchController.text}'...".tr),
                                ),
                              )
                            else if (liveSearchResult != null)
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "Live Search Result:".tr,
                                        style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  _buildMarketPriceRow(liveSearchResult!, isDark, isLiveSearch: true),
                                  const SizedBox(height: 16),
                                  Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blueAccent.shade400,
                                            side: BorderSide(color: Colors.blueAccent.shade400, width: 1.5),
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          icon: const Icon(Icons.analytics_outlined, size: 20),
                                          label: Text(
                                            "${'Live Search '.tr}'${searchController.text}'",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          onPressed: () {
                                            String query = searchController.text.trim();
                                            if (query.isNotEmpty) {
                                              String displayCrop = query.substring(0, 1).toUpperCase() + query.substring(1).toLowerCase();
                                              _showCropDetails({
                                                "crop": displayCrop,
                                                "trend": "Live Search",
                                              });
                                            }
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF064E3B),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          label: Text(
                                            "${'Track '.tr}'${searchController.text}'",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          onPressed: _trackLiveSearchResult,
                                        ),
                                      ],
                                    ),
                                ],
                              )
                            else
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(
                                        "${'No local crops match '.tr}'${searchController.text}'",
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Press Enter on your keyboard to fetch live data.".tr,
                                        style: TextStyle(color: Colors.blueAccent.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                                      ),
                                      if (liveSearchError != null) ...[
                                        const SizedBox(height: 16),
                                        Text(liveSearchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      ]
                                    ],
                                  ),
                                ),
                              )
                          else
                            Column(
                              children: displayedCrops.asMap().entries.map((entry) {
                                int index = entry.key;
                                var item = entry.value;
                                return FadeInSlide(
                                  index: index + 3,
                                  child: _buildMarketPriceRow(item, isDark),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketHubCard(bool isDark) {
    List<String> cropNames = allCrops
        .map((e) => e['crop'].toString())
        .toSet()
        .toList();

    return Container(
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select crop to view optimal market:".tr,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      value: cropNames.contains(selectedHubCrop)
                          ? selectedHubCrop
                          : (cropNames.isNotEmpty ? cropNames.first : null),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF064E3B),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      items: cropNames.map((String crop) {
                        return DropdownMenuItem<String>(
                          value: crop,
                          child: Text(crop),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != selectedHubCrop) {
                          setState(() => selectedHubCrop = newValue);
                          _fetchOptimalHubForSelectedCrop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            height: 1,
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: isHubLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: AgroPulseLoader(),
                    ),
                  )
                : optimalHub != null
                ? Builder(
                    builder: (context) {
                      double hubNetProfit = optimalHub!['Net Profit (Rs)'] / 10;
                      bool isHubLoss = hubNetProfit < 0;

                      return InkWell(
                        onTap: () => _showMarketBreakdown(context, optimalHub),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                color: const Color(0xFF064E3B),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    optimalHub!['Market'] ?? "Unknown Market".tr,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 14,
                                        color: const Color(0xFF064E3B) ,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Top 3 Local Avg: ₹${optimalHub!['AvgPricePer10Kg'].toStringAsFixed(2)} / 10 kg",
                                          style: TextStyle(
                                            color: const Color(0xFF064E3B) ,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${isHubLoss ? '-' : ''}₹${hubNetProfit.abs().toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isHubLoss ? Colors.redAccent.shade400 : const Color(0xFF064E3B) ,
                                  ),
                                ),
                                Text(
                                  (isHubLoss ? "Net Loss / 10 kg" : "Net Profit / 10 kg").tr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isHubLoss ? Colors.redAccent.shade400 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  )
                : Center(
                    child: Text(
                      "${'No optimal market data available for '.tr}$selectedHubCrop.",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketPriceRow(Map<String, dynamic> item, bool isDark, {bool isLiveSearch = false}) {
    bool isPositive = item['trend'].startsWith('+');
    bool isNeutral = item['trend'].startsWith('0');
    bool isStarred = starredCrops.contains(item['crop']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(isDark, radius: 16).copyWith(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showCropDetails(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (!isLiveSearch)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isStarred) {
                            starredCrops.remove(item['crop']);
                          } else {
                            starredCrops.add(item['crop']);
                          }
                          _filterCrops(searchController.text);
                        });
                      },
                      child: Icon(
                        isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isStarred ? Colors.amber.shade400 : Colors.grey.shade400,
                        size: 24,
                      ),
                    )
                  else
                    Icon(Icons.cloud_outlined, color: Colors.blueAccent.shade400, size: 24),
                  const SizedBox(width: 16),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                    ),
                    child: Center(
                      child: Text(
                        item['crop'][0],
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item['crop'],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${(item['price'] / 10).toStringAsFixed(2)} / 10 kg",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: const Color(0xFF064E3B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isNeutral
                              ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
                              : (isDark ? Colors.blueAccent.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward_rounded
                                  : (isNeutral
                                      ? Icons.horizontal_rule_rounded
                                      : Icons.arrow_downward_rounded),
                              color: isNeutral
                                  ? Colors.grey.shade500
                                  : Colors.blueAccent.shade400,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item['trend'],
                              style: TextStyle(
                                color: isNeutral
                                    ? Colors.grey.shade500
                                    : Colors.blueAccent.shade400,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  if (!isLiveSearch)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent.shade400,
                        size: 22,
                      ),
                      onPressed: () => _deleteCrop(item),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}