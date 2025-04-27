import 'package:flutter/material.dart';
import '../models/booking_model.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const BookingCard({Key? key, required this.booking, required this.onTap})
    : super(key: key);

  bool get isUpcoming {
    try {
      // Parse the end time from the booking format (assuming format: "DD/MM/YYYY HH:MM")
      final dateTimeParts = booking.reqTimeEnd.split(' ');
      if (dateTimeParts.length >= 2) {
        final datePart = dateTimeParts[0]; // DD/MM/YYYY
        final timePart = dateTimeParts[1]; // HH:MM

        final dateSplit = datePart.split('/');
        final timeSplit = timePart.split(':');

        if (dateSplit.length == 3 && timeSplit.length == 2) {
          final day = int.parse(dateSplit[0]);
          final month = int.parse(dateSplit[1]);
          final year = int.parse(dateSplit[2]);
          final hour = int.parse(timeSplit[0]);
          final minute = int.parse(timeSplit[1]);

          final bookingEndTime = DateTime(year, month, day, hour, minute);
          return bookingEndTime.isAfter(DateTime.now());
        }
      }
    } catch (e) {
      // If parsing fails, use status-based logic
      print('Error parsing booking time: $e');
    }

    // Fallback to status-based check if date parsing fails
    return booking.status.toLowerCase() != 'exit';
  }

  void _showQRCodeModal(BuildContext context) {
    if (booking.qrCode == null || booking.qrCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code available for this booking')),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Booking QR Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Slot ${booking.slot}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Image.network(
                    booking.qrCode!,
                    height: 200,
                    width: 200,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.qr_code_2,
                        size: 200,
                        color: Colors.deepPurple,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Show this QR code at the parking entrance',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slot ${booking.slot}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _StatusBadge(isUpcoming: isUpcoming),
                ],
              ),
              const SizedBox(height: 12),

              // Parking Spot Name (if available)
              if (booking.parkingName != null &&
                  booking.parkingName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_parking_rounded,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.parkingName!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.deepPurple,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${booking.reqTimeStart} - ${booking.reqTimeEnd}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (booking.user.name.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.user.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // QR Code Button (if QR code exists)
                  if (booking.qrCode != null && booking.qrCode!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showQRCodeModal(context),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text(
                        'View QR',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // View Details Button
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isUpcoming;

  const _StatusBadge({Key? key, required this.isUpcoming}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            isUpcoming
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isUpcoming ? 'UPCOMING' : 'COMPLETED',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isUpcoming ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}
