import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/app_config.dart';
import '../core/translations.dart';
import '../widgets/agro_pulse_loader.dart';
import '../widgets/fade_in_slide.dart';

class GovSchemesScreen extends StatefulWidget {
  final bool showAppBar;
  const GovSchemesScreen({super.key, this.showAppBar = true});

  @override
  State<GovSchemesScreen> createState() => _GovSchemesScreenState();
}

class _GovSchemesScreenState extends State<GovSchemesScreen> {
  List<dynamic> schemes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchemes();
  }

  Future<void> _fetchSchemes() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/community/schemes'));
      if (response.statusCode == 200) {
        setState(() {
          schemes = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching schemes: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch link.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: widget.showAppBar ? AppBar(
        title: Text("Government Schemes".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ) : null,
      body: isLoading
          ? const Center(child: AgroPulseLoader(message: "Fetching Active Schemes..."))
          : schemes.isEmpty
              ? Center(child: Text("No schemes available at the moment.".tr))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schemes.length,
                  itemBuilder: (context, index) {
                    final scheme = schemes[index];
                    return FadeInSlide(
                      index: index,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF064E3B).withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance, color: Color(0xFF064E3B), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    scheme['title'],
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (scheme['state'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text("Region: ${scheme['state']}", style: TextStyle(color: Colors.amber.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(height: 12),
                            Text(scheme['description'], style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.4)),
                            const SizedBox(height: 16),
                            if (scheme['link'] != null && scheme['link'].toString().isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    foregroundColor: const Color(0xFF064E3B),
                                    side: const BorderSide(color: Color(0xFF064E3B)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.open_in_browser, size: 24),
                                  label: const Text("Apply / Learn More", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  onPressed: () => _launchURL(scheme['link']),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}