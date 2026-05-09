// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$driverRepositoryHash() => r'45dc397058b73ac015c81fa6319f93e7d414c79f';

/// See also [driverRepository].
@ProviderFor(driverRepository)
final driverRepositoryProvider = Provider<DriverRepository>.internal(
  driverRepository,
  name: r'driverRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$driverRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DriverRepositoryRef = ProviderRef<DriverRepository>;
String _$getDriverProfileHash() => r'999eb96e730abb43037e40a21692ab6e10beb8f2';

/// See also [getDriverProfile].
@ProviderFor(getDriverProfile)
final getDriverProfileProvider = Provider<GetDriverProfile>.internal(
  getDriverProfile,
  name: r'getDriverProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getDriverProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetDriverProfileRef = ProviderRef<GetDriverProfile>;
String _$getDriverStatsHash() => r'81f68065bf4aa3d69fa5d218de9d411bb0492740';

/// See also [getDriverStats].
@ProviderFor(getDriverStats)
final getDriverStatsProvider = Provider<GetDriverStats>.internal(
  getDriverStats,
  name: r'getDriverStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getDriverStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetDriverStatsRef = ProviderRef<GetDriverStats>;
String _$getEarningsSummaryHash() =>
    r'cf33ae8d3db3a88eae29b87e869ce4b105b12712';

/// See also [getEarningsSummary].
@ProviderFor(getEarningsSummary)
final getEarningsSummaryProvider = Provider<GetEarningsSummary>.internal(
  getEarningsSummary,
  name: r'getEarningsSummaryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getEarningsSummaryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetEarningsSummaryRef = ProviderRef<GetEarningsSummary>;
String _$toggleOnlineStatusHash() =>
    r'6727a9f6a1a1c2b76cbd78a35a49f184fef33117';

/// See also [toggleOnlineStatus].
@ProviderFor(toggleOnlineStatus)
final toggleOnlineStatusProvider = Provider<ToggleOnlineStatus>.internal(
  toggleOnlineStatus,
  name: r'toggleOnlineStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$toggleOnlineStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ToggleOnlineStatusRef = ProviderRef<ToggleOnlineStatus>;
String _$acceptRideRequestHash() => r'cafdcd2f0707a67be0894be1653e8ec5c08fb29e';

/// See also [acceptRideRequest].
@ProviderFor(acceptRideRequest)
final acceptRideRequestProvider = Provider<AcceptRideRequest>.internal(
  acceptRideRequest,
  name: r'acceptRideRequestProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$acceptRideRequestHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AcceptRideRequestRef = ProviderRef<AcceptRideRequest>;
String _$declineRideRequestHash() =>
    r'3d8bb60ecb0e007a8b14050b1d8a5d6347192b6a';

/// See also [declineRideRequest].
@ProviderFor(declineRideRequest)
final declineRideRequestProvider = Provider<DeclineRideRequest>.internal(
  declineRideRequest,
  name: r'declineRideRequestProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$declineRideRequestHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeclineRideRequestRef = ProviderRef<DeclineRideRequest>;
String _$getPendingRequestsHash() =>
    r'e26851ee911c11145486d759a56cd56e2c99dafa';

/// See also [getPendingRequests].
@ProviderFor(getPendingRequests)
final getPendingRequestsProvider = Provider<GetPendingRequests>.internal(
  getPendingRequests,
  name: r'getPendingRequestsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getPendingRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetPendingRequestsRef = ProviderRef<GetPendingRequests>;
String _$getEarningsHash() => r'560fe0d4ff69b28109fbc54610b0fb695972c72a';

/// See also [getEarnings].
@ProviderFor(getEarnings)
final getEarningsProvider = Provider<GetEarningsSummary>.internal(
  getEarnings,
  name: r'getEarningsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$getEarningsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetEarningsRef = ProviderRef<GetEarningsSummary>;
String _$driverProfileHash() => r'945494d7e270ab643a2eab47aea9a69ff173d36f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [driverProfile].
@ProviderFor(driverProfile)
const driverProfileProvider = DriverProfileFamily();

/// See also [driverProfile].
class DriverProfileFamily extends Family<AsyncValue<DriverProfile>> {
  /// See also [driverProfile].
  const DriverProfileFamily();

  /// See also [driverProfile].
  DriverProfileProvider call(
    String uid,
  ) {
    return DriverProfileProvider(
      uid,
    );
  }

  @override
  DriverProfileProvider getProviderOverride(
    covariant DriverProfileProvider provider,
  ) {
    return call(
      provider.uid,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'driverProfileProvider';
}

/// See also [driverProfile].
class DriverProfileProvider extends AutoDisposeStreamProvider<DriverProfile> {
  /// See also [driverProfile].
  DriverProfileProvider(
    String uid,
  ) : this._internal(
          (ref) => driverProfile(
            ref as DriverProfileRef,
            uid,
          ),
          from: driverProfileProvider,
          name: r'driverProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$driverProfileHash,
          dependencies: DriverProfileFamily._dependencies,
          allTransitiveDependencies:
              DriverProfileFamily._allTransitiveDependencies,
          uid: uid,
        );

  DriverProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uid,
  }) : super.internal();

  final String uid;

  @override
  Override overrideWith(
    Stream<DriverProfile> Function(DriverProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DriverProfileProvider._internal(
        (ref) => create(ref as DriverProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uid: uid,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<DriverProfile> createElement() {
    return _DriverProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DriverProfileProvider && other.uid == uid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DriverProfileRef on AutoDisposeStreamProviderRef<DriverProfile> {
  /// The parameter `uid` of this provider.
  String get uid;
}

class _DriverProfileProviderElement
    extends AutoDisposeStreamProviderElement<DriverProfile>
    with DriverProfileRef {
  _DriverProfileProviderElement(super.provider);

  @override
  String get uid => (origin as DriverProfileProvider).uid;
}

String _$pendingRequestsHash() => r'e51796ad853c581bda1cff50dc0cf1a5bb3a2ba4';

/// See also [pendingRequests].
@ProviderFor(pendingRequests)
const pendingRequestsProvider = PendingRequestsFamily();

/// See also [pendingRequests].
class PendingRequestsFamily extends Family<AsyncValue<List<RideRequest>>> {
  /// See also [pendingRequests].
  const PendingRequestsFamily();

  /// See also [pendingRequests].
  PendingRequestsProvider call(
    String uid,
    String serviceType,
  ) {
    return PendingRequestsProvider(
      uid,
      serviceType,
    );
  }

  @override
  PendingRequestsProvider getProviderOverride(
    covariant PendingRequestsProvider provider,
  ) {
    return call(
      provider.uid,
      provider.serviceType,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pendingRequestsProvider';
}

/// See also [pendingRequests].
class PendingRequestsProvider
    extends AutoDisposeStreamProvider<List<RideRequest>> {
  /// See also [pendingRequests].
  PendingRequestsProvider(
    String uid,
    String serviceType,
  ) : this._internal(
          (ref) => pendingRequests(
            ref as PendingRequestsRef,
            uid,
            serviceType,
          ),
          from: pendingRequestsProvider,
          name: r'pendingRequestsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$pendingRequestsHash,
          dependencies: PendingRequestsFamily._dependencies,
          allTransitiveDependencies:
              PendingRequestsFamily._allTransitiveDependencies,
          uid: uid,
          serviceType: serviceType,
        );

  PendingRequestsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uid,
    required this.serviceType,
  }) : super.internal();

  final String uid;
  final String serviceType;

  @override
  Override overrideWith(
    Stream<List<RideRequest>> Function(PendingRequestsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PendingRequestsProvider._internal(
        (ref) => create(ref as PendingRequestsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uid: uid,
        serviceType: serviceType,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<RideRequest>> createElement() {
    return _PendingRequestsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingRequestsProvider &&
        other.uid == uid &&
        other.serviceType == serviceType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uid.hashCode);
    hash = _SystemHash.combine(hash, serviceType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PendingRequestsRef on AutoDisposeStreamProviderRef<List<RideRequest>> {
  /// The parameter `uid` of this provider.
  String get uid;

  /// The parameter `serviceType` of this provider.
  String get serviceType;
}

class _PendingRequestsProviderElement
    extends AutoDisposeStreamProviderElement<List<RideRequest>>
    with PendingRequestsRef {
  _PendingRequestsProviderElement(super.provider);

  @override
  String get uid => (origin as PendingRequestsProvider).uid;
  @override
  String get serviceType => (origin as PendingRequestsProvider).serviceType;
}

String _$onlineStatusHash() => r'b36dfa1b98d9e444864a0fe29ecb728a79763ea5';

/// See also [OnlineStatus].
@ProviderFor(OnlineStatus)
final onlineStatusProvider =
    AutoDisposeAsyncNotifierProvider<OnlineStatus, bool>.internal(
  OnlineStatus.new,
  name: r'onlineStatusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$onlineStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$OnlineStatus = AutoDisposeAsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
