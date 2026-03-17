import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart'; // REQUIRED FOR GOOGLE MAPS ROUTING
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

  bool isHubLoading = false;
  String? selectedHubCrop;
  Map<String, dynamic>? optimalHub;

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

  Future<void> _fetchDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => currentLocation = "GPS Disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => currentLocation = "Permission Denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => currentLocation = "Permission Denied Forever");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      farmerLat = position.latitude;
      farmerLon = position.longitude;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        farmerLat,
        farmerLon,
      );

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

        setState(() {
          currentLocation = addressParts.isNotEmpty
              ? addressParts.join(", ")
              : "Location Found";
        });
      }
    } catch (e) {
      setState(() => currentLocation = "Location Acquired");
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
          
          hubData['AvgPricePerKg'] = avgPrice / 100;

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

  Future<void> _addNewCrop(String cropName) async {
    setState(() => isLoading = true);

    int newPrice = 2000;

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
      "color": Colors.blue,
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

  void _deleteCrop(Map<String, dynamic> item) {
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Add Custom Crop".tr,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          content: TextField(
            controller: cropInputController,
            decoration: InputDecoration(
              hintText: "e.g., Barley, Brinjal...".tr,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel".tr,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/markets/summary'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> summary = data['summary'] ?? [];
        
        List<Map<String, dynamic>> apiData = summary.map((item) {
          return {
            "crop": item["crop"],
            "price": (item["price"] * 100).round(), 
            "trend": item["trend"],
            "color": Colors.blue,
            "detail": item["detail"],
          };
        }).toList();
        
        apiData.insertAll(0, userAddedCrops);

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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                "Expected Price (per kg)".tr,
                "₹${(market['Expected Price (Rs/Q)'] / 100).toStringAsFixed(2)}",
                isDark,
                isPositive: true,
              ),
              const SizedBox(height: 12),
              _buildBreakdownRow(
                "Est. Transport (per kg)".tr,
                "- ₹${(market['Transport Cost (Rs)'] / 100).toStringAsFixed(2)}",
                isDark,
                isPositive: false,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(),
              ),
              _buildBreakdownRow(
                "Net Profit (per kg)".tr,
                "₹${(market['Net Profit (Rs)'] / 100).toStringAsFixed(2)}",
                isDark,
                isTotal: true,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI Confidence Score".tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                    Text(
                      "${market['Confidence Score']}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue.shade500,
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
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
                ? (isDark ? Colors.white : Colors.black87)
                : Colors.grey.shade500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
            fontSize: isTotal ? 16 : 14,
            color: isTotal
                ? Colors.green.shade600
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

            // Calculate Average Price from recommended markets
            double avgPrice = 0;
            if (recommendedMarkets.isNotEmpty) {
              avgPrice = recommendedMarkets
                  .map((m) => m['Expected Price (Rs/Q)'] as num)
                  .reduce((a, b) => a + b) / recommendedMarkets.length;
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        crop['crop'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${(avgPrice / 100).toStringAsFixed(2)} / kg",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            "Top 3 Local Avg".tr, // Updated Label
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? crop['color'].withOpacity(0.2)
                          : crop['color'].shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${'Trend: '.tr}${crop['trend']}",
                      style: TextStyle(
                        color: isDark
                            ? crop['color'].shade300
                            : crop['color'].shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "AI Predicted Top Markets".tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 12),

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
                          (m) => GestureDetector(
                            onTap: () => _showMarketBreakdown(context, m),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
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
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "₹${(m['Expected Price (Rs/Q)'] / 100).toStringAsFixed(2)} / kg",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Colors.blue.shade400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Tap for cost breakdown".tr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade400,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "${'Net Profit:'.tr} ₹${(m['Net Profit (Rs)'] / 100).toStringAsFixed(2)} / kg",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Close".tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Market Analytics".tr,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
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
                                    size: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Current Location".tr,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _openOSMSearch,
                                    child: Icon(
                                      Icons.edit_location_alt,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentLocation,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
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
                  const SizedBox(height: 20),

                  FadeInSlide(
                    index: 1,
                    child: _buildMarketHubCard(isDark),
                  ),

                  const SizedBox(height: 24),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "* Global Average per Kilogram (kg)".tr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 24,
                                  ),
                                  onPressed: _showAddCropDialog,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.grey.shade500,
                                    size: 22,
                                  ),
                                  onPressed: _loadData,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: searchController,
                          onChanged: (val) {
                            setState(() {
                              _filterCrops(val);
                            });
                          },
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Search any crop...".tr,
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "${'No crops found matching '.tr}'${searchController.text}'",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: Text(
                                "${'Track '.tr}'${searchController.text}'",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                _addNewCrop(searchController.text.trim());
                              },
                            ),
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketHubCard(bool isDark) {
    List<String> cropNames = allCrops
        .map((e) => e['crop'].toString())
        .toSet()
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.green.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.green.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select crop to view optimal market:".tr,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isDark
                        ? Colors.black12
                        : Colors.green.shade50.withOpacity(0.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: cropNames.contains(selectedHubCrop)
                          ? selectedHubCrop
                          : (cropNames.isNotEmpty ? cropNames.first : null),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      items: cropNames.map((String crop) {
                        return DropdownMenuItem<String>(
                          value: crop,
                          child: Text(
                            crop,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            height: 1,
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isHubLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: AgroPulseLoader(),
                    ),
                  )
                : optimalHub != null
                ? InkWell(
                    onTap: () => _showMarketBreakdown(context, optimalHub),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.storefront,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.blue.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "Top 3 Local Avg: ₹${optimalHub!['AvgPricePerKg'].toStringAsFixed(2)} / kg",
                                      style: TextStyle(
                                        color: Colors.blue.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                              "₹${(optimalHub!['Net Profit (Rs)'] / 100).toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
                              ),
                            ),
                            Text(
                              "Net Profit / kg".tr,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      "${'No optimal market data available for '.tr}$selectedHubCrop.",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketPriceRow(Map<String, dynamic> item, bool isDark) {
    bool isPositive = item['trend'].startsWith('+');
    bool isNeutral = item['trend'].startsWith('0');
    bool isStarred = starredCrops.contains(item['crop']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showCropDetails(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
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
                      isStarred ? Icons.star : Icons.star_border,
                      color: isStarred ? Colors.amber : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        item['crop'][0],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['crop'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${(item['price'] / 100).toStringAsFixed(2)} / kg",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isNeutral
                              ? (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100)
                              : (isDark
                                  ? item['color'].withOpacity(0.15)
                                  : item['color'].shade50),
                          borderRadius: BorderRadius.circular(6),
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
                                  : (isDark
                                      ? item['color'].shade400
                                      : item['color'].shade700),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item['trend'],
                              style: TextStyle(
                                color: isNeutral
                                    ? Colors.grey.shade500
                                    : (isDark
                                        ? item['color'].shade400
                                        : item['color'].shade700),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
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