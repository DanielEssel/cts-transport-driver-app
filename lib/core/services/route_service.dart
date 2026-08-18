// features/ride/services/route_service.dart
//
// ✅ Fetches a real road route from Google Directions API
// ✅ Decodes the encoded polyline into LatLng points
// ✅ Returns distance (metres) and duration (seconds) for fare calculation
// ✅ API key injected via --dart-define=MAPS_API_KEY=YOUR_KEY
// ✅ Riverpod provider for DI + testability

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_constants.dart'; // Adjust the import path as needed
import 'package:flutter/foundation.dart' show debugPrint;


const _apiKey = AppConstants.googleMapsApiKey;

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

class RouteService {
  final HttpClient _client;
  RouteService({HttpClient? client}) : _client = client ?? HttpClient();

  Future<RouteResult?> getRoute(LatLng origin, LatLng destination) async {
  debugPrint('🔑 API key length: ${_apiKey.length}, first 8 chars: ${_apiKey.isNotEmpty ? _apiKey.substring(0, _apiKey.length.clamp(0, 8)) : "EMPTY"}');
  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/directions/json',
    {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': _apiKey,
      'mode': 'driving',
    },
  );

  try {
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      debugPrint('❌ RouteService: HTTP ${response.statusCode}');
      return null;
    }

    final bodyString = await utf8.decoder.bind(response).join();
    final body = json.decode(bodyString) as Map<String, dynamic>;
    if (body['status'] != 'OK') {
      debugPrint('❌ RouteService: API status=${body['status']}, error_message=${body['error_message']}');
      return null;
    }

    final route = (body['routes'] as List).first as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final distanceM = (leg['distance']['value'] as num).toDouble();
    final durationS = (leg['duration']['value'] as num).toInt();
    final encoded = route['overview_polyline']['points'] as String;
    final points = _decodePolyline(encoded);

    return RouteResult(
      points: points,
      distanceKm: distanceM / 1000,
      durationMin: (durationS / 60).ceil(),
    );
  } catch (e) {
    debugPrint('❌ RouteService: exception: $e');
    return null;
  }
}

  /// Google's encoded polyline algorithm decoder.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

final routeServiceProvider = Provider<RouteService>(
  (_) => RouteService(),
);
