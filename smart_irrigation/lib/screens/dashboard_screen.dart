import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../core/translations.dart';
import '../core/globals.dart'; 
import 'sensors_screen.dart';
import 'crop_doctor_screen.dart';
import 'market_screen.dart';
import 'settings_screen.dart';
import '../core/app_config.dart';
import 'community_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  WebSocketChannel? _channel;

  List<Widget> get _screens => [
        const SensorsScreen(),
        const CropDoctorScreen(),
        const MarketScreen(),
        const CommunityScreen(),
        SettingsScreen(
          isDarkMode: SmartIrrigationApp.themeNotifier.value == ThemeMode.dark,
          onThemeChanged: (bool isDark) {
            SmartIrrigationApp.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
          },
        ),
      ];

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchInitialProfile();
    _fetchNotificationHistory();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://${AppConfig.serverIp}:8000/api/notifications/ws'), 
      );

      _channel!.stream.listen((message) {
        final decodedMessage = jsonDecode(message);
        
        if (!mounted) return;

        final newNotification = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: (decodedMessage['type'] == 'alert' ? "Critical Alert" : "System Update").tr,
          message: (decodedMessage['message'] ?? "New event occurred").toString().tr,
          timestamp: DateTime.now(),
        );

        final currentList = List<AppNotification>.from(SmartIrrigationApp.notificationsNotifier.value);
        currentList.insert(0, newNotification);
        SmartIrrigationApp.notificationsNotifier.value = currentList;

        if (SettingsScreen.pushNotificationsEnabled.value) {
          _showBottomPopupNotification();
        }
      }, onError: (error) {
        debugPrint("WebSocket Error: $error");
      });
    } catch (e) {
      debugPrint("WebSocket Connection Error: $e");
    }
  }

  Future<void> _fetchNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List notifications = data['notifications'];
          
          final List<AppNotification> historyList = notifications.map((n) => AppNotification(
            id: n['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: (n['type'] == 'alert' ? "Critical Alert" : "System Update").tr,
            message: (n['message'] ?? "Event occurred").toString().tr,
            timestamp: n['timestamp'] != null ? DateTime.parse(n['timestamp']) : DateTime.now(),
            isRead: false,
          )).toList();

          if (mounted) {
            SmartIrrigationApp.notificationsNotifier.value = historyList;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching notification history: $e");
    }
  }

  Future<void> _fetchInitialProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/get_profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final user = data['user'];
          
          currentUserName.value = user['name'] ?? "Unknown";
          currentUserEmail.value = user['email'] ?? "Unknown";
          currentUserPhone.value = user['phone'] ?? "Unknown";
          currentUserLocation.value = user['location'] ?? "Unknown";
          
          if (user['profile_pic_base64'] != null) {
            userProfileImageNotifier.value = base64Decode(user['profile_pic_base64']);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching initial profile: $e");
    }
  }

  void _showBottomPopupNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Color(0xFF064E3B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "New notification received".tr,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE8F5E9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openNotificationInbox() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withOpacity(0.95) : const Color(0xFFF8FAFC).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Notifications",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                      Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                final list = List<AppNotification>.from(SmartIrrigationApp.notificationsNotifier.value);
                                for (var notif in list) {
                                  notif.isRead = true;
                                }
                                SmartIrrigationApp.notificationsNotifier.value = list;
                              },
                              child: Text(
                                "Mark all as read",
                                style: TextStyle(color: Colors.greenAccent.shade700, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                              tooltip: "Clear all notifications",
                              onPressed: () {
                                SmartIrrigationApp.notificationsNotifier.value = [];
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ValueListenableBuilder<List<AppNotification>>(
                      valueListenable: SmartIrrigationApp.notificationsNotifier,
                      builder: (context, notifications, _) {
                        if (notifications.isEmpty) {
                          return Center(
                            child: Text(
                              "No new notifications",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          );
                        }
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            final isRead = notif.isRead;

                            return InkWell(
                              onTap: () {
                                if (!isRead) {
                                  final list = List<AppNotification>.from(SmartIrrigationApp.notificationsNotifier.value);
                                  list[index].isRead = true;
                                  SmartIrrigationApp.notificationsNotifier.value = list;
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                color: isRead ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.05) : Colors.greenAccent.withOpacity(0.1)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRead 
                                            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                                            : Colors.redAccent.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.water_drop_rounded,
                                        color: isRead ? Colors.grey.shade500 : Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                                                    color: isRead 
                                                        ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
                                                        : Theme.of(context).textTheme.bodyLarge!.color,
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: Colors.greenAccent.shade700,
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notif.message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isRead ? Colors.grey.shade600 : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _selectedIndex == 0 
        ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      letterSpacing: -0.8,
                    ),
                    children: const [
                      TextSpan(
                        text: "A",
                        style: TextStyle(fontSize: 44), 
                      ),
                      TextSpan(
                        text: "gro",
                        style: TextStyle(fontSize: 34),
                      ),
                      TextSpan(
                        text: "Sync",
                        style: TextStyle(
                          fontSize: 34,
                          color: Color(0xFF2C6339),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset(
                  'assets/plant_icon.png', 
                  width: 78, 
                  height: 78,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            actions: [
              ValueListenableBuilder<List<AppNotification>>(
                valueListenable: SmartIrrigationApp.notificationsNotifier,
                builder: (context, notifications, child) {
                  final unreadCount = notifications.where((n) => !n.isRead).length;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.notifications_rounded,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                          onPressed: _openNotificationInbox,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 14,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  openEditProfileNotifier.value = true;
                  _onItemTapped(3); 
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E6B52), width: 2),
                  ),
                  child: ValueListenableBuilder<Uint8List?>(
                    valueListenable: userProfileImageNotifier,
                    builder: (context, imageBytes, child) {
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                        child: imageBytes == null 
                            ? Icon(Icons.person_rounded, color: isDark ? Colors.white : Colors.black87, size: 24)
                            : null,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          )
        : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      // Replace the existing bottomNavigationBar block in dashboard_screen.dart
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: isDark ? const Color(0xFF10B981) : const Color(0xFF0D5C2E),
            unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            showUnselectedLabels: true, // Forces labels to always show
            type: BottomNavigationBarType.fixed, // Prevents the shifting animation
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            selectedIconTheme: const IconThemeData(size: 28),
            unselectedIconTheme: const IconThemeData(size: 24),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.dashboard_rounded)),
                label: 'Overview'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.medical_services_rounded)),
                label: 'Crop Doctor'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.storefront_rounded)),
                label: 'Market'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.forum_rounded)),
                label: 'Community'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.settings_rounded)),
                label: 'Settings'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}