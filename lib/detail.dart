import 'package:flutter/material.dart';
import 'parking_lot_availability.dart';

class ParkingDetailPage extends StatefulWidget {
  final Map<String, dynamic> parkingSpot;

  const ParkingDetailPage({Key? key, required this.parkingSpot}) : super(key: key);

  @override
  _ParkingDetailPageState createState() => _ParkingDetailPageState();
}

class _ParkingDetailPageState extends State<ParkingDetailPage> {
  int rating = 0;
  final TextEditingController reviewController = TextEditingController();
  final List<Map<String, dynamic>> reviews = [
    {
      'name': 'John Doe',
      'rating': 4.5,
      'date': 'March 15, 2024',
      'comment': 'Excellent parking facility with great security measures.',
      'initials': 'JD',
    },
    {
      'name': 'Jane Smith',
      'rating': 5.0,
      'date': 'April 2, 2024',
      'comment': 'Convenient location and clean parking spaces.',
      'initials': 'JS',
    },
    {
      'name': 'Alex Johnson',
      'rating': 4.0,
      'date': 'April 10, 2024',
      'comment': 'Good value for money. The app made booking super easy.',
      'initials': 'AJ',
    },
  ];

  // Reservation state variables
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _totalFare = 0.0;
  String? selectedSlot;

  void _handleSlotSelected(String? slot) {
    if (slot != null) {
      setState(() {
        selectedSlot = slot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spot $slot selected successfully!')),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _calculateFare();
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        _calculateFare();
      });
    }
  }

  Future<void> _selectEndTime() async {
    TimeOfDay initialTime;

    if (_startTime == null) {
      final now = TimeOfDay.now();
      initialTime = TimeOfDay(
        hour: (now.hour + 2) % 24,
        minute: now.minute,
      );
    } else {
      initialTime = TimeOfDay(
        hour: (_startTime!.hour + 2) % 24,
        minute: _startTime!.minute,
      );
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? initialTime,
    );

    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
        _calculateFare();
      });
    }
  }

  void _calculateFare() {
    if (_startTime != null && _endTime != null) {
      if (_endTime!.hour < _startTime!.hour ||
          (_endTime!.hour == _startTime!.hour && _endTime!.minute <= _startTime!.minute)) {
        final duration = ((_endTime!.hour + 24) - _startTime!.hour) +
            (_endTime!.minute - _startTime!.minute) / 60;
        setState(() {
          _totalFare = (duration * 100).roundToDouble();
        });
      } else {
        final duration = (_endTime!.hour - _startTime!.hour) +
            (_endTime!.minute - _startTime!.minute) / 60;
        setState(() {
          _totalFare = (duration * 100).roundToDouble();
        });
      }
    } else {
      setState(() {
        _totalFare = 0.0;
      });
    }
  }

  void _navigateToSlotSelection() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time first')),
      );
      return;
    }

    if (_endTime!.hour < _startTime!.hour ||
        (_endTime!.hour == _startTime!.hour && _endTime!.minute <= _startTime!.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParkingLotAvailabilityPage(
          selectedDate: '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          parkingSpotName: widget.parkingSpot['parking_user']['parking_name'],
          initialSelectedSpot: selectedSlot,
          fare: _totalFare,
          startTime: _startTime!,
          endTime: _endTime!,
        ),
      ),
    ).then((selectedSpot) {
      if (selectedSpot != null && selectedSpot is String) {
        _handleSlotSelected(selectedSpot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final parkingUser = widget.parkingSpot['parking_user'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/logoParko.jpg'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              parkingUser['parking_name'],
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),

      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parking Spot Image
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(parkingUser['image_url']),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Basic Information Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parkingUser['parking_name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      Text(
                        ' ${parkingUser['rating']} (${widget.parkingSpot['available_slots']} slots)',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    parkingUser['address'] ?? 'No address provided',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCard(
                        icon: Icons.access_time,
                        title: 'Opening Hours',
                        value: parkingUser['openingHours'] ?? 'N/A',
                      ),
                      _buildInfoCard(
                        icon: Icons.local_parking,
                        title: 'Vehicle Types',
                        value: parkingUser['availableTypes'] ?? 'N/A',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Description Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    parkingUser['description'] ?? 'No description provided.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

// Available Types Section
                  const Text(
                    'Available Types',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (parkingUser['availableTypes']?.toString().split(',') ?? [])
                        .map<Widget>((type) => Chip( // Explicit type casting here
                      label: Text(type.trim()),
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                      labelStyle: const TextStyle(color: Colors.deepPurple),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Pricing Section
                  const Text(
                    'Pricing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Hourly Rate'),
                          ),
                          Text('₹${parkingUser['hourlyRate'] ?? 'N/A'}'),
                        ],
                      ),
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Daily Rate'),
                          ),
                          Text('₹${parkingUser['dailyRate'] ?? 'N/A'}'),
                        ],
                      ),
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Monthly Rate'),
                          ),
                          Text('₹${parkingUser['monthlyRate'] ?? 'N/A'}'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Reserve Your Spot Section
            Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reserve Your Spot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date Selection
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Selection Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start time',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectStartTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _startTime != null
                                        ? _startTime!.format(context)
                                        : 'Select time',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End time',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectEndTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _endTime != null
                                        ? _endTime!.format(context)
                                        : 'Select time',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Duration and Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startTime != null && _endTime != null
                              ? 'Duration: ${_endTime!.hour - _startTime!.hour} hours'
                              : 'Duration: --',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _totalFare > 0
                              ? 'Total: ₹$_totalFare'
                              : 'Total: ₹--',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple[400],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Choose Slot Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _navigateToSlotSelection,
                        child: const Text(
                          'Choose Slot',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Free cancellation up to 24h before arrival',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contact Information Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactRow(Icons.phone, parkingUser['phone'] ?? 'N/A'),
                      _buildContactRow(Icons.email, parkingUser['email'] ?? 'N/A'),
                      _buildContactRow(Icons.language, parkingUser['website'] ?? 'N/A'),
                      _buildContactRow(Icons.business, parkingUser['company'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            ),

            // Reviews Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Write Review Box
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Write a review',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    rating = index + 1;
                                  });
                                },
                                child: Icon(
                                  index < rating ? Icons.star : Icons.star_border,
                                  size: 32,
                                  color: Colors.amber,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: reviewController,
                            decoration: const InputDecoration(
                              hintText: 'Share your experience...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                if (reviewController.text.isNotEmpty && rating > 0) {
                                  setState(() {
                                    reviews.insert(0, {
                                      'name': 'You',
                                      'rating': rating.toDouble(),
                                      'date': 'Just now',
                                      'comment': reviewController.text,
                                      'initials': 'YO',
                                    });
                                    reviewController.clear();
                                    rating = 0;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'Submit Review',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Existing Reviews
                  const Text(
                    'Customer Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: reviews.map((review) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.deepPurple,
                                      child: Text(
                                        review['initials'],
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${review['rating']} • ${review['date']}',
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  review['comment'],
                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'History',
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
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}