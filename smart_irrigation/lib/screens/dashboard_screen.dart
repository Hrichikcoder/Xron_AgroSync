import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import '../core/translations.dart';
import 'sensors_screen.dart';
import 'crop_doctor_screen.dart';
import 'market_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        const SensorsScreen(),
        const CropDoctorScreen(),
        const MarketScreen(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerDemoNotification();
    });
  }

  void _triggerDemoNotification() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final newNotification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Critical Alert".tr,
      message: "Water level dropping rapidly in Sector 4.".tr,
      timestamp: DateTime.now(),
    );

    final currentList = List<AppNotification>.from(SmartIrrigationApp.notificationsNotifier.value);
    currentList.insert(0, newNotification);
    SmartIrrigationApp.notificationsNotifier.value = currentList;

    _showBottomPopupNotification();
  }

  void _showBottomPopupNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "New notification received".tr,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.greenAccent.shade700,
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
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.eco, color: const Color(0xFF2C6339), size: 26),
                    Positioned(
                      bottom: -2,
                      child: Icon(Icons.change_history, color: const Color(0xFF2C6339), size: 14),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  "Agro",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  "Sync",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C6339),
                    letterSpacing: -0.5,
                  ),
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E6B52), width: 2),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: isDark ? const Color(0xFF10B981) : const Color(0xFF0D5C2E),
            unselectedItemColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            selectedIconTheme: const IconThemeData(size: 28),
            unselectedIconTheme: const IconThemeData(size: 24),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_rounded),
                label: 'Overview'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.medical_services_rounded),
                label: 'Crop Dr'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.storefront_rounded),
                label: 'Market'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_rounded),
                label: 'Settings'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}