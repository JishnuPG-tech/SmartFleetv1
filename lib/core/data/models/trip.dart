enum TripStatus {
  waiting,
  accepted,
  running,
  breakdown,
  delivered,
  failed,
}

class Trip {
  static const double averageSpeedKmPerHour = 40.0; // Fixed commercial heavy vehicle speed on Kerala NH-66

  final String id; // Format TR-1025
  final String from;
  final String to;
  final String cargo;
  final double weightTons;
  final String truckPlate;
  final String driverId;
  final TripStatus status;
  final DateTime startedAt;
  final double distanceKm;
  final double distanceDoneKm;
  final int allowanceAmount; // Daily allowance (Bata) in ₹
  final bool isPaid; // Payout settlement status
  final String? podOtp;
  final String? podPhotoPath;
  final String? podSignatureSvg;

  const Trip({
    required this.id,
    required this.from,
    required this.to,
    required this.cargo,
    required this.weightTons,
    required this.truckPlate,
    required this.driverId,
    required this.status,
    required this.startedAt,
    required this.distanceKm,
    required this.distanceDoneKm,
    required this.allowanceAmount,
    this.isPaid = false,
    this.podOtp,
    this.podPhotoPath,
    this.podSignatureSvg,
  });

  // Derived progress percentage strictly between 0.0 and 1.0
  double get progressPercent {
    if (distanceKm <= 0) return 0.0;
    return (distanceDoneKm / distanceKm).clamp(0.0, 1.0);
  }

  // Derived remaining distance
  double get remainingKm {
    final rem = distanceKm - distanceDoneKm;
    return rem < 0 ? 0.0 : rem;
  }

  // Derived remaining duration in hours and minutes
  int get remainingHours {
    if (status == TripStatus.delivered) return 0;
    return (remainingKm / averageSpeedKmPerHour).floor();
  }

  int get remainingMinutes {
    if (status == TripStatus.delivered) return 0;
    final totalHours = remainingKm / averageSpeedKmPerHour;
    final fractionalHour = totalHours - totalHours.floor();
    return (fractionalHour * 60).round();
  }

  // Derived ETA arrival time
  DateTime get estimatedArrival {
    final totalMinutes = (remainingKm / averageSpeedKmPerHour * 60).round();
    return DateTime.now().add(Duration(minutes: totalMinutes));
  }

  Trip copyWith({
    TripStatus? status,
    double? distanceDoneKm,
    bool? isPaid,
    String? podOtp,
    String? podPhotoPath,
    String? podSignatureSvg,
  }) {
    return Trip(
      id: id,
      from: from,
      to: to,
      cargo: cargo,
      weightTons: weightTons,
      truckPlate: truckPlate,
      driverId: driverId,
      status: status ?? this.status,
      startedAt: startedAt,
      distanceKm: distanceKm,
      distanceDoneKm: distanceDoneKm ?? this.distanceDoneKm,
      allowanceAmount: allowanceAmount,
      isPaid: isPaid ?? this.isPaid,
      podOtp: podOtp ?? this.podOtp,
      podPhotoPath: podPhotoPath ?? this.podPhotoPath,
      podSignatureSvg: podSignatureSvg ?? this.podSignatureSvg,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'cargo': cargo,
    'weightTons': weightTons,
    'truckPlate': truckPlate,
    'driverId': driverId,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'distanceKm': distanceKm,
    'distanceDoneKm': distanceDoneKm,
    'allowanceAmount': allowanceAmount,
    'isPaid': isPaid,
    'podOtp': podOtp,
    'podPhotoPath': podPhotoPath,
    'podSignatureSvg': podSignatureSvg,
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    cargo: json['cargo'] as String,
    weightTons: (json['weightTons'] as num).toDouble(),
    truckPlate: json['truckPlate'] as String,
    driverId: json['driverId'] as String,
    status: TripStatus.values.byName(json['status'] as String),
    startedAt: DateTime.parse(json['startedAt'] as String),
    distanceKm: (json['distanceKm'] as num).toDouble(),
    distanceDoneKm: (json['distanceDoneKm'] as num).toDouble(),
    allowanceAmount: json['allowanceAmount'] as int,
    isPaid: json['isPaid'] as bool? ?? false,
    podOtp: json['podOtp'] as String?,
    podPhotoPath: json['podPhotoPath'] as String?,
    podSignatureSvg: json['podSignatureSvg'] as String?,
  );
}
