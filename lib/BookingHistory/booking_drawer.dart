import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/parking_models.dart';

class BookingDrawer extends StatelessWidget {
  final Booking booking;
  final ParkingSlot? parkingSlot;
  final ParkingArea? parkingArea;

  const BookingDrawer({
    Key? key,
    required this.booking,
    this.parkingSlot,
    this.parkingArea,
  }) : super(key: key);

  bool get isUpcoming {
    try {
      // Parse the end time
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
      print('Error parsing booking time: $e');
    }

    return booking.status.toLowerCase() != 'exit';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle at top
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                ),
              ),

              // Header with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Booking #${booking.id}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 24),

              // Basic booking info section
              _buildSectionTitle('Booking Information'),
              _buildInfoCard([
                _buildInfoRow('Slot Number', '${booking.slot}'),
                _buildInfoRow('Start Time', booking.reqTimeStart),
                _buildInfoRow('End Time', booking.reqTimeEnd),
                _buildInfoRow('User', booking.user.name),
                _buildInfoRow('Email', booking.user.email),
                if (booking.status.isNotEmpty)
                  _buildInfoRow('Status', booking.status),
              ]),
              const SizedBox(height: 20),

              // Parking Slot info section
              if (parkingSlot != null) ...[
                _buildSectionTitle('Parking Slot Details'),
                _buildInfoCard([
                  _buildInfoRow('Slot ID', '${parkingSlot!.id}'),
                  _buildInfoRow(
                    'Available',
                    parkingSlot!.available ? 'Yes' : 'No',
                  ),
                  _buildInfoRow(
                    'Reserved',
                    parkingSlot!.reserved ? 'Yes' : 'No',
                  ),
                  if (parkingSlot!.reservedForStart != null &&
                      parkingSlot!.reservedForEnd != null)
                    _buildInfoRow(
                      'Reserved Time',
                      '${parkingSlot!.reservedForStart} - ${parkingSlot!.reservedForEnd}',
                    ),
                ]),
                const SizedBox(height: 20),
              ],

              // Parking Area info section
              if (parkingArea != null) ...[
                _buildSectionTitle('Parking Area Details'),
                if (parkingArea!.owner.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      parkingArea!.owner.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  parkingArea!.owner.parkingName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  parkingArea!.owner.address,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow(
                    'Hourly Rate',
                    '₹${parkingArea!.owner.hourlyRate}',
                  ),
                  _buildInfoRow(
                    'Daily Rate',
                    '₹${parkingArea!.owner.dailyRate}',
                  ),
                  _buildInfoRow(
                    'Monthly Rate',
                    '₹${parkingArea!.owner.monthlyRate}',
                  ),
                  _buildInfoRow(
                    'Opening Hours',
                    parkingArea!.owner.openingHours,
                  ),
                  _buildInfoRow(
                    'Total Slots',
                    '${parkingArea!.owner.totalSlots}',
                  ),
                  _buildInfoRow(
                    'Available Slots',
                    '${parkingArea!.availableSlots}',
                  ),
                  _buildInfoRow('Rating', '${parkingArea!.owner.rating}'),
                ]),
                const SizedBox(height: 20),
              ],

              // QR Code Section
              if (booking.qrCode != null && booking.qrCode!.isNotEmpty) ...[
                _buildSectionTitle('QR Code'),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Scan this code at the parking entrance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          booking.qrCode!,
                          height: 200,
                          width: 200,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              width: 200,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.qr_code_2,
                                size: 100,
                                color: Colors.deepPurple,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
