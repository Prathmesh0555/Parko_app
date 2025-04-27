import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'models/booking_model.dart';
import 'models/parking_models.dart'; // Import the new model

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({Key? key}) : super(key: key);

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  bool _isLoading = true;
  List<Booking> _bookings = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      setState(() => _isLoading = true);
      final bookingResponse = await AuthService.fetchMyBookings();
      setState(() {
        _bookings = bookingResponse.bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load booking history. Please try again.';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.blue;
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showBookingDetailModal(BuildContext context, Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BookingDetailModal(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _bookings.isEmpty
                  ? const Center(child: Text('No bookings found'))
                  : RefreshIndicator(
                      onRefresh: _fetchBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return InkWell(
                            onTap: () => _showBookingDetailModal(context, booking),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Booking #${booking.id}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(booking.status),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            booking.status.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Slot Number:', '${booking.slot}'),
                                    _buildInfoRow('Time:', '${booking.reqTimeStart} - ${booking.reqTimeEnd}'),
                                    if (booking.qrCode != null) ...[
                                      const SizedBox(height: 16),
                                      Center(
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Scan QR Code at entry',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Image.network(
                                              booking.qrCode!,
                                              height: 150,
                                              width: 150,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.qr_code, size: 150);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
class BookingDetailModal extends StatefulWidget {
  final Booking booking; 
  const BookingDetailModal({Key? key, required this.booking}) : super(key: key);
  @override
  State<BookingDetailModal> createState() => _BookingDetailModalState();
}

class _BookingDetailModalState extends State<BookingDetailModal> {
  bool _isLoading = true;
  ParkingSlot? _parkingSlot;
  ParkingArea? _parkingArea;
  String _errorMessage = '';

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.blue;
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchParkingDetails();
  }
  Future<void> _fetchParkingDetails() async {
    try {
      setState(() => _isLoading = true);      
      final slotId = widget.booking.slot;
      final parkingSlot = await AuthService.fetchParkingSlot(slotId);      
      final parkingAreaId = parkingSlot.parkingArea;
      final parkingArea = await AuthService.fetchParkingArea(parkingAreaId);
      setState(() {
        _parkingSlot = parkingSlot;
        _parkingArea = parkingArea;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load parking details. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(child: Text(_errorMessage))
                  : ListView(
                      controller: scrollController,
                      children: [
                        // Header section with drag indicator
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        
                        // Booking details card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Booking #${widget.booking.id}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(widget.booking.status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        widget.booking.status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow('Slot Number:', '${widget.booking.slot}'),
                                _buildDetailRow('Booking Time:', '${widget.booking.reqTimeStart} - ${widget.booking.reqTimeEnd}'),
                                _buildDetailRow('User:', widget.booking.user.name),
                                _buildDetailRow('Email:', widget.booking.user.email),
                              ],
                            ),
                          ),
                        ),
                        
                        // Parking slot details
                        if (_parkingSlot != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Parking Slot Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('Slot ID:', '${_parkingSlot!.id}'),
                                  _buildDetailRow('Available:', _parkingSlot!.available ? 'Yes' : 'No'),
                                  _buildDetailRow('Reserved:', _parkingSlot!.reserved ? 'Yes' : 'No'),
                                  if (_parkingSlot!.reservedForStart != null && _parkingSlot!.reservedForEnd != null)
                                    _buildDetailRow('Reserved Time:', '${_parkingSlot!.reservedForStart} - ${_parkingSlot!.reservedForEnd}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        // Parking area details
                        if (_parkingArea != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Parking Area Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    _parkingArea!.owner.imageUrl,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image_not_supported, size: 50),
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _parkingArea!.owner.parkingName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _parkingArea!.owner.address,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDetailRow('Hourly Rate:', '₹${_parkingArea!.owner.hourlyRate}'),
                                      _buildDetailRow('Daily Rate:', '₹${_parkingArea!.owner.dailyRate}'),
                                      _buildDetailRow('Monthly Rate:', '₹${_parkingArea!.owner.monthlyRate}'),
                                      _buildDetailRow('Opening Hours:', _parkingArea!.owner.openingHours),
                                      _buildDetailRow('Total Slots:', '${_parkingArea!.owner.totalSlots}'),
                                      _buildDetailRow('Available Slots:', '${_parkingArea!.availableSlots}'),
                                      _buildDetailRow('Rating:', '${_parkingArea!.owner.rating}'),
                                      if (_parkingArea!.owner.description.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Description',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(_parkingArea!.owner.description),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        if (widget.booking.qrCode != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'QR Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Text(
                                      'Scan this QR code at the parking entrance',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Image.network(
                                      widget.booking.qrCode!,
                                      height: 200,
                                      width: 200,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.qr_code, size: 200);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        // Close button
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
