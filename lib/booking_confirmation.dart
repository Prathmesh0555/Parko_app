import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'main.dart';

class BookingConfirmationPage extends StatelessWidget {
  final String parkingSpotName;
  final String selectedDate;
  final String selectedSlot;
  final String startTimeStr;  // Add this parameter
  final String endTimeStr;    // Add this parameter
  final String bookingId;     // Add this parameter
  final double totalAmount;
  final String paymentMethod;
  final String qrCode;        // Add this parameter
  final String transactionId;
  final String bookingTime;

  // Style constants
  static const primaryColor = Colors.deepPurple;
  static const successColor = Colors.green;
  static const paddingLarge = 32.0;
  static const paddingMedium = 16.0;
  static const paddingSmall = 8.0;

  const BookingConfirmationPage({
    super.key,
    required this.parkingSpotName,
    required this.selectedDate,
    required this.selectedSlot,
    required this.startTimeStr,  // Add this parameter
    required this.endTimeStr,    // Add this parameter
    required this.bookingId,     // Add this parameter
    required this.totalAmount,
    required this.paymentMethod,
    required this.qrCode,        // Add this parameter
    required this.transactionId,
    required this.bookingTime,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = _generateQrData();

    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context, qrData),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Booking Confirmed',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String qrData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: successColor,
            size: 80,
          ),
          const SizedBox(height: paddingMedium),
          const Text(
            'Booking Confirmed!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: paddingSmall),
          Text(
            'Your parking spot is reserved',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: paddingLarge),
          _buildQrCard(qrData),
          const SizedBox(height: paddingLarge),
          _buildBookingDetails(),
          const SizedBox(height: paddingLarge),
          _buildDoneButton(context),
        ],
      ),
    );
  }

  Widget _buildQrCard(String qrData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Display the image from URL
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  qrCode,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load QR code',
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: paddingMedium),
            const Text(
              'Show this QR code at parking',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Booking Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: paddingMedium),
        _buildDetailRow('Parking Spot', parkingSpotName),
        _buildDetailRow('Date', selectedDate),
        _buildDetailRow('Start Time', startTimeStr),
        _buildDetailRow('End Time', endTimeStr),
        _buildDetailRow('Booking ID', bookingId),
        _buildDetailRow('Parking Slot', selectedSlot),
        _buildDetailRow('Payment Method', paymentMethod),
        _buildDetailRow('Transaction ID', transactionId),
        _buildDetailRow('Amount', '₹${totalAmount.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: paddingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed width for label to ensure alignment
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const ParkoHomePage()),
                (route) => false,
          );
        },
        child: const Text(
          'Done',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const ParkoHomePage()),
                (route) => false,
          );
        }
        // No action for other tabs as we've removed history
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }

  String _generateQrData() {
    return jsonEncode({
      'parkingSpot': parkingSpotName,
      'date': selectedDate,
      'slot': selectedSlot,
      'startTime': startTimeStr,
      'endTime': endTimeStr,
      'bookingId': bookingId,
      'time': bookingTime,
      'amount': totalAmount.toStringAsFixed(2),
      'transactionId': transactionId,
    });
  }
}