import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'models/driver.dart';
import 'models/truck.dart';
import 'models/trip.dart';
import 'seed_data.dart';

abstract class FleetRepository {
  Stream<List<Trip>> watchTrips();
  Future<List<Trip>> getTrips();
  Future<Trip?> getTripById(String id);
  Future<Trip?> getCurrentTripForDriver(String driverId);
  Future<void> updateTripStatus(String tripId, TripStatus status);
  Future<bool> verifyDeliveryOtp(String tripId, String otp);
  Future<void> submitProofOfDelivery(
    String tripId, {
    required String otp,
    required String photoPath,
    required String signatureSvg,
  });

  Future<void> acceptTrip(String tripId);
  Future<void> startTrip(String tripId);
  Future<void> reportBreakdown(
    String tripId, {
    required double latitude,
    required double longitude,
    required String reason,
    String? remarks,
  });
  Future<void> reportDeliveryFailed(String tripId, {String? remarks});

  Future<Trip> createTrip({
    required String from,
    required String to,
    required String cargo,
    required double weightTons,
    required String driverId,
  });

  Stream<List<Driver>> watchDrivers();
  Future<List<Driver>> getDrivers();
  Future<Driver?> getDriverById(String id);

  Stream<List<Truck>> watchTrucks();
  Future<List<Truck>> getTrucks();
  Future<Truck?> getTruckByPlate(String plate);

  Future<List<String>> getPlaces();
  Future<int> getRunningTripsCount();
  Future<int> getFreeTrucksCount();
  Future<int> getDeliveredThisMonthCount();
  Future<List<String>> getNeedsAttentionList();
}

class LocalFleetRepository implements FleetRepository {
  static LocalFleetRepository? _instance;
  static LocalFleetRepository get instance => _instance ??= LocalFleetRepository._();

  LocalFleetRepository._() {
    _init();
  }

  // Factory constructor for unit testing with custom persistence directory
  factory LocalFleetRepository.forTesting({Directory? testDir, ApiClient? apiClient}) {
    final repo = LocalFleetRepository._();
    if (testDir != null) repo._storageDir = testDir;
    if (apiClient != null) repo._apiClient = apiClient;
    return repo;
  }

  Directory? _storageDir;
  ApiClient _apiClient = ApiClient();
  final List<Trip> _trips = [];
  final List<Driver> _drivers = [];
  final List<Truck> _trucks = [];
  final List<String> _places = [];

  final _tripsController = StreamController<List<Trip>>.broadcast();
  final _driversController = StreamController<List<Driver>>.broadcast();
  final _trucksController = StreamController<List<Truck>>.broadcast();

  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;
    _drivers.addAll(SeedData.drivers);
    _trucks.addAll(SeedData.trucks);
    _places.addAll(SeedData.places);
    _trips.addAll(SeedData.trips);

    await _loadFromDisk();
    _isInitialized = true;
    _notifyAll();

    // Asynchronously synchronize with live FastAPI backend
    unawaited(_syncFromRemote());
  }

  Future<void> refresh() => _syncFromRemote();

  Future<void> _syncFromRemote() async {
    try {
      final remoteTrips = await _apiClient.getTrips();
      if (remoteTrips.isNotEmpty) {
        _trips.clear();
        _trips.addAll(remoteTrips);
        await _saveToDisk();
      }
      final remoteTrucks = await _apiClient.getTrucks();
      if (remoteTrucks.isNotEmpty) {
        _trucks.clear();
        _trucks.addAll(remoteTrucks);
      }
      final remoteDrivers = await _apiClient.getDrivers();
      if (remoteDrivers.isNotEmpty) {
        _drivers.clear();
        _drivers.addAll(remoteDrivers);
      }
      _notifyAll();
    } catch (_) {
      // Offline fallback
    }
  }

  File? _getStorageFile() {
    if (_storageDir == null) return null;
    return File('${_storageDir!.path}/smartfleet_db.json');
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = _getStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data.containsKey('trips')) {
          _trips.clear();
          for (final item in data['trips'] as List) {
            _trips.add(Trip.fromJson(item as Map<String, dynamic>));
          }
        }
      }
    } catch (e) {
      debugPrint('FleetRepository disk load error: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = _getStorageFile();
      if (file != null) {
        final data = {
          'trips': _trips.map((t) => t.toJson()).toList(),
        };
        await file.writeAsString(jsonEncode(data), flush: true);
      }
    } catch (e) {
      debugPrint('FleetRepository disk save error: $e');
    }
  }

  void _notifyAll() {
    _tripsController.add(List.unmodifiable(_trips));
    _driversController.add(List.unmodifiable(_drivers));
    _trucksController.add(List.unmodifiable(_trucks));
  }

  @override
  Stream<List<Trip>> watchTrips() async* {
    await _init();
    yield List.unmodifiable(_trips);
    yield* _tripsController.stream;
  }

  @override
  Future<List<Trip>> getTrips() async {
    await _init();
    return List.unmodifiable(_trips);
  }

  @override
  Future<Trip?> getTripById(String id) async {
    await _init();
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Trip?> getCurrentTripForDriver(String driverId) async {
    await _init();
    try {
      return _trips.firstWhere(
        (t) => t.driverId == driverId && t.status != TripStatus.delivered,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = _trips[index];
      double done = old.distanceDoneKm;
      if (status == TripStatus.delivered) {
        done = old.distanceKm;
      } else if (status == TripStatus.running && done == 0.0) {
        done = old.distanceKm * 0.15; // Initialized departure
      }
      _trips[index] = old.copyWith(status: status, distanceDoneKm: done);
      await _saveToDisk();
      _notifyAll();

      // Dispatch update to live backend asynchronously
      unawaited(_apiClient.updateTripStatus(tripId, status));
    }
  }

  @override
  Future<bool> verifyDeliveryOtp(String tripId, String otp) async {
    await _init();
    // 1. Check live backend first
    try {
      final remoteVerified = await _apiClient.verifyDeliveryOtp(tripId, otp);
      if (remoteVerified) return true;
    } catch (_) {}

    // 2. Fallback to local check
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index == -1) return false;
    final trip = _trips[index];
    if (trip.podOtp != null && trip.podOtp!.isNotEmpty) {
      return trip.podOtp == otp.trim();
    }
    return otp.trim().length >= 4;
  }

  @override
  Future<void> submitProofOfDelivery(
    String tripId, {
    required String otp,
    required String photoPath,
    required String signatureSvg,
  }) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = _trips[index];
      _trips[index] = old.copyWith(
        status: TripStatus.delivered,
        distanceDoneKm: old.distanceKm,
        podOtp: otp,
        podPhotoPath: photoPath,
        podSignatureSvg: signatureSvg,
      );
      await _saveToDisk();
      _notifyAll();

      // Dispatch to live backend
      unawaited(_apiClient.submitProofOfDelivery(
        tripId,
        otp: otp,
        photoPath: photoPath,
        signatureSvg: signatureSvg,
      ));
    }
  }

  @override
  Future<void> acceptTrip(String tripId) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: TripStatus.accepted);
      await _saveToDisk();
      _notifyAll();
      unawaited(_apiClient.acceptTrip(tripId));
    }
  }

  @override
  Future<void> startTrip(String tripId) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: TripStatus.running);
      await _saveToDisk();
      _notifyAll();
      unawaited(_apiClient.startTrip(tripId));
    }
  }

  @override
  Future<void> reportBreakdown(
    String tripId, {
    required double latitude,
    required double longitude,
    required String reason,
    String? remarks,
  }) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: TripStatus.breakdown);
      await _saveToDisk();
      _notifyAll();
      unawaited(_apiClient.reportBreakdown(
        tripId,
        latitude: latitude,
        longitude: longitude,
        reason: reason,
        remarks: remarks,
      ));
    }
  }

  @override
  Future<void> reportDeliveryFailed(String tripId, {String? remarks}) async {
    await _init();
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(status: TripStatus.failed);
      await _saveToDisk();
      _notifyAll();
      unawaited(_apiClient.reportDeliveryFailed(tripId, remarks: remarks));
    }
  }

  @override
  Future<Trip> createTrip({
    required String from,
    required String to,
    required String cargo,
    required double weightTons,
    required String driverId,
  }) async {
    await _init();
    final driver = _drivers.firstWhere((d) => d.id == driverId, orElse: () => _drivers.first);
    final truckPlate = driver.assignedTruckPlate.isNotEmpty ? driver.assignedTruckPlate : _trucks.first.plate;

    // Generate next TR-#### ID
    int maxId = 1025;
    for (final t in _trips) {
      if (t.id.startsWith('TR-')) {
        final numPart = int.tryParse(t.id.substring(3));
        if (numPart != null && numPart > maxId) {
          maxId = numPart;
        }
      }
    }
    final nextId = 'TR-${maxId + 1}';

    final newTrip = Trip(
      id: nextId,
      from: from,
      to: to,
      cargo: cargo,
      weightTons: weightTons,
      truckPlate: truckPlate,
      driverId: driverId,
      status: TripStatus.waiting,
      startedAt: DateTime.now(),
      distanceKm: 160.0,
      distanceDoneKm: 0.0,
      allowanceAmount: 1500,
      isPaid: false,
    );

    _trips.insert(0, newTrip);
    await _saveToDisk();
    _notifyAll();

    // Post to live backend asynchronously
    unawaited(_apiClient.createTrip(
      from: from,
      to: to,
      cargo: cargo,
      weightTons: weightTons,
      driverId: driverId,
      truckPlate: truckPlate,
    ));

    return newTrip;
  }

  @override
  Stream<List<Driver>> watchDrivers() async* {
    await _init();
    yield List.unmodifiable(_drivers);
    yield* _driversController.stream;
  }

  void addOrUpdateDriver(Driver driver) {
    final idx = _drivers.indexWhere((d) => d.id == driver.id || d.phone == driver.phone);
    if (idx != -1) {
      _drivers[idx] = driver;
    } else {
      _drivers.insert(0, driver);
    }
    _notifyAll();
  }

  @override
  Future<List<Driver>> getDrivers() async {
    await _init();
    return List.unmodifiable(_drivers);
  }

  @override
  Future<Driver?> getDriverById(String id) async {
    await _init();
    try {
      return _drivers.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Truck>> watchTrucks() async* {
    await _init();
    yield List.unmodifiable(_trucks);
    yield* _trucksController.stream;
  }

  @override
  Future<List<Truck>> getTrucks() async {
    await _init();
    return List.unmodifiable(_trucks);
  }

  @override
  Future<Truck?> getTruckByPlate(String plate) async {
    await _init();
    try {
      return _trucks.firstWhere((t) => t.plate == plate);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> getPlaces() async {
    await _init();
    return List.unmodifiable(_places);
  }

  @override
  Future<int> getRunningTripsCount() async {
    await _init();
    return _trips.where((t) => t.status == TripStatus.running).length;
  }

  @override
  Future<int> getFreeTrucksCount() async {
    await _init();
    return _trucks.where((t) => t.status == TruckStatus.available).length;
  }

  @override
  Future<int> getDeliveredThisMonthCount() async {
    await _init();
    return _trips.where((t) => t.status == TripStatus.delivered).length;
  }

  @override
  Future<List<String>> getNeedsAttentionList() async {
    await _init();
    final alerts = <String>[];
    for (final truck in _trucks) {
      if (truck.status == TruckStatus.inWorkshop) {
        alerts.add('${truck.plate} is currently in workshop');
      }
    }
    return alerts;
  }
}
