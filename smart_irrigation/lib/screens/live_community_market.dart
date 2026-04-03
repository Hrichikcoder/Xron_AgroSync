import 'dart:convert';
import 'dart:math';
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

  // Navigation & Filter State
  String? selectedCrop;
  String? selectedMarket;
  String selectedTimeframe = "7 Days"; 

  final List<String> timeframes = ["7 Days", "1 Month", "6 Months", "1 Year"];

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
          // Do not auto-select crop/market here so the list view shows first
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade600),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          isDense: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==================================================
  // VIEW 1: MASTER LIST (CROWDSOURCED SCREENSHOT VIEW)
  // ==================================================
  Widget _buildMarketList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: communityData.length,
      itemBuilder: (context, index) {
        final cropGroup = communityData[index];
        final String cropName = cropGroup['crop'];
        final List<dynamic> markets = cropGroup['markets'];

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cropName.isNotEmpty ? cropName[0] : '', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(cropName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: markets.map((m) => _buildMarketCard(m, cropName, isDark)).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketCard(dynamic market, String cropName, bool isDark) {
    // Extract today's logic (last entry in history array)
    final history = market['history'] as List<dynamic>? ?? [];
    final today = history.isNotEmpty ? history.last : null;
    
    double avg = today != null ? (today['price'] as num).toDouble() : 0.0;
    double minPrice = today != null ? (today['min'] as num).toDouble() : 0.0;
    double maxPrice = today != null ? (today['max'] as num).toDouble() : 0.0;

    // Calculate Day-over-Day percentage change if we have at least 2 days of data
    double pctChange = 0.0;
    if (history.length >= 2) {
      double yesterdayAvg = (history[history.length - 2]['price'] as num).toDouble();
      if (yesterdayAvg > 0) {
        pctChange = ((avg - yesterdayAvg) / yesterdayAvg) * 100;
      }
    }
    bool isUp = pctChange > 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCrop = cropName;
          selectedMarket = market['market'];
        });
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(market['market'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text("₹${avg.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.amber)),
            Text("Avg / 10kg", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Min: ₹${minPrice.toStringAsFixed(2)} | Max: ₹${maxPrice.toStringAsFixed(2)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.green.shade400),
                    const SizedBox(width: 4),
                    Text("4 Verified", style: TextStyle(color: Colors.green.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (pctChange != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isUp ? Colors.blueAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Row(
                      children: [
                        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: isUp ? Colors.blueAccent : Colors.redAccent),
                        Text("${pctChange.abs().toStringAsFixed(1)}%", style: TextStyle(color: isUp ? Colors.blueAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  // ==================================================
  // VIEW 2: ANALYTICS DETAIL (GRAPH & STATS)
  // ==================================================
  Widget _buildAnalyticsDetail(bool isDark) {
    // 1. Fetch raw history for selected crop & market
    List<dynamic> marketsData = [];
    final cropData = communityData.firstWhere((e) => e['crop'] == selectedCrop, orElse: () => null);
    if (cropData != null) marketsData = cropData['markets'] ?? [];
    
    List<dynamic> rawHistory = [];
    final marketItem = marketsData.firstWhere((e) => e['market'] == selectedMarket, orElse: () => null);
    if (marketItem != null) rawHistory = marketItem['history'] ?? [];

    // 2. Data Aggregation Logic (Retained exactly from your original setup)
    DateTime now = DateTime.now();
    DateTime currentStart;
    DateTime prevStart;
    
    if (selectedTimeframe == '7 Days') {
      currentStart = now.subtract(const Duration(days: 6)); 
      prevStart = now.subtract(const Duration(days: 13));
    } else if (selectedTimeframe == '1 Month') {
      currentStart = now.subtract(const Duration(days: 29));
      prevStart = now.subtract(const Duration(days: 59));
    } else if (selectedTimeframe == '6 Months') {
      currentStart = now.subtract(const Duration(days: 179));
      prevStart = now.subtract(const Duration(days: 359));
    } else { 
      currentStart = now.subtract(const Duration(days: 364));
      prevStart = now.subtract(const Duration(days: 729));
    }

    List<dynamic> currentDataRaw = [];
    List<dynamic> prevDataRaw = [];

    for (var item in rawHistory) {
      DateTime dt = DateTime.parse(item['date'] + "T00:00:00Z");
      if (dt.isAfter(currentStart.subtract(const Duration(hours: 1))) && dt.isBefore(now.add(const Duration(days: 1)))) {
        currentDataRaw.add(item);
      } else if (dt.isAfter(prevStart.subtract(const Duration(hours: 1))) && dt.isBefore(currentStart)) {
        prevDataRaw.add(item);
      }
    }
    
    double curAvg = 0;
    if (currentDataRaw.isNotEmpty) {
      curAvg = currentDataRaw.map((e) => (e['price'] as num).toDouble()).reduce((a, b) => a + b) / currentDataRaw.length;
    }

    double prevAvg = 0, prevMax = 0, prevMin = double.infinity;
    if (prevDataRaw.isNotEmpty) {
      prevMax = prevDataRaw.map((e) => (e['max'] as num).toDouble()).reduce(max);
      prevMin = prevDataRaw.map((e) => (e['min'] as num).toDouble()).reduce(min);
      prevAvg = prevDataRaw.map((e) => (e['price'] as num).toDouble()).reduce((a, b) => a + b) / prevDataRaw.length;
    } else {
      prevMin = 0;
    }

    double pctChange = 0;
    if (prevAvg > 0) pctChange = ((curAvg - prevAvg) / prevAvg) * 100;
    bool isUp = pctChange > 0;

    List<dynamic> chartData = [];
    if (selectedTimeframe == '6 Months' || selectedTimeframe == '1 Year') {
      Map<String, List<dynamic>> monthlyGroups = {};
      for (var item in currentDataRaw) {
        String monthKey = item['date'].substring(0, 7); 
        monthlyGroups.putIfAbsent(monthKey, () => []).add(item);
      }
      monthlyGroups.forEach((month, items) {
        double avg = items.map((e) => (e['price'] as num).toDouble()).reduce((a,b) => a+b) / items.length;
        chartData.add({"date": month, "price": avg});
      });
      chartData.sort((a, b) => a['date'].compareTo(b['date']));
    } else {
      chartData = List.from(currentDataRaw); 
      chartData.sort((a, b) => a['date'].compareTo(b['date']));
    }

    return WillPopScope(
      onWillPop: () async {
        setState(() { selectedMarket = null; selectedCrop = null; });
        return false; // Prevent full screen exit, just return to list view
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Header Row with Back Button
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => setState(() { selectedMarket = null; selectedCrop = null; }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedMarket ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(selectedCrop ?? '', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              _buildDropdown(selectedTimeframe, timeframes, (v) => setState(() => selectedTimeframe = v!), isDark),
            ],
          ),
          const SizedBox(height: 24),

          // The Interactive Line Chart Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: chartData.isEmpty
              ? SizedBox(height: 220, child: Center(child: Text("Not enough history for this timeframe", style: TextStyle(color: Colors.grey.shade500))))
              : SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      history: chartData, 
                      isDark: isDark, 
                      startDate: currentStart, 
                      endDate: now, 
                      timeframe: selectedTimeframe
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 24),

          // Previous Period Analysis Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: Colors.amber.shade600),
                        const SizedBox(width: 8),
                        Text("Previous Period Analysis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color)),
                      ],
                    ),
                    if (prevDataRaw.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUp ? Colors.blueAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isUp ? Colors.blueAccent.shade400 : Colors.redAccent.shade400),
                            const SizedBox(width: 4),
                            Text("${pctChange.abs().toStringAsFixed(1)}%", style: TextStyle(color: isUp ? Colors.blueAccent.shade400 : Colors.redAccent.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Data from the preceding $selectedTimeframe", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                if (prevDataRaw.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("No data recorded for the previous period.", style: TextStyle(color: Colors.grey.shade500)),
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _buildStatBox("Average", "₹${prevAvg.round()}", Colors.blueAccent.shade400, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox("Max Peak", "₹${prevMax.round()}", Colors.green.shade500, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatBox("Min Drop", "₹${prevMin.round()}", Colors.redAccent.shade400, isDark)),
                    ],
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      // Only show the main App Bar when on the master list
      appBar: selectedMarket == null ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          "Real-Time Crowdsourced Data",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ) : null,
      body: isLoading
          ? const Center(child: AgroPulseLoader(message: "Fetching Markets..."))
          : communityData.isEmpty
              ? Center(child: Text("No community data found.", style: TextStyle(color: Colors.grey.shade500)))
              : selectedMarket == null 
                  ? _buildMarketList(isDark) 
                  : _buildAnalyticsDetail(isDark),
    );
  }
}

// ==================================================
// FIXED X-AXIS LINE CHART PAINTER (UNCHANGED)
// ==================================================
class LineChartPainter extends CustomPainter {
  final List<dynamic> history;
  final bool isDark;
  final DateTime startDate;
  final DateTime endDate;
  final String timeframe;

  LineChartPainter({
    required this.history, 
    required this.isDark, 
    required this.startDate, 
    required this.endDate, 
    required this.timeframe
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    // Y-AXIS Scaling
    double maxPrice = history.map((e) => (e['price'] as num).toDouble()).reduce(max);
    double minPrice = history.map((e) => (e['price'] as num).toDouble()).reduce(min);
    double range = maxPrice - minPrice;
    if (range == 0) range = 10; 
    
    maxPrice += range * 0.2;
    minPrice -= range * 0.2;
    if(minPrice < 0) minPrice = 0;
    range = maxPrice - minPrice;

    const double paddingLeft = 35.0;
    const double paddingBottom = 25.0;
    final double chartWidth = size.width - paddingLeft;
    final double chartHeight = size.height - paddingBottom;

    // 1. Draw Grid Lines & Y-Axis Prices
    final gridPaint = Paint()..color = isDark ? Colors.white10 : Colors.black12..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      double y = chartHeight - (i * (chartHeight / 4));
      double priceLabel = minPrice + (i * (range / 4));
      
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), gridPaint);
      
      final textSpan = TextSpan(text: priceLabel.round().toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // 2. X-AXIS LABELS (Fixed Timeline, Independent of Data)
    int totalDurationDays = endDate.difference(startDate).inDays;
    if (totalDurationDays <= 0) totalDurationDays = 1;

    int steps = 6; // Default intervals
    if (timeframe == "7 Days") steps = 6;      // 7 points
    if (timeframe == "1 Month") steps = 5;     // 6 points
    if (timeframe == "6 Months") steps = 5;    // 6 points
    if (timeframe == "1 Year") steps = 11;     // 12 points

    for(int i = 0; i <= steps; i++) {
        double x = paddingLeft + (i / steps) * chartWidth;
        int daysToAdd = (totalDurationDays * (i / steps)).round();
        DateTime labelDate = startDate.add(Duration(days: daysToAdd));
        
        String labelStr;
        if (timeframe == "7 Days" || timeframe == "1 Month") {
            labelStr = "${labelDate.day.toString().padLeft(2,'0')}/${labelDate.month.toString().padLeft(2,'0')}";
        } else {
            List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            labelStr = "${months[labelDate.month - 1]} '${labelDate.year.toString().substring(2)}";
        }

        final textSpan = TextSpan(text: labelStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold));
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - (textPainter.width / 2), chartHeight + 10));
    }

    // 3. PLOT DATA POINTS (Proportionally on the Fixed Timeline)
    List<Offset> points = [];
    
    for (var e in history) {
      double price = (e['price'] as num).toDouble();
      String dateStr = e['date'].toString();
      DateTime dt;
      
      if (dateStr.length == 7) {
        dt = DateTime.parse("$dateStr-15T00:00:00Z"); // Center of the month for YYYY-MM
      } else {
        dt = DateTime.parse("${dateStr}T00:00:00Z");
      }
      
      int daysFromStart = dt.difference(startDate).inDays;
      double xPct = daysFromStart / totalDurationDays;
      
      // Clamp to prevent drawing off-chart
      if(xPct < 0) xPct = 0;
      if(xPct > 1) xPct = 1;

      double x = paddingLeft + xPct * chartWidth;
      double y = chartHeight - ((price - minPrice) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    // 4. DRAW LINE & GRADIENT
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        path.cubicTo(
          (p0.dx + p1.dx) / 2, p0.dy,
          (p0.dx + p1.dx) / 2, p1.dy,
          p1.dx, p1.dy,
        );
      }

      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, chartHeight)
        ..lineTo(points.first.dx, chartHeight)
        ..close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blueAccent.shade400.withOpacity(0.4),
          Colors.blueAccent.shade400.withOpacity(0.0)
        ],
      ).createShader(Rect.fromLTWH(paddingLeft, 0, chartWidth, chartHeight));

      canvas.drawPath(fillPath, Paint()..shader = gradient);
      canvas.drawPath(path, Paint()..color = Colors.blueAccent.shade400..strokeWidth = 3..style = PaintingStyle.stroke);

    } 

    // 5. DRAW WHITE DATA DOTS (Failsafe overlay)
    final paintDotBorder = Paint()..color = Colors.blueAccent.shade400..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final paintDot = Paint()..color = Colors.white..style = PaintingStyle.fill; 
    
    for (var p in points) {
      canvas.drawCircle(p, 4, paintDot);       // Solid White Inner
      canvas.drawCircle(p, 4, paintDotBorder); // Colored Outer Ring
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}