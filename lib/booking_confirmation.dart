import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'main.dart';

class BookingConfirmationPage extends StatelessWidget {
  final String parkingSpotName;
  final String selectedDate;
  final String selectedSlot;
  final double totalAmount;
  final String paymentMethod;
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
    required this.totalAmount,
    required this.paymentMethod,
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
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              gapless: false,
              errorStateBuilder: (cxt, err) {
                return const Center(
                  child: Text(
                    'Unable to generate QR code',
                    textAlign: TextAlign.center,
                  ),
                );
              },
              embeddedImage: const AssetImage('assets/logoParko.jpg'),
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(40, 40),
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
        _buildDetailRow('Time Slot', bookingTime),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
      'time': bookingTime,
      'amount': totalAmount.toStringAsFixed(2),
      'transactionId': transactionId,
    });
  }
}