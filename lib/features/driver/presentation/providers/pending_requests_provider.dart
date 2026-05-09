import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../domain/entities/ride_request.dart';
import '../../../domain/entities/request_type.dart';
import '../../../domain/repositories/driver_repository.dart';



// Pending Requests Provider
@riverpod
class PendingRequests extends _$PendingRequests {
  late final GetPendingRequests _getPendingRequests;
  late final String _driverId;
  final Set<String> _dismissedIds = {};
  
  Stream<List<RideRequest>>? _requestsStream;
  
  @override
  Future<List<RideRequest>> build(String serviceType) async {
    _getPendingRequests = ref.read(getPendingRequestsProvider);
    _driverId = FirebaseAuth.instance.currentUser!.uid;
    
    // Return empty list initially
    return [];
  }
  
  Stream<List<RideRequest>> watchRequests(String serviceType) {
    return _getPendingRequests(_driverId, serviceType).map(
      (requests) => requests
          .where((request) => !_dismissedIds.contains(request.id))
          .toList(),
    );
  }
  
  void dismiss(String requestId) {
    _dismissedIds.add(requestId);
    // Force refresh of current state
    ref.invalidateSelf();
  }
}

