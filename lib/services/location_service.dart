// services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  // Cek dan request permission menggunakan Geolocator
  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Cek apakah location service aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return false;
    }

    // Cek permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  // Dapatkan lokasi saat ini
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _handlePermission();

      if (!hasPermission) {
        print('Permission not granted');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      print('Location retrieved: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Dapatkan alamat dari koordinat menggunakan Nominatim API
  Future<Map<String, String>> getAddressFromCoordinates(
      double latitude,
      double longitude,
      ) async {
    try {
      print('Getting address from Nominatim for: $latitude, $longitude');

      // URL Nominatim API
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
            'format=json&'
            'lat=$latitude&'
            'lon=$longitude&'
            'zoom=18&'
            'addressdetails=1',
      );

      // Kirim request dengan User-Agent (required by Nominatim)
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterLocationApp/1.0',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Nominatim API request timeout');
        },
      );

      print('Nominatim response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Nominatim response: $data');

        // Parse address components
        final address = data['address'] ?? {};

        // Build full address
        List<String> addressParts = [];

        // Tambahkan komponen alamat
        if (address['road'] != null) {
          addressParts.add(address['road']);
        }
        if (address['suburb'] != null) {
          addressParts.add(address['suburb']);
        }
        if (address['village'] != null && address['suburb'] == null) {
          addressParts.add(address['village']);
        }
        if (address['city'] != null) {
          addressParts.add(address['city']);
        } else if (address['town'] != null) {
          addressParts.add(address['town']);
        } else if (address['county'] != null) {
          addressParts.add(address['county']);
        }
        if (address['state'] != null) {
          addressParts.add(address['state']);
        }
        if (address['postcode'] != null) {
          addressParts.add(address['postcode']);
        }
        if (address['country'] != null) {
          addressParts.add(address['country']);
        }

        String fullAddress = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : data['display_name'] ?? 'Address not available';

        print('Full address built: $fullAddress');

        return {
          'street': address['road']?.toString() ?? 'N/A',
          'subLocality': address['suburb']?.toString() ?? address['village']?.toString() ?? '',
          'locality': address['city']?.toString() ?? address['town']?.toString() ?? address['county']?.toString() ?? 'N/A',
          'administrativeArea': address['state']?.toString() ?? '',
          'postalCode': address['postcode']?.toString() ?? '',
          'country': address['country']?.toString() ?? 'N/A',
          'fullAddress': fullAddress,
        };
      } else {
        print('Nominatim API error: ${response.statusCode}');
        throw Exception('Failed to fetch address from Nominatim');
      }
    } catch (e, stackTrace) {
      print('Error getting address from Nominatim: $e');
      print('Stack trace: $stackTrace');

      // Return koordinat sebagai fallback
      return _getDefaultAddressMap(
        'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
      );
    }
  }

  // Helper method untuk default address map
  Map<String, String> _getDefaultAddressMap(String fullAddress) {
    return {
      'street': 'N/A',
      'subLocality': '',
      'locality': 'N/A',
      'administrativeArea': '',
      'postalCode': '',
      'country': 'N/A',
      'fullAddress': fullAddress,
    };
  }

  // Format coordinate untuk ditampilkan
  static String formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  // Hitung jarak dalam km
  static double calculateDistanceInKm(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    ) / 1000;
  }

  // Format altitude
  static String formatAltitude(double? altitude) {
    if (altitude == null || altitude == 0.0) {
      return 'N/A';
    }
    return '${altitude.toStringAsFixed(1)} m';
  }

  // Format speed
  static String formatSpeed(double? speed) {
    if (speed == null || speed == 0.0) {
      return '0 km/h';
    }
    // Convert m/s to km/h
    double speedKmh = speed * 3.6;
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  // Get compass direction from heading
  static String getCompassDirection(double? heading) {
    if (heading == null) return 'N/A';

    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    int index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}