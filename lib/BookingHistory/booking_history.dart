import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../models/booking_model.dart';
import '../models/parking_models.dart';
import 'booking_card.dart';
import 'booking_drawer.dart';

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
    if (!AuthService.isLoggedIn) {
      setState(() {
        _errorMessage = 'Please log in to view your bookings';
        _isLoading = false;
      });
      return;
    }

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

  void _showBookingDetails(Booking booking) async {
    try {
      // Fetch additional details
      final slotId = booking.slot;
      final parkingSlot = await AuthService.fetchParkingSlot(slotId);
      final parkingAreaId = parkingSlot.parkingArea;
      final parkingArea = await AuthService.fetchParkingArea(parkingAreaId);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => BookingDrawer(
              booking: booking,
              parkingSlot: parkingSlot,
              parkingArea: parkingArea,
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return content directly without Scaffold to maintain navigation
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchBookings,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No booking history yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your past and upcoming bookings will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Bookings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your parking reservation history',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchBookings,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                return BookingCard(
                  booking: booking,
                  onTap: () => _showBookingDetails(booking),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
