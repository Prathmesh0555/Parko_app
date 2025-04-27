import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_gateway.dart';
import 'dart:math';

class ParkingLotAvailabilityPage extends StatefulWidget {
  final String selectedDate;
  final String parkingSpotName;
  final String? initialSelectedSpot;
  final double fare;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const ParkingLotAvailabilityPage({
    Key? key,
    required this.selectedDate,
    required this.parkingSpotName,
    this.initialSelectedSpot,
    required this.fare,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<ParkingLotAvailabilityPage> createState() => _ParkingLotAvailabilityPageState();
}

class _ParkingLotAvailabilityPageState extends State<ParkingLotAvailabilityPage> {
  late List<ParkingSpot> spots;
  String? selectedSpot;

  @override
  void initState() {
    super.initState();
    selectedSpot = widget.initialSelectedSpot;
    _initializeSpots();
  }

  void _initializeSpots() {
    final random = Random();
    spots = [
      ...List.generate(11, (i) {
        final spotId = 'A${i + 1}';
        return ParkingSpot(
          spotId,
          spotId == selectedSpot
              ? ParkingAvailability.selected
              : random.nextDouble() < 0.6
              ? ParkingAvailability.available
              : ParkingAvailability.occupied,
        );
      }),
      ...List.generate(9, (i) {
        final spotId = 'B${i + 16}';
        return ParkingSpot(
          spotId,
          spotId == selectedSpot
              ? ParkingAvailability.selected
              : random.nextDouble() < 0.6
              ? ParkingAvailability.available
              : ParkingAvailability.occupied,
        );
      }),
      ...List.generate(9, (i) {
        final spotId = 'C${i + 29}';
        return ParkingSpot(
          spotId,
          spotId == selectedSpot
              ? ParkingAvailability.selected
              : random.nextDouble() < 0.6
              ? ParkingAvailability.available
              : ParkingAvailability.occupied,
        );
      }),
    ];
  }

  void _toggleSpotSelection(String spotId) {
    setState(() {
      if (selectedSpot == spotId) {
        selectedSpot = null;
      } else {
        selectedSpot = spotId;
      }
      _initializeSpots();
    });
  }

  void _resetSelection() {
    setState(() {
      selectedSpot = null;
      _initializeSpots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.parkingSpotName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Information
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date: ${widget.selectedDate}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Time: ${widget.startTime.format(context)} - ${widget.endTime.format(context)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const Divider(height: 24),
              ],
            ),
          ),

          // Parking Lot Visualization
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Section A (1-11)
                  _buildParkingSection('A', 1, 11),
                  const SizedBox(height: 24),

                  // Section B (16-24)
                  _buildParkingSection('B', 16, 24),
                  const SizedBox(height: 24),

                  // Section C (29-37)
                  _buildParkingSection('C', 29, 37),
                  const SizedBox(height: 24),

                  // Legend
                  _buildLegend(),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedSpot != null
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentGatewayPage(
                            fare: widget.fare,
                            parkingSpotName: widget.parkingSpotName,
                            selectedDate: widget.selectedDate,
                            selectedSlot: selectedSpot!,
                            startTime: widget.startTime,
                            endTime: widget.endTime,
                          ),
                        ),
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Book Selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingSection(String section, int start, int end) {
    final sectionSpots = spots.where((spot) =>
    spot.id.startsWith(section) &&
        int.parse(spot.id.substring(1)) >= start &&
        int.parse(spot.id.substring(1)) <= end).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section $section',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sectionSpots.map((spot) => _buildParkingSpot(spot)).toList(),
        ),
      ],
    );
  }

  Widget _buildParkingSpot(ParkingSpot spot) {
    IconData icon;
    Color color;
    Color bgColor;

    switch (spot.availability) {
      case ParkingAvailability.available:
        icon = Icons.directions_car;
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
        break;
      case ParkingAvailability.selected:
        icon = Icons.local_parking;
        color = Colors.blue;
        bgColor = Colors.blue.withOpacity(0.1);
        break;
      case ParkingAvailability.occupied:
        icon = Icons.block;
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
        break;
    }

    return GestureDetector(
      onTap: spot.availability == ParkingAvailability.occupied
          ? null
          : () => _toggleSpotSelection(spot.id),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              spot.id,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Available', Icons.directions_car, Colors.green),
        _buildLegendItem('Selected', Icons.local_parking, Colors.blue),
        _buildLegendItem('Occupied', Icons.block, Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}

class ParkingSpot {
  final String id;
  ParkingAvailability availability;

  ParkingSpot(this.id, this.availability);
}

enum ParkingAvailability {
  available,
  selected,
  occupied,
}