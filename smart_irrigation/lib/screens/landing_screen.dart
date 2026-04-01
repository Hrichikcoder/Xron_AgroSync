import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/translations.dart';
import '../widgets/fade_in_slide.dart';
import 'auth_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  Offset _mousePosition = Offset.zero;

  // For the dashboard preview animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<Map<String, dynamic>> _sensorData = [
    {'icon': '💧', 'label': 'Soil Moisture', 'value': 62, 'unit': '%', 'trend': '↑ Optimal', 'up': true},
    {'icon': '🌡️', 'label': 'Temperature', 'value': 28, 'unit': '°C', 'trend': '↑ +2° today', 'up': true},
    {'icon': '🌫️', 'label': 'Humidity', 'value': 74, 'unit': '%', 'trend': '↓ Dropping', 'up': false},
    {'icon': '🌧️', 'label': 'Rainfall', 'value': 12, 'unit': 'mm', 'trend': '↑ Above avg', 'up': true},
    {'icon': '☀️', 'label': 'Light (LDR)', 'value': 85, 'unit': '%', 'trend': '↑ Optimal', 'up': true},
    {'icon': '📏', 'label': 'Water Depth', 'value': 45, 'unit': 'cm', 'trend': '↓ Stable', 'up': true},
  ];

  final List<double> _barHeights = [0.55, 0.62, 0.48, 0.70, 0.65, 0.80, 0.72];
  Timer? _sensorTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Simulate live data on the dashboard preview
    _sensorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final rng = Random();
      setState(() {
        _sensorData[0]['value'] = 60 + rng.nextInt(5);
        _sensorData[1]['value'] = 27 + rng.nextInt(3);
        _sensorData[2]['value'] = 72 + rng.nextInt(4);
        _sensorData[3]['value'] = 11 + rng.nextInt(3);
        _sensorData[4]['value'] = 80 + rng.nextInt(8); // LDR simulation
        _sensorData[5]['value'] = 44 + rng.nextInt(3); // Depth simulation
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sensorTimer?.cancel();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  // ─── UI COMPONENTS ───

  Widget _buildHero(bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return Container(
        padding: const EdgeInsets.only(top: 80, bottom: 40),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: _heroLeft(isDark)),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: _buildDashboardCard(isDark)),
                ],
              )
            : Column(
                children: [
                  _heroLeft(isDark),
                  const SizedBox(height: 64),
                  _buildDashboardCard(isDark),
                ],
              ),
      );
    });
  }

  Widget _heroLeft(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI & IoT Powered Platform',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your Farm,\nIntelligently\nConnected',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).textTheme.bodyLarge!.color,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'AgroSync makes farming simpler and smarter. It uses real-time sensor data to handle irrigation and shade automatically, while still letting you take control anytime. It helps you keep your crops healthy, guides you on what to grow, shows the best places to sell, and connects you with other farmers to share and learn together.',
          style: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _goToAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text("Get Started".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🌾 Ramesh\'s Farm — Field A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge!.color)),
                  const SizedBox(height: 4),
                  Text('📍 Nashik, Maharashtra · 4.2 acres', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('Live', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3, // Changed to 3 columns
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, // Slightly reduced spacing
            mainAxisSpacing: 10,
            childAspectRatio: 1.4, // Adjusted ratio to fit 3 neatly
            children: _sensorData.map((s) => _sensorTile(s, isDark)).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                      children: const [
                        TextSpan(text: 'AI detected early blight on tomato plant in Zone B — '),
                        TextSpan(text: 'tap to view', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Adjusted tile to fit 3 in a row
  Widget _sensorTile(Map<String, dynamic> s, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10), // Reduced padding
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12), // Slightly sharper corners
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s['icon'], style: const TextStyle(fontSize: 16)), // Smaller icon
              Flexible(
                child: Text(
                  s['trend'],
                  overflow: TextOverflow.ellipsis, // Prevents text overflow if trend is long
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: s['up'] ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(s['label'], overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)), // Smaller label
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${s['value']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color)), // Smaller value
              const SizedBox(width: 2),
              Text(s['unit'], style: TextStyle(fontSize: 10, color: Colors.grey.shade500)), // Smaller unit
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(bool isDark) {
    final features = [
      {'icon': Icons.sensors, 'title': 'IoT Sensor Network', 'desc': 'Monitor your farm in real time with sensors tracking soil moisture, temperature, humidity, and rainfall—giving you accurate, continuous insights into field conditions.', 'tags': ['Soil Moisture', 'Temperature', 'Rainfall', 'Humidity']},
      {'icon': Icons.water_drop, 'title': 'Automated Irrigation', 'desc': 'Irrigate only when needed using smart automation based on real-time data, helping you save water, reduce effort, and maintain optimal crop conditions.', 'tags': ['Smart Scheduling', 'Water Saving', 'Auto-Trigger']},
      {'icon': Icons.healing, 'title': 'Crop Disease Detection', 'desc': 'Detect crop diseases early by simply uploading an image. Get instant insights and clear guidance to protect your crops before damage spreads.', 'tags': ['Image Analysis', '50+ Diseases', 'Instant Results']},
      {'icon': Icons.grass, 'title': 'Crop Recommendation', 'desc': 'Receive crop suggestions based on your soil, weather, and market trends to choose what grows best and brings higher returns.', 'tags': ['Soil Analysis', 'Season-Aware', 'Profit-Optimized']},
      {'icon': Icons.trending_up, 'title': 'Market Price Engine', 'desc': 'Track live market prices and demand trends to decide the best time and place to sell, ensuring you get the maximum value for your produce.', 'tags': ['Live Prices', 'Best Market', 'Sell Alerts']},
      {'icon': Icons.forum, 'title': 'Farmer Community', 'desc': 'Connect with farmers, share experiences, ask questions, and learn practical solutions from a supportive and growing community.', 'tags': ['Q&A Forum', 'Expert Advice', 'Multilingual']},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, 
      children: [
        Text('Everything You Need, From Soil to Sale', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        Text(
          'AgroSync brings together automation, guidance, and market insights to support every stage of your farming journey.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        const SizedBox(height: 48),
        Center(
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: features.map((f) {
              return Container(
                width: 360,
                height: 400, 
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Icon(f['icon'] as IconData, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 24),
                    Text(f['title'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color)),
                    const SizedBox(height: 12),
                    Text(
                      f['desc'] as String,
                      style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (f['tags'] as List<String>).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      )).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks(bool isDark) {
    final steps = [
      {'num': '1', 'title': 'Set Up Sensors', 'desc': 'Install sensors across your farm to easily track real-time conditions and understand your field better.'},
      {'num': '2', 'title': 'AI Analyzes Data', 'desc': 'The system processes sensor data along with weather and trends to understand your farm’s condition.'},
      {'num': '3', 'title': 'Get Smart Alerts', 'desc': 'Receive timely notifications for irrigation, shade control, crop health issues, and market opportunities.'},
      {'num': '4', 'title': 'Take Better Actions', 'desc': 'Use insights to automate tasks, improve crop care, and sell at the right time for better profits.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('From Data to Decisions, Seamlessly', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color, letterSpacing: -0.5)),
        const SizedBox(height: 48),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: steps.map((s) => Container(
            width: 280,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -10, top: -20,
                  child: Text(
                    s['num']!,
                    style: TextStyle(fontSize: 100, fontWeight: FontWeight.w900, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), height: 1.0),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['title']!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color)),
                    const SizedBox(height: 12),
                    Text(s['desc']!, style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildMarketEngine(bool isDark) {
    final crops = [
      {'icon': '🌾', 'title': 'Wheat · Nashik Mandi', 'sub': 'Best price today · 12 km away', 'price': '₹2,340 / 10 kg', 'change': '↑ +4.2% today', 'up': true},
      {'icon': '🍅', 'title': 'Tomato · Pune Market', 'sub': 'AI Tip: Wait 3 more days', 'price': '₹890 / 10 kg', 'change': '↓ -1.8% today', 'up': false},
      {'icon': '🌽', 'title': 'Maize · Ahmednagar', 'sub': 'Demand spike detected', 'price': '₹1,650 / 10 kg', 'change': '↑ +7.1% this week', 'up': true},
      {'icon': '🧅', 'title': 'Onion · Lasalgaon', 'sub': 'Top mandi by volume', 'price': '₹2,100 / 10 kg', 'change': '↑ Stable', 'up': true},
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final leftContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Know When and Where to Sell', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Text(
            'AgroSync tracks market prices and trends across locations, helping you choose the right time and place to sell so you never miss better opportunities.',
            style: TextStyle(fontSize: 18, height: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _goToAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Market Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      );

      final rightContent = Column(
        children: crops.map((c) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(c['icon'] as String, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['title'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge!.color)),
                    const SizedBox(height: 4),
                    Text(c['sub'] as String, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(c['price'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981))),
                  const SizedBox(height: 4),
                  Text(c['change'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: (c['up'] as bool) ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                ],
              ),
            ],
          ),
        )).toList(),
      );

      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: leftContent),
                const SizedBox(width: 64),
                Expanded(child: rightContent),
              ],
            )
          : Column(
              children: [leftContent, const SizedBox(height: 48), rightContent],
            );
    });
  }

  Widget _buildCommunity(bool isDark) {
    final posts = [
      {'avatar': '🍂', 'question': 'Leaves Turning Yellow', 'answer': 'My crop leaves are turning yellow from the edges. Could this be due to overwatering, nutrient deficiency, or something else?', 'tag': 'Crop Health', 'meta': '12 replies'},
      {'avatar': '💧', 'question': 'Best Time to Irrigate Crops', 'answer': 'When is the most effective time to irrigate for better water absorption—early morning or evening? Looking for practical advice.', 'tag': 'Irrigation', 'meta': '8 replies'},
      {'avatar': '🐛', 'question': 'Pest Attack on Tomato Plants', 'answer': 'Small holes appearing on tomato leaves and fruits. What could be causing this, and how can I control it naturally?', 'tag': 'Pest Control', 'meta': '24 replies'},
      {'avatar': '📈', 'question': 'Choosing the Right Market to Sell', 'answer': 'How do you decide the best market to sell your produce? Any tips on getting better prices or timing the sale?', 'tag': 'Market', 'meta': '31 replies'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text('A Community That Farms Together', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge!.color, letterSpacing: -0.5), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                'Learn from real experiences, get expert-backed advice, and solve everyday farming problems with a network that grows stronger together.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        
        // Horizontal scrolling row replacing the wrap
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: posts.map((p) {
              return Padding(
                padding: const EdgeInsets.only(right: 24.0),
                child: Container(
                  width: 400, // Fixed width for horizontal scrolling
                  height: 240, 
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.02), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Text(p['avatar']!, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(height: 16),
                      Text(p['question']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(p['answer']!, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(p['tag']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                          const Spacer(),
                          Text(p['meta']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 48),
        Center(
          child: ElevatedButton(
            onPressed: _goToAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Explore Community', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCTA() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Ready to Farm Smarter?",
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "Join thousands of farmers using AgroSync to simplify decisions, reduce effort, and improve profits. Start for free and experience smarter irrigation, better crop care, and data-driven selling—without any complexity.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Navigating to the Market Model Screen
              Navigator.pushNamed(context, '/market-model');
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text("🌿 Start for Free — No Cost", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/plant_icon.png', height: 48),
            const SizedBox(width: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  letterSpacing: -0.5,
                  fontSize: 42,
                ),
                children: [
                  const TextSpan(text: "Agro"),
                  TextSpan(text: "Sync", style: TextStyle(color: Colors.greenAccent.shade700)),
                ],
              ),
            ),
          ],
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
                      const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.2),
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
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      children: [
                        FadeInSlide(index: 0, child: _buildHero(isDark)),
                        const SizedBox(height: 80),
                        FadeInSlide(index: 1, child: _buildFeatures(isDark)),
                        const SizedBox(height: 120),
                        FadeInSlide(index: 2, child: _buildHowItWorks(isDark)),
                        const SizedBox(height: 120),
                        FadeInSlide(index: 3, child: _buildMarketEngine(isDark)),
                        const SizedBox(height: 120),
                        FadeInSlide(index: 4, child: _buildCommunity(isDark)),
                        const SizedBox(height: 120),
                        FadeInSlide(index: 5, child: _buildCTA()),
                        const SizedBox(height: 100),
                        Divider(color: isDark ? Colors.white24 : Colors.black12),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Text(
                            "© 2026 AgroSync by Team XRON. All rights reserved.",
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        )
                      ],
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