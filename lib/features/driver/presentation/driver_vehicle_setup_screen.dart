import 'package:cts_transport_driver_app/features/driver/models/driver_type.dart';
import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/app_routes.dart';

class DriverVehicleSetupScreen extends StatelessWidget {
  const DriverVehicleSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Vehicle Setup'),
        backgroundColor: AppTheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bike_rounded,
                size: 70, color: AppTheme.primary),
            const SizedBox(height: 24),
            const Text(
              'Set up your vehicle',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Next we’ll collect your vehicle and driver documents for approval.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.driverDocuments,
                    arguments: DriverType.okadaDelivery
                  );
                },
                child: const Text('Continue to document upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


