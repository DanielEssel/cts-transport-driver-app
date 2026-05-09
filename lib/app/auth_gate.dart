// auth_gate.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/root/driver_root_shell.dart';
import '../../features/driver/models/driver_types.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // ✅ Delegate to a separate widget so the future isn't
        // re-created on every auth stream emission
        return _ProfileLoader(uid: authSnapshot.data!.uid);
      },
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({required this.uid});
  final String uid;

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  late final Future<DocumentSnapshot> _profileFuture;

  @override
  void initState() {
    super.initState();
    // ✅ Future is created once and cached in state
    _profileFuture = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _ErrorScreen(message: snapshot.error.toString());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Profile missing — sign them out so they don't get stuck
          FirebaseAuth.instance.signOut();
          return const _ErrorScreen(message: 'Driver profile not found.');
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final profile = DriverProfile.fromMap(data);

        return DriverRootShell(profile: profile);
      },
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(message)),
    );
  }
}