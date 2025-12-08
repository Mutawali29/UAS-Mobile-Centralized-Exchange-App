import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimService {
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        // HEADER wajib agar tidak diblokir oleh OpenStreetMap
        'User-Agent': 'flutter-location-app'
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["display_name"];
    }

    return null;
  }
}
