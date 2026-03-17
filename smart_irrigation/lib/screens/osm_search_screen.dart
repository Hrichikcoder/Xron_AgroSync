import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/translations.dart';
import '../widgets/agro_pulse_loader.dart';

class OSMSearchScreen extends StatefulWidget {
  const OSMSearchScreen({super.key});

  @override
  State<OSMSearchScreen> createState() => _OSMSearchScreenState();
}

class _OSMSearchScreenState extends State<OSMSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _predictions = [];
  bool _isLoading = false;

  Future<void> _searchPlaces(String input) async {
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://photon.komoot.io/api/?q=${Uri.encodeComponent(input)}&limit=8";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _predictions = data['features'] ?? []);
      } else {
        setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint("Error fetching places: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "Search city, village, or zip...".tr,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade500,
                size: 20,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _predictions = []);
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _searchPlaces,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: AgroPulseLoader(message: "Locating...".tr))
          : _predictions.isEmpty && _controller.text.isNotEmpty && !_isLoading
          ? Center(
              child: Text(
                "No locations found.".tr,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ListView.separated(
              itemCount: _predictions.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                final props = prediction['properties'];
                final coords = prediction['geometry']['coordinates'];

                String name = props['name'] ?? '';
                String state = props['state'] ?? '';
                String country = props['country'] ?? '';
                String displayName = [
                  name,
                  state,
                  country,
                ].where((e) => e.isNotEmpty).join(", ");

                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.grey),
                  title: Text(
                    displayName.isEmpty ? 'Unknown Location'.tr : displayName,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'lat': coords[1],
                      'lng': coords[0],
                      'address': displayName,
                    });
                  },
                );
              },
            ),
    );
  }
}