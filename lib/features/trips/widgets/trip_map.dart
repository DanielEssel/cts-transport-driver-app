import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/marker_service.dart';

class TripMap extends StatelessWidget {
  final GoogleMapController? controller;
  final Function(GoogleMapController) onMapCreated;

  final LatLng driverPos;
  final LatLng pickupPos;
  final LatLng dropoffPos;

  final double driverHeading;
  final String? serviceType;

  final Set<Polyline> polylines;

  final bool showMyLocation;

  /// Controls whether the pickup marker is displayed.
  final bool showPickup;

  /// Controls whether the drop-off marker is displayed.
  final bool showDropoff;

  /// Controls whether the driver marker is displayed.
  final bool showDriver;

  const TripMap({
    super.key,
    required this.controller,
    required this.onMapCreated,
    required this.driverPos,
    required this.pickupPos,
    required this.dropoffPos,
    required this.driverHeading,
    this.serviceType,
    this.polylines = const {},
    this.showMyLocation = false,
    this.showPickup = true,
    this.showDropoff = true,
    this.showDriver = true,
  });

  static const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8f5e9"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d9f2"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    // Idempotent: shares one load future. Guarantees icons start loading even
    // if no earlier screen pre-warmed them.
    MarkerService.instance.warmUp(context);

    // Rebuild when icons finish loading, so static pickup/drop-off pins don't
    // stay as default fallback pins until the next unrelated rebuild.
    return ValueListenableBuilder<int>(
      valueListenable: MarkerService.instance.revision,
      builder: (_, __, ___) => GoogleMap(
        style: _mapStyle,
        onMapCreated: onMapCreated,
        // Start on the pickup, not on the driver (which is a placeholder
        // until the first GPS fix).
        initialCameraPosition: CameraPosition(
          target: pickupPos,
          zoom: 14,
        ),
        markers: _buildMarkers(context),
        polylines: polylines,
        myLocationEnabled: showMyLocation,
        myLocationButtonEnabled: false, // screens have their own recenter button
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
      ),
    );
  }

  Set<Marker> _buildMarkers(BuildContext context) {
    final ms = MarkerService.instance;
    final markers = <Marker>{};

    if (showPickup) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupPos,
          icon: ms.pickup(),
          anchor: const Offset(0.5, 1.0),
          infoWindow: const InfoWindow(
            title: 'Pickup',
          ),
        ),
      );
    }

    if (showDropoff) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoffPos,
          icon: ms.dropoff(),
          anchor: const Offset(0.5, 1.0),
          infoWindow: const InfoWindow(
            title: 'Drop-off',
          ),
        ),
      );
    }

    if (showDriver) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: ms.vehicle(serviceType ?? 'taxi'),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(
            title: 'You',
          ),
          rotation: driverHeading,
          flat: true,
          zIndex: 10, // always above pickup/drop-off pins
        ),
      );
    }

    return markers;
  }
}