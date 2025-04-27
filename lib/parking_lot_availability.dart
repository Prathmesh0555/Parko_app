import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_gateway.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'models/parking_models.dart';

class ParkingLotAvailabilityPage extends StatefulWidget {
  final String selectedDate;
  final String parkingSpotName;
  final String? initialSelectedSpot;
  final double fare;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int parkingAreaId; // Add this parameter

  const ParkingLotAvailabilityPage({
    Key? key,
    required this.selectedDate,
    required this.parkingSpotName,
    this.initialSelectedSpot,
    required this.fare,
    required this.startTime,
    required this.endTime,
    required this.parkingAreaId, // Initialize this parameter
  }) : super(key: key);

  @override
  State<ParkingLotAvailabilityPage> createState() =>
      _ParkingLotAvailabilityPageState();
}

class _ParkingLotAvailabilityPageState
    extends State<ParkingLotAvailabilityPage> {
  late List<ParkingSpot> spots = [];
  String? selectedSpot;
  bool isLoading = true;
  String errorMessage = '';
  int totalSlots = 0;
  int availableSlots = 0;
  int levels = 0;

  @override
  void initState() {
    super.initState();
    selectedSpot = widget.initialSelectedSpot;
    _fetchParkingSlots();
  }

  Future<void> _fetchParkingSlots() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await AuthService.protectedApiCall(() async {
        return await http.get(
          Uri.parse(
            '${AuthService.baseUrl}/reservation/parking-area/${widget.parkingAreaId}/slots/',
          ),
          headers: await AuthService.getAuthHeader(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract top-level data
        totalSlots = data['total_slots'] ?? 0;
        availableSlots =
            data['avaiilable_slots'] ?? 0; // Note: typo in API response
        levels = data['levels'] ?? 1;

        // Convert slots data
        final slotsData = data['slots'] as List;
        List<ParkingSpot> fetchedSpots = [];

        for (var slotData in slotsData) {
          final id = slotData['id'].toString();

          // UPDATED LOGIC: Only consider slots as available if reserved=false
          final isReserved =
              slotData['reserved'] ??
              true; // Default to true (occupied) if missing

          // Default to occupied if reserved is true
          ParkingAvailability availability =
              isReserved
                  ? ParkingAvailability.occupied
                  : ParkingAvailability.available;

          // If this is the initially selected spot, mark it as selected
          if (id == selectedSpot) {
            availability = ParkingAvailability.selected;
          }

          fetchedSpots.add(ParkingSpot(id, availability));
        }

        setState(() {
          spots = fetchedSpots;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Failed to load parking slots. Status: ${response.statusCode}';
          isLoading = false;
          _initializeFallbackSpots(); // Use fallback data in case of failure
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading parking slots: $e';
        isLoading = false;
        _initializeFallbackSpots(); // Use fallback data in case of failure
      });
    }
  }

  // Check if the selected time slot conflicts with a reserved time
  bool _hasTimeConflict(String reservedStartStr, String reservedEndStr) {
    // Convert reservation times to TimeOfDay
    final reservedStart = _parseTimeString(reservedStartStr);
    final reservedEnd = _parseTimeString(reservedEndStr);

    if (reservedStart == null || reservedEnd == null) {
      return false; // Can't determine conflict with invalid time
    }

    // Selected time from widget
    final selectedStart = widget.startTime;
    final selectedEnd = widget.endTime;

    // Time overlaps if:
    // 1. Selected start time is within reserved period
    // 2. Selected end time is within reserved period
    // 3. Selected period completely contains reserved period

    // Convert all times to minutes for easier comparison
    int reservedStartMinutes = reservedStart.hour * 60 + reservedStart.minute;
    int reservedEndMinutes = reservedEnd.hour * 60 + reservedEnd.minute;
    int selectedStartMinutes = selectedStart.hour * 60 + selectedStart.minute;
    int selectedEndMinutes = selectedEnd.hour * 60 + selectedEnd.minute;

    // Check for overlap
    return (selectedStartMinutes < reservedEndMinutes &&
        selectedEndMinutes > reservedStartMinutes);
  }

  // Parse time string like "10:00:00" to TimeOfDay
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
    return null;
  }

  // Fallback to randomly generated spots if API fails
  void _initializeFallbackSpots() {
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

      // Update the availability status
      for (var spot in spots) {
        if (spot.availability != ParkingAvailability.occupied) {
          spot.availability =
              spot.id == selectedSpot
                  ? ParkingAvailability.selected
                  : ParkingAvailability.available;
        }
      }
    });
  }

  void _resetSelection() {
    setState(() {
      selectedSpot = null;

      // Reset all non-occupied spots to available
      for (var spot in spots) {
        if (spot.availability != ParkingAvailability.occupied) {
          spot.availability = ParkingAvailability.available;
        }
      }
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
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Time: ${widget.startTime.format(context)} - ${widget.endTime.format(context)}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                if (!isLoading && errorMessage.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Available: $availableSlots out of $totalSlots slots',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (levels > 1)
                    Text(
                      'Levels: $levels',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                ],
                const Divider(height: 24),
              ],
            ),
          ),

          // Parking Lot Visualization with Loading State
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage.isNotEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load parking spots',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchParkingSlots,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Display all spots in a grid
                          _buildParkingSpotGrid(),
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
                    onPressed: isLoading ? null : _resetSelection,
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
                    onPressed:
                        isLoading || selectedSpot == null
                            ? null
                            : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PaymentGatewayPage(
                                        fare: widget.fare,
                                        parkingSpotName: widget.parkingSpotName,
                                        selectedDate: widget.selectedDate,
                                        selectedSlot: selectedSpot!,
                                        startTime: widget.startTime,
                                        endTime: widget.endTime,
                                        parkingAreaId:
                                            widget
                                                .parkingAreaId, // Pass the parking area ID
                                      ),
                                ),
                              );
                            },
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

  // Build a grid of all parking spots
  Widget _buildParkingSpotGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Parking Slots',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: spots.map((spot) => _buildParkingSpot(spot)).toList(),
        ),
      ],
    );
  }

  Widget _buildParkingSection(String section, int start, int end) {
    final sectionSpots =
        spots
            .where(
              (spot) =>
                  spot.id.startsWith(section) &&
                  int.parse(spot.id.substring(1)) >= start &&
                  int.parse(spot.id.substring(1)) <= end,
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section $section',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              sectionSpots.map((spot) => _buildParkingSpot(spot)).toList(),
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
      onTap:
          spot.availability == ParkingAvailability.occupied
              ? null
              : () => _toggleSpotSelection(spot.id),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
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

enum ParkingAvailability { available, selected, occupied }
