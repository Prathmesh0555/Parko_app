import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'detail.dart';
import 'booking_history.dart';
import 'login_screen.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  runApp(const ParkoApp());
}

class ParkoApp extends StatelessWidget {
  const ParkoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parko',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Roboto',
      ),
      home: const ParkoHomePage(),
    );
  }
}

class ParkoHomePage extends StatefulWidget {
  const ParkoHomePage({super.key});

  @override
  State<ParkoHomePage> createState() => _ParkoHomePageState();
}

class _ParkoHomePageState extends State<ParkoHomePage> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _locationError = false;
  Position? _userPosition;
  List<ParkingSpot> _parkingSpots = [];
  List<ParkingSpot> _allParkingSpots = [];
  int _displayLimit = 3;
  String _locationName = "Fetching location...";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeLocationAndFetchParkingSpots();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _parkingSpots = _allParkingSpots
          .where((spot) => spot.parkingUser.parkingName
          .toLowerCase()
          .contains(query))
          .take(_displayLimit)
          .toList();
    });
  }

  Future<void> _initializeLocationAndFetchParkingSpots() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      _userPosition = await Geolocator.getCurrentPosition();
      await _reverseGeocodeLocation();
      await _fetchNearbyParkingSpots();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationError = true;
        _locationName = "Nagari Niwara...";
        _allParkingSpots = _getDummyParkingSpots();
        _parkingSpots = _allParkingSpots.take(_displayLimit).toList();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reverseGeocodeLocation() async {
    try {
      if (_userPosition != null) {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
          _userPosition!.latitude,
          _userPosition!.longitude,
        );
        if (placemarks.isNotEmpty) {
          geo.Placemark place = placemarks.first;
          setState(() {
            _locationName =
                "${place.locality ?? ''} ${place.subLocality ?? ''}".trim();
            if (_locationName.isEmpty) {
              _locationName = "Current Location";
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      setState(() => _locationName = "Current Location");
    }
  }

  Future<void> _fetchNearbyParkingSpots() async {
    if (_userPosition == null) return;
    try {
      print('Fetching parking spots...');
      final response = await AuthService.protectedApiCall(() async {
        return await http.get(
          Uri.parse(
            '${AuthService.baseUrl}/reservation/parking-area/nearby/?user-lat=${_userPosition!.latitude}&user-long=${_userPosition!.longitude}',
          ),
          headers: {
            ...await AuthService.getAuthHeader(),
            'ngrok-skip-browser-warning': 'true'
          },
        );
      });

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('API decoded data length: ${data.length}');
        
        if (data.isNotEmpty) {
          try {
            // Get dummy data to fill in missing fields
            final dummySpots = _getDummyParkingSpots();
            
            // Create the list outside setState to debug
            final spots = data.map((json) {
              try {
                return ParkingSpot.fromJson(json, dummySpots);
              } catch (e) {
                print('Error parsing individual spot: $e');
                // Find a matching dummy spot if possible
                final dummySpot = _findMatchingDummySpot(json, dummySpots);
                if (dummySpot != null) {
                  return dummySpot;
                }
                // If no match found, rethrow to use all dummy data
                throw e;
              }
            }).toList();
            
            print('Parsed parking spots count: ${spots.length}');
            
            // Check the first spot if available
            if (spots.isNotEmpty) {
              print('First spot name: ${spots[0].parkingUser.parkingName}');
            }
            
            setState(() {
              _allParkingSpots = spots;
              _parkingSpots = _allParkingSpots.take(_displayLimit).toList();
              print('State updated with ${_parkingSpots.length} spots out of ${_allParkingSpots.length} total');
            });
          } catch (e) {
            print('Error parsing API data: $e');
            setState(() {
              _allParkingSpots = _getDummyParkingSpots();
              _parkingSpots = _allParkingSpots.take(_displayLimit).toList();
            });
          }
        } else {
          print('API returned empty data array');
          setState(() {
            _allParkingSpots = _getDummyParkingSpots();
            _parkingSpots = _allParkingSpots.take(_displayLimit).toList();
          });
        }
      } else {
        print('API error status code: ${response.statusCode}');
        throw Exception('Failed to load parking spots: ${response.statusCode}');
      }
    } catch (e) {
      print('API exception caught: $e');
      setState(() {
        _allParkingSpots = _getDummyParkingSpots();
        _parkingSpots = _allParkingSpots.take(_displayLimit).toList();
      });
    }
    
    // This print statement runs too early - it doesn't give setState time to complete
    // Move it after a brief delay to accurately check state
    Future.delayed(const Duration(milliseconds: 100), () {
      print('Delayed check - API resp: ${_parkingSpots.isNotEmpty ? _parkingSpots[0].parkingUser.parkingName : "No spots"}');
    });
  }

  // Find a matching dummy spot based on id or name
  ParkingSpot? _findMatchingDummySpot(Map<String, dynamic> apiSpot, List<ParkingSpot> dummySpots) {
    // Try to match by ID first
    if (apiSpot.containsKey('id')) {
      final id = apiSpot['id'];
      final matchById = dummySpots.where((spot) => spot.id == id).toList();
      if (matchById.isNotEmpty) return matchById.first;
    }
    
    // Try to match by parking name if available
    if (apiSpot.containsKey('parking_user') && 
        apiSpot['parking_user'] is Map<String, dynamic> &&
        apiSpot['parking_user'].containsKey('parking_name')) {
      final name = apiSpot['parking_user']['parking_name'];
      final matchByName = dummySpots.where(
        (spot) => spot.parkingUser.parkingName.toLowerCase().contains(
          name.toString().toLowerCase()
        )
      ).toList();
      if (matchByName.isNotEmpty) return matchByName.first;
    }
    
    return null;
  }

  List<ParkingSpot> _getDummyParkingSpots() {
    return [
      ParkingSpot(
        id: 1,
        latitude: 19.0760,
        longitude: 72.8777,
        availableSlots: 92,
        distance: 2.5,
        parkingUser: ParkingUser(
          id: 1,
          name: "John Doe",
          phone: "9876543210",
          email: "john@example.com",
          parkingName: "Trios Fashion Mall Parking",
          address: "Hill Road, Bandra West, Mumbai, Maharashtra 400050",
          hourlyRate: 50,
          openingHours: "24/7",
          dailyRate: 500,
          monthlyRate: 5000,
          rating: 4.2,
          imageUrl:
          "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          availableTypes: "Compact,SUV,Bike",
        ),
      ),
      ParkingSpot(
        id: 2,
        latitude: 19.0770,
        longitude: 72.8787,
        availableSlots: 30,
        distance: 3.5,
        parkingUser: ParkingUser(
          id: 2,
          name: "Jane Smith",
          phone: "9876543211",
          email: "jane@example.com",
          parkingName: "Linking Road Parking",
          address: "Linking Road, Bandra West, Mumbai, Maharashtra 400050",
          hourlyRate: 60,
          openingHours: "9am-9pm",
          dailyRate: 600,
          monthlyRate: 6000,
          rating: 4.5,
          imageUrl:
          "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          availableTypes: "Compact,SUV",
        ),
      ),
      ParkingSpot(
        id: 3,
        latitude: 19.0780,
        longitude: 72.8797,
        availableSlots: 50,
        distance: 4.5,
        parkingUser: ParkingUser(
          id: 3,
          name: "David Johnson",
          phone: "9876543212",
          email: "david@example.com",
          parkingName: "Hill Road Parking",
          address: "Hill Road, Bandra West, Mumbai, Maharashtra 400050",
          hourlyRate: 70,
          openingHours: "10am-10pm",
          dailyRate: 700,
          monthlyRate: 7000,
          rating: 4.8,
          imageUrl:
          "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          availableTypes: "SUV",
        ),
      ),
      ParkingSpot(
        id: 4,
        latitude: 19.0790,
        longitude: 72.8807,
        availableSlots: 60,
        distance: 5.5,
        parkingUser: ParkingUser(
          id: 4,
          name: "Sarah Williams",
          phone: "9876543213",
          email: "sarah@example.com",
          parkingName: "Turner Road Parking",
          address: "Turner Road, Bandra West, Mumbai, Maharashtra 400050",
          hourlyRate: 80,
          openingHours: "11am-11pm",
          dailyRate: 800,
          monthlyRate: 8000,
          rating: 4.9,
          imageUrl:
          "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          availableTypes: "Compact",
        ),
      ),
      ParkingSpot(
        id: 5,
        latitude: 19.0800,
        longitude: 72.8817,
        availableSlots: 70,
        distance: 6.5,
        parkingUser: ParkingUser(
          id: 5,
          name: "Michael Brown",
          phone: "9876543214",
          email: "michael@example.com",
          parkingName: "Waterfield Road Parking",
          address: "Waterfield Road, Bandra West, Mumbai, Maharashtra 400050",
          hourlyRate: 90,
          openingHours: "12pm-12am",
          dailyRate: 900,
          monthlyRate: 9000,
          rating: 4.7,
          imageUrl:
          "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          availableTypes: "SUV,Bike",
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
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
            const Text(
              'Parko',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: AuthService.isLoggedIn
                ? PopupMenuButton(
              icon: const Icon(Icons.person, color: Colors.deepPurple),
              onSelected: (value) {
                if (value == 'logout') {
                  AuthService.logout();
                  setState(() {});
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            )
                : ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginScreen()),
                ).then((_) => setState(() {}));
              },
              style: ElevatedButton.styleFrom(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.login,
                  size: 20, color: Colors.deepPurple),
              label: const Text(
                'Login',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Section
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: _locationError
                      ? const AssetImage('assets/map.jpeg')
                      : const AssetImage('assets/map.jpeg')
                  as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.cyan,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _locationName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Let's find the best\nParking Space",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search),
                            hintText: 'Search for parking spots...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Parking Spots Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby Parking Spots',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'The best parking space near you',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ..._parkingSpots
                .map((spot) => ParkingSpotCard(spot: spot))
                .toList(),
            if (_allParkingSpots.length > _displayLimit)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _displayLimit += 3;
                        _parkingSpots = _allParkingSpots
                            .where((spot) => _searchController.text.isEmpty || 
                                  spot.parkingUser.parkingName
                                      .toLowerCase()
                                      .contains(_searchController.text.toLowerCase()))
                            .take(_displayLimit)
                            .toList();
                        
                        print('View More clicked: now showing ${_parkingSpots.length} of ${_allParkingSpots.length} spots');
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View More',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
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
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingHistoryPage(bookings: []),
              ),
            );
          }
          setState(() => _currentIndex = index);
        },
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
}

class ParkingSpotCard extends StatelessWidget {
  final ParkingSpot spot;
  const ParkingSpotCard({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ParkingDetailPage(parkingSpot: spot.toJson()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(spot.parkingUser.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          children: spot.parkingUser.availableTypes
                              .split(',')
                              .map((type) => Container(
                            margin: const EdgeInsets.only(
                                right: 8, bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2E9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              type.trim(),
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 12,
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          spot.parkingUser.parkingName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          spot.parkingUser.address,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹ ${spot.parkingUser.hourlyRate}/hr',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${spot.distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_filled,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${spot.availableSlots} available',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
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

class ParkingSpot {
  final int id;
  final double latitude;
  final double longitude;
  final int availableSlots;
  final double distance;
  final ParkingUser parkingUser;

  ParkingSpot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.availableSlots,
    required this.distance,
    required this.parkingUser,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json, [List<ParkingSpot>? dummySpots]) {
    // Try to find matching dummy spot for fallback values
    ParkingSpot? dummySpot;
    if (dummySpots != null) {
      for (var spot in dummySpots) {
        if (spot.id == json['id']) {
          dummySpot = spot;
          break;
        }
      }
    }
    
    return ParkingSpot(
      id: json['id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      availableSlots: json['available_slots'] as int,
      distance: (json['distance'] as num).toDouble(),
      parkingUser: ParkingUser.fromJson(
        json['parking_user'], 
        dummySpot?.parkingUser
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'available_slots': availableSlots,
    'distance': distance,
    'parking_user': parkingUser.toJson(),
  };
}

class ParkingUser {
  final int id;
  final String name;
  final String? phone; // Make phone nullable
  final String email;
  final String parkingName;
  final String address;
  final double hourlyRate;
  final String openingHours;
  final double dailyRate;
  final double monthlyRate;
  final double rating;
  final String imageUrl;
  final String availableTypes;

  ParkingUser({
    required this.id,
    required this.name,
    this.phone,        // Optional parameter
    required this.email,
    required this.parkingName,
    required this.address,
    required this.hourlyRate,
    required this.openingHours,
    required this.dailyRate,
    required this.monthlyRate,
    required this.rating,
    required this.imageUrl,
    required this.availableTypes,
  });

  factory ParkingUser.fromJson(Map<String, dynamic> json, [ParkingUser? fallback]) {
    // Check if availableTypes is empty or missing
    final String availableTypesValue = json.containsKey('availableTypes') 
        ? (json['availableTypes'] as String? ?? '') 
        : '';
        
    // Use fallback data if availableTypes is empty
    final String finalAvailableTypes = (availableTypesValue.isEmpty && fallback != null) 
        ? fallback.availableTypes 
        : availableTypesValue;
        
    return ParkingUser(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String,
      parkingName: json['parking_name'] as String,
      address: json['address'] as String,
      hourlyRate: fallback != null && !json.containsKey('hourlyRate') 
          ? fallback.hourlyRate 
          : (json['hourlyRate'] as num).toDouble(),
      openingHours: fallback != null && !json.containsKey('openingHours') 
          ? fallback.openingHours 
          : json['openingHours'] as String,
      dailyRate: fallback != null && !json.containsKey('dailyRate') 
          ? fallback.dailyRate 
          : (json['dailyRate'] as num).toDouble(),
      monthlyRate: fallback != null && !json.containsKey('monthlyRate') 
          ? fallback.monthlyRate 
          : (json['monthlyRate'] as num).toDouble(),
      rating: fallback != null && !json.containsKey('rating') 
          ? fallback.rating 
          : (json['rating'] as num).toDouble(),
      imageUrl: fallback != null && !json.containsKey('image_url') 
          ? fallback.imageUrl 
          : json['image_url'] as String,
      availableTypes: finalAvailableTypes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'parking_name': parkingName,
    'address': address,
    'hourlyRate': hourlyRate,
    'openingHours': openingHours,
    'dailyRate': dailyRate,
    'monthlyRate': monthlyRate,
    'rating': rating,
    'image_url': imageUrl,
    'availableTypes': availableTypes,
  };
}