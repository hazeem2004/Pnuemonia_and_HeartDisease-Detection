import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class HospitalMapScreen extends StatefulWidget {
  const HospitalMapScreen({Key? key}) : super(key: key);

  @override
  _HospitalMapScreenState createState() => _HospitalMapScreenState();
}

class _HospitalMapScreenState extends State<HospitalMapScreen> {
  bool _isLoading = true;
  final List<Map<String, dynamic>> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          _showError('Location permission denied');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _fetchNearbyHospitals(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to get location: $e');
    }
  }

  Future<void> _fetchNearbyHospitals(double lat, double lng) async {
    try {
      // OpenStreetMap Overpass API - FREE, NO API KEY REQUIRED!
      final query = '''
        [out:json][timeout:25];
        (
          node["amenity"="hospital"](around:5000,$lat,$lng);
          way["amenity"="hospital"](around:5000,$lat,$lng);
          node["healthcare"="hospital"](around:5000,$lat,$lng);
          way["healthcare"="hospital"](around:5000,$lat,$lng);
        );
        out body;
        >;
        out skel qt;
      ''';

      final url = Uri.parse(
        'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        setState(() {
          _hospitals.clear();

          for (var element in elements) {
            if (element['type'] == 'node' || element['type'] == 'way') {
              final tags = element['tags'] ?? {};
              final name = tags['name'] ?? 'Hospital';

              // Get coordinates
              double hospitalLat, hospitalLng;
              if (element['type'] == 'node') {
                hospitalLat = element['lat'];
                hospitalLng = element['lon'];
              } else {
                // For ways, use center coordinates if available
                hospitalLat =
                    element['center']?['lat'] ?? element['lat'] ?? lat;
                hospitalLng =
                    element['center']?['lon'] ?? element['lon'] ?? lng;
              }

              // Calculate distance
              final distance = Geolocator.distanceBetween(
                    lat,
                    lng,
                    hospitalLat,
                    hospitalLng,
                  ) /
                  1000; // Convert to km

              _hospitals.add({
                'name': name,
                'address': tags['addr:street'] ??
                    tags['addr:full'] ??
                    'Address not available',
                'phone': tags['phone'] ?? tags['contact:phone'] ?? '',
                'lat': hospitalLat,
                'lng': hospitalLng,
                'distance': distance,
              });
            }
          }

          // Sort by distance
          _hospitals.sort((a, b) => a['distance'].compareTo(b['distance']));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to fetch hospitals');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error fetching hospitals: $e');
    }
  }

  Future<void> _callHospital(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not launch phone app');
    }
  }

  Future<void> _getDirections(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not launch maps');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hospitals.isEmpty
              ? const Center(
                  child: Text('No hospitals found nearby'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = _hospitals[index];
                    return _buildHospitalCard(hospital, index);
                  },
                ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital, int index) {
    final lat = hospital['lat'] as double;
    final lng = hospital['lng'] as double;
    final distance = hospital['distance'] as double;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital['name'] ?? 'Hospital',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hospital['vicinity'] != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hospital['vicinity'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getDirections(lat, lng),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 10),
                if (hospital['phone'] != null && hospital['phone'].isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      _callHospital(hospital['phone']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Icon(Icons.phone, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
