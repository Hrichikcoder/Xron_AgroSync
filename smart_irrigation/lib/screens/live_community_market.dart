import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/agro_pulse_loader.dart';

class LiveCommunityMarketScreen extends StatefulWidget {
  const LiveCommunityMarketScreen({super.key});

  @override
  State<LiveCommunityMarketScreen> createState() => _LiveCommunityMarketScreenState();
}

class _LiveCommunityMarketScreenState extends State<LiveCommunityMarketScreen> {
  bool isLoading = true;
  List<dynamic> communityData = [];
  List<dynamic> filteredData = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCommunityData();
  }

  Future<void> _fetchCommunityData() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/markets/community'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          communityData = data['community_markets'] ?? [];
          filteredData = List.from(communityData);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _filterData(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredData = List.from(communityData);
      });
    } else {
      setState(() {
        filteredData = communityData.where((item) {
          final cropMatch = item['crop'].toString().toLowerCase().contains(query.toLowerCase());
          final marketMatch = item['market'].toString().toLowerCase().contains(query.toLowerCase());
          return cropMatch || marketMatch;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          "Real-Time Crowdsourced Data",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: TextField(
              controller: searchController,
              onChanged: _filterData,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Search by crop or market...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: AgroPulseLoader(message: "Loading Verified Market Data..."))
                : filteredData.isEmpty
                    ? Center(
                        child: Text("No community data found.", style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : Builder(
                        builder: (context) {
                          // 1. GROUP THE DATA BY CROP
                          Map<String, List<dynamic>> groupedByCrop = {};
                          for (var item in filteredData) {
                            String crop = item['crop'];
                            groupedByCrop.putIfAbsent(crop, () => []).add(item);
                          }
                          List<String> cropNames = groupedByCrop.keys.toList();

                          // 2. RENDER THE BIG BOXES
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: cropNames.length,
                            itemBuilder: (context, index) {
                              String cropName = cropNames[index];
                              List<dynamic> markets = groupedByCrop[cropName]!;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // BIG ROW HEADER (CROP NAME)
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              cropName[0],
                                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          cropName,
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // HORIZONTAL SCROLLING MARKET CARDS (SIDE-BY-SIDE)
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: markets.map((item) {
                                          bool isPositive = item['trend'].startsWith('+') && !item['trend'].contains('0.0');
                                          bool isNegative = item['trend'].startsWith('-');
                                          bool isNeutral = !isPositive && !isNegative;

                                          return Container(
                                            width: 240, // Fixed width for the market cards
                                            margin: const EdgeInsets.only(right: 16),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Market Name
                                                Text(
                                                  item['market'],
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 12),
                                                
                                                // Prices
                                                Text(
                                                  "₹${item['price'].toStringAsFixed(2)}",
                                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amber.shade600),
                                                ),
                                                Text(
                                                  "Avg / 10kg",
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  "Min: ₹${item['min_price']} | Max: ₹${item['max_price']}",
                                                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                
                                                const SizedBox(height: 16),
                                                
                                                // Footer (Reports + Trend)
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.verified_user_rounded, size: 12, color: Colors.green.shade500),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          "${item['reports']} Verified",
                                                          style: TextStyle(color: Colors.green.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isNeutral
                                                            ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
                                                            : (isPositive 
                                                                ? (isDark ? Colors.blueAccent.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.1))
                                                                : (isDark ? Colors.redAccent.withOpacity(0.15) : Colors.redAccent.withOpacity(0.1))),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            isPositive
                                                                ? Icons.arrow_upward_rounded
                                                                : (isNegative
                                                                    ? Icons.arrow_downward_rounded
                                                                    : Icons.horizontal_rule_rounded),
                                                            color: isNeutral
                                                                ? Colors.grey.shade500
                                                                : (isPositive ? Colors.blueAccent.shade400 : Colors.redAccent.shade400),
                                                            size: 10,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            item['trend'],
                                                            style: TextStyle(
                                                              color: isNeutral
                                                                  ? Colors.grey.shade500
                                                                  : (isPositive ? Colors.blueAccent.shade400 : Colors.redAccent.shade400),
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      ),
          ),
        ],
      ),
    );
  }
}