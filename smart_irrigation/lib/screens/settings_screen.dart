import 'package:flutter/material.dart';
import '../core/globals.dart';
import '../core/translations.dart';
import '../widgets/fade_in_slide.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool pushNotifications = true;
  bool waterAlerts = true;
  bool autoUpdate = false;

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    String currentLanguageName =
        AppTranslations.languageNames[languageNotifier.value] ?? 'English';

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
                    child: Text(
                      "Settings".tr,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInSlide(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Basic Configuration".tr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black38
                                    : Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  "Dark Mode".tr,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                secondary: const Icon(
                                  Icons.dark_mode,
                                  size: 20,
                                ),
                                value: isDark,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) {
                                  themeNotifier.value = val
                                      ? ThemeMode.dark
                                      : ThemeMode.light;
                                },
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                              ListTile(
                                title: Text(
                                  "Language".tr,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  currentLanguageName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                leading: const Icon(Icons.language, size: 20),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      title: Text(
                                        "Select Language".tr,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: AppTranslations
                                              .languageNames
                                              .length,
                                          itemBuilder: (context, index) {
                                            String langCode = AppTranslations
                                                .languageNames
                                                .keys
                                                .elementAt(index);
                                            String langName = AppTranslations
                                                .languageNames[langCode]!;
                                            return ListTile(
                                              title: Text(
                                                langName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              onTap: () {
                                                languageNotifier.value =
                                                    langCode;
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  FadeInSlide(
                    index: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notifications".tr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black38
                                    : Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  "Push Notifications".tr,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                secondary: const Icon(
                                  Icons.notifications,
                                  size: 20,
                                ),
                                value: pushNotifications,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) =>
                                    setState(() => pushNotifications = val),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                              SwitchListTile(
                                title: Text(
                                  "Critical Water Alerts".tr,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                secondary: const Icon(
                                  Icons.warning_amber,
                                  size: 20,
                                ),
                                value: waterAlerts,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) =>
                                    setState(() => waterAlerts = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  FadeInSlide(
                    index: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Advanced & Maintenance".tr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black38
                                    : Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  "Auto-Update Firmwares".tr,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                secondary: const Icon(
                                  Icons.system_update,
                                  size: 20,
                                ),
                                value: autoUpdate,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) =>
                                    setState(() => autoUpdate = val),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                              ListTile(
                                title: Text(
                                  "Account Details".tr,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                                leading: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Cannot delete guest account",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ), // SliverPadding
        ], // slivers
      ), // CustomScrollView
    ); // SafeArea
  }
}