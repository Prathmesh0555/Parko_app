class BookingResponse {
  final int count;
  final List<Booking> bookings;

  BookingResponse({required this.count, required this.bookings});

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      count: json['count'],
      bookings: List<Booking>.from(
        json['bookings'].map((x) => Booking.fromJson(x)),
      ),
    );
  }
}

class Booking {
  final int id;
  final int slot;
  final String reqTimeStart;
  final String reqTimeEnd;
  final String status;
  final String? qrCode;
  final BookingUser user;
  final String? parkingName;

  Booking({
    required this.id,
    required this.slot,
    required this.reqTimeStart,
    required this.reqTimeEnd,
    required this.status,
    this.qrCode,
    required this.user,
    this.parkingName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      slot: json['slot'],
      reqTimeStart: json['req_time_start'],
      reqTimeEnd: json['req_time_end'],
      status: json['status'],
      qrCode: json['qr_code'],
      user: BookingUser.fromJson(json['user']),
      parkingName: json['parking_name'] ?? '',
    );
  }
}

class BookingUser {
  final int id;
  final String username;
  final String name;
  final String email;

  BookingUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
  });

  factory BookingUser.fromJson(Map<String, dynamic> json) {
    return BookingUser(
      id: json['id'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
    );
  }
}
