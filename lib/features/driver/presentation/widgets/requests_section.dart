import 'package:flutter/material.dart';
import '../../../../core/constants/design_constants.dart';

class RequestsSection extends StatelessWidget {
  final String serviceType;
  final bool isOnline;
  final VoidCallback onGoOnline;

  const RequestsSection({
    super.key,
    required this.serviceType,
    required this.isOnline,
    required this.onGoOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Available Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: SpacingConstants.md),
        if (!isOnline)
          Center(
            child: ElevatedButton(
              onPressed: onGoOnline,
              child: const Text("Go Online to see Requests"),
            ),
          )
        else
          const Center(child: Text("Searching for rides in your area...")),
      ],
    );
  }
}