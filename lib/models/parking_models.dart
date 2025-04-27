class ParkingSlot {
  final int id;
  final int parkingArea;
  final bool available;
  final bool reserved;
  final String? reservedForStart;
  final String? reservedForEnd;

  ParkingSlot({
    required this.id,
    required this.parkingArea,
    required this.available,
    required this.reserved,
    this.reservedForStart,
    this.reservedForEnd,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      id: json['id'],
      parkingArea: json['parking_area'],
      available: json['available'],
      reserved: json['reserved'],
      reservedForStart: json['reserved_for_start'],
      reservedForEnd: json['reserved_for_end'],
    );
  }
}

class ParkingAreaOwner {
  final int id;
  final ParkingAreaUser user;
  final String parkingName;
  final int totalSlots;
  final double hourlyRate;
  final double dailyRate;
  final double monthlyRate;
  final String openingHours;
  final String description;
  final int levels;
  final String address;
  final double rating;
  final String imageUrl;
  final String availableTypes;

  ParkingAreaOwner({
    required this.id,
    required this.user,
    required this.parkingName,
    required this.totalSlots,
    required this.hourlyRate,
    required this.dailyRate,
    required this.monthlyRate,
    required this.openingHours,
    required this.description,
    required this.levels,
    required this.address,
    required this.rating,
    required this.imageUrl,
    required this.availableTypes,
  });

  factory ParkingAreaOwner.fromJson(Map<String, dynamic> json) {
    return ParkingAreaOwner(
      id: json['id'],
      user: ParkingAreaUser.fromJson(json['user']),
      parkingName: json['parking_name'],
      totalSlots: json['total_slots'],
      hourlyRate: json['hourlyRate'].toDouble(),
      dailyRate: json['dailyRate'].toDouble(),
      monthlyRate: json['monthlyRate'].toDouble(),
      openingHours: json['openingHours'],
      description: json['description'],
      levels: json['levels'],
      address: json['address'],
      rating: json['rating'].toDouble(),
      imageUrl: json['image_url'],
      availableTypes: json['availableTypes'] ?? '',
    );
  }
}

class ParkingAreaUser {
  final int id;
  final String username;
  final String name;
  final String email;

  ParkingAreaUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
  });

  factory ParkingAreaUser.fromJson(Map<String, dynamic> json) {
    return ParkingAreaUser(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
    );
  }
}

class ParkingArea {
  final int id;
  final double latitude;
  final double longitude;
  final ParkingAreaOwner owner;
  final int availableSlots;

  ParkingArea({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.owner,
    required this.availableSlots,
  });

  factory ParkingArea.fromJson(Map<String, dynamic> json) {
    return ParkingArea(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      owner: ParkingAreaOwner.fromJson(json['owner']),
      availableSlots: json['available_slots'],
    );
  }
}