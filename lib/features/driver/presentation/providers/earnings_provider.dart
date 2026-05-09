// presentation/providers/earnings_provider.dart (Complete)
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/earnings_summary.dart';
import '../../domain/usecases/get_earnings_summary.dart';
import 'driver_home_providers.dart';

part 'earnings_provider.g.dart';

@riverpod
class EarningsNotifier extends _$EarningsNotifier {
  late final GetEarningsSummary _getEarningsSummary;
  late final String _driverId;
  
  @override
  Future<EarningsSummary> build() async {
    _getEarningsSummary = ref.read(getEarningsSummaryProvider);
    _driverId = FirebaseAuth.instance.currentUser!.uid;
    
    // Listen to real-time earnings updates
    final subscription = _getEarningsSummary(_driverId).listen(
      (result) {
        result.fold(
          (failure) => state = AsyncError(failure, StackTrace.current),
          (earnings) => state = AsyncData(earnings),
        );
      },
    );
    
    ref.onDispose(subscription.cancel);
    
    // Return empty earnings initially
    return  EarningsSummary();
  }
  
  // Convenience getters
  EarningsSummary get earnings => state.value ??  EarningsSummary();
  
  bool get hasData => state.hasValue;
  
  bool get isLoading => state.isLoading;
  
  void refresh() {
    ref.invalidateSelf();
  }
}