import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import
import 'dart:convert';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'detail.dart'; // Adjust the import path if necessary
import 'auth_service.dart'; // Import the actual AuthService

class ParkingSpot {
  final int id;
  final double latitude;
  final double longitude;
  final int availableSlots;
  final double distance;
  final String name;
  final String address;
  final double hourlyRate;
  final String openingHours;
  final double rating;
  final String imageUrl;
  final List<String> availableTypes;
  final String time;
  final Map<String, dynamic> data; // Store original JSON for detail page

  ParkingSpot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.availableSlots,
    required this.distance,
    required this.name,
    required this.address,
    required this.hourlyRate,
    required this.openingHours,
    required this.rating,
    required this.imageUrl,
    required this.availableTypes,
    required this.time,
    required this.data,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) {
    final parkingUser = json['parking_user'] ?? {};
    final availableTypesStr = parkingUser['available_types'] as String? ?? '';
    final availableTypes =
        availableTypesStr.isNotEmpty
            ? availableTypesStr
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
    final distanceValue = (json['distance'] ?? 0).toDouble();
    final estimatedTime = '${(distanceValue * 4).round()} mins';

    return ParkingSpot(
      id: json['id'] ?? 0,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      availableSlots: json['available_slots'] ?? 0,
      distance: distanceValue,
      name: parkingUser['parking_name'] ?? 'Unknown Parking',
      address: parkingUser['address'] ?? 'No Address',
      hourlyRate: (parkingUser['hourly_rate'] ?? 0).toDouble(),
      openingHours: parkingUser['opening_hours'] ?? '24/7',
      rating: (parkingUser['rating'] ?? 0).toDouble(),
      imageUrl:
          parkingUser['image_url'] ??
          'https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg',
      availableTypes: availableTypes,
      time: estimatedTime,
      data: json,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? mapController;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  List<ParkingSpot> _parkingSpots = [];
  bool _isLoading = true;
  String _locationName = "Current Location";
  bool _locationError = false;
  final String _googleMapsApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? ''; // Get API key from .env

  // For directions
  ParkingSpot? _selectedSpot;
  bool _showDirections = false;
  bool _isLoadingDirections = false;
  List<Map<String, dynamic>> _alternativeRoutes = [];
  int _selectedRouteIndex = 0;

  // For drawer animation
  late DraggableScrollableController _draggableScrollableController;
  double _initialChildSize = 0.3;
  double _minChildSize = 0.1;
  double _maxChildSize = 0.7;

  // For search animation
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  bool _isSearching = false;
  bool _showPlacesAutocomplete = false;

  // For map mode
  String _mapMode = "search"; // "search" or "directions"

  // For info window
  ParkingSpot? _infoWindowSpot;

  // For drawer snap positions
  final List<double> _snapPositions = [0.1, 0.3, 0.7];

  List<Map<String, dynamic>> _autocompletePredictions = [];
  bool _isLoadingPredictions = false;

  @override
  void initState() {
    super.initState();
    _draggableScrollableController = DraggableScrollableController();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _draggableScrollableController.dispose();
    _searchAnimationController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = true);
        _useDummyData();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = true);
          _useDummyData();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = true);
        _useDummyData();
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(
        () => _currentPosition = LatLng(position.latitude, position.longitude),
      );
      await _reverseGeocodeLocation(position);
      await _fetchParkingSpots();
    } catch (e) {
      setState(() {
        _locationError = true;
        _locationName = "Nagari Niwara";
      });
      _useDummyData();
    }
  }

  Future<void> _reverseGeocodeLocation(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          final locality = placemarks.first.locality ?? '';
          final subLocality = placemarks.first.subLocality ?? '';
          _locationName = "$locality $subLocality".trim();
          if (_locationName.isEmpty) _locationName = "Current Location";
        });
      }
    } catch (e) {
      setState(() => _locationName = "Current Location");
    }
  }

  Future<void> _fetchParkingSpots() async {
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await AuthService.protectedApiCall(() async {
        return await http.get(
          Uri.parse(
            '${AuthService.baseUrl}/reservation/parking-area/nearby/?user-lat=${_currentPosition!.latitude}&user-long=${_currentPosition!.longitude}',
          ),
          headers: await AuthService.getAuthHeader(),
        );
      });

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            _parkingSpots =
                List<Map<String, dynamic>>.from(
                  data,
                ).map((spot) => ParkingSpot.fromJson(spot)).toList();
            _parkingSpots.sort((a, b) => a.distance.compareTo(b.distance));
            _addMarkers();
            _isLoading = false;
          });
        } else {
          debugPrint('API returned unexpected data format: $data');
          _useDummyData();
        }
      } else {
        throw Exception('Failed to load parking spots');
      }
    } catch (e) {
      debugPrint('Error fetching parking spots: $e');
      if (e.toString().contains("Session expired")) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        _useDummyData();
      }
    }
  }

  void _useDummyData() {
    final dummyData = [
      {
        "id": 1,
        "latitude": 19.0760,
        "longitude": 72.8777,
        "available_slots": 92,
        "distance": 2.5,
        "parking_user": {
          "id": 1,
          "name": "John Doe",
          "phone": "9876543210",
          "email": "john@example.com",
          "parking_name": "Trios Fashion Mall Parking",
          "address": "Hill Road, Bandra West, Mumbai, Maharashtra 400050",
          "hourly_rate": 50,
          "opening_hours": "24/7",
          "daily_rate": 500,
          "monthly_rate": 5000,
          "rating": 4.2,
          "image_url":
              "https://cdn11.bigcommerce.com/s-64cbb/product_images/uploaded_images/tgtechnicalservices-246300-parking-garage-safer-blogbanner1.jpg",
          "available_types": "Compact,SUV,Bike",
        },
      },
      {
        "id": 2,
        "latitude": 19.0860,
        "longitude": 72.8877,
        "available_slots": 50,
        "distance": 3.0,
        "parking_user": {
          "id": 2,
          "name": "Jane Smith",
          "phone": "9876543211",
          "email": "jane@example.com",
          "parking_name": "Linking Road Parking",
          "address": "Linking Road, Bandra West, Mumbai, Maharashtra 400050",
          "hourly_rate": 60,
          "opening_hours": "24/7",
          "daily_rate": 600,
          "monthly_rate": 6000,
          "rating": 4.5,
          "image_url":
              "https://www.adanirealty.com/-/media/project/realty/blogs/what-is-stilt-parking-meaning-rules-how-it-works.ashx",
          "available_types": "Compact,SUV",
        },
      },
      {
        "id": 3,
        "latitude": 19.0960,
        "longitude": 72.8977,
        "available_slots": 75,
        "distance": 3.5,
        "parking_user": {
          "id": 3,
          "name": "Alice Johnson",
          "phone": "9876543212",
          "email": "alice@example.com",
          "parking_name": "SV Road Parking",
          "address": "SV Road, Bandra West, Mumbai, Maharashtra 400050",
          "hourly_rate": 70,
          "opening_hours": "24/7",
          "daily_rate": 700,
          "monthly_rate": 7000,
          "rating": 4.7,
          "image_url":
              "https://raicdn.nl/cdn-cgi/image/width=3840,quality=75,format=auto,sharpen=1/https://edge.sitecorecloud.io/raiamsterda13f7-raidigitalpdb6c-productionf3f5-ef30/media/project/rai-amsterdam-xmc/intertraffic/intertraffic/news/2022/9/parkingshape1-550-x-300-px.png",
          "available_types": "SUV,Bike",
        },
      },
      {
        "id": 4,
        "latitude": 19.0660,
        "longitude": 72.8677,
        "available_slots": 120,
        "distance": 2.8,
        "parking_user": {
          "id": 4,
          "name": "Bob Williams",
          "phone": "9876543213",
          "email": "bob@example.com",
          "parking_name": "Kalpataru Avana Parking",
          "address": "Gen Nagesh Marg, Parel, Mumbai, Maharashtra 400012",
          "hourly_rate": 55,
          "opening_hours": "24/7",
          "daily_rate": 550,
          "monthly_rate": 5500,
          "rating": 4.1,
          "image_url":
              "https://www.99acres.com/microsite/articles/files/2018/07/car-parking.jpg",
          "available_types": "SUV,Bike",
        },
      },
      {
        "id": 5,
        "latitude": 19.1060,
        "longitude": 72.9077,
        "available_slots": 35,
        "distance": 6.0,
        "parking_user": {
          "id": 5,
          "name": "Charlie Brown",
          "phone": "9876543214",
          "email": "charlie@example.com",
          "parking_name": "MCGM Parking Lot Andheri",
          "address":
              "Jay Prakash Road, Andheri West, Mumbai, Maharashtra 400058",
          "hourly_rate": 40,
          "opening_hours": "24/7",
          "daily_rate": 400,
          "monthly_rate": 4000,
          "rating": 3.9,
          "image_url":
              "https://raicdn.nl/cdn-cgi/image/width=3840,quality=75,format=auto,sharpen=1/https://edge.sitecorecloud.io/raiamsterda13f7-raidigitalpdb6c-productionf3f5-ef30/media/project/rai-amsterdam-xmc/intertraffic/intertraffic/news/2022/9/parkingshape1-550-x-300-px.png",
          "available_types": "Compact",
        },
      },
    ];

    setState(() {
      _parkingSpots =
          dummyData.map((spot) => ParkingSpot.fromJson(spot)).toList();
      _addMarkers();
      _isLoading = false;
    });
  }

  void _addMarkers() {
    if (_currentPosition == null) return;
    _markers.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('current'),
        position: _currentPosition!,
        infoWindow: InfoWindow(title: _locationName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    for (final spot in _parkingSpots) {
      _markers.add(
        Marker(
          markerId: MarkerId(spot.id.toString()),
          position: LatLng(spot.latitude, spot.longitude),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet:
                '${spot.availableSlots} spots - ₹${spot.hourlyRate.toInt()}/hr',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () {
            setState(() {
              _infoWindowSpot = spot;
              _selectedSpot = spot;
            });
          },
        ),
      );
    }
    setState(() {});
  }

  Future<void> _getDirections(ParkingSpot destination) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingDirections = true;
      _mapMode = "directions";
      _showDirections = true;
      _selectedSpot = destination;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&alternatives=true&key=$_googleMapsApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if ((data['routes'] as List).isNotEmpty) {
          final List<Map<String, dynamic>> routes = [];

          for (var route in data['routes']) {
            final points = route['overview_polyline']['points'];
            final PolylinePoints polylinePoints = PolylinePoints();
            final List<PointLatLng> decodedPoints = polylinePoints
                .decodePolyline(points);
            final List<LatLng> polylineCoordinates =
                decodedPoints
                    .map((point) => LatLng(point.latitude, point.longitude))
                    .toList();

            routes.add({
              'polyline': polylineCoordinates,
              'summary': route['summary'] ?? 'Route',
              'distance': route['legs'][0]['distance']['text'],
              'duration': route['legs'][0]['duration']['text'],
              'steps': route['legs'][0]['steps'],
            });
          }

          setState(() {
            _alternativeRoutes = routes;
            _selectedRouteIndex = 0;
            _updatePolylines();
            _fitPolylineToBounds();
            _snapDrawerTo(_minChildSize);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get directions: $e')));
      }
    } finally {
      setState(() => _isLoadingDirections = false);
    }
  }

  void _updatePolylines() {
    if (_alternativeRoutes.isEmpty ||
        _selectedRouteIndex >= _alternativeRoutes.length)
      return;

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points:
              _alternativeRoutes[_selectedRouteIndex]['polyline']
                  as List<LatLng>,
          width: 5,
          color: Colors.blue,
        ),
      );
    });
  }

  void _fitPolylineToBounds() {
    if (_alternativeRoutes.isEmpty ||
        _selectedRouteIndex >= _alternativeRoutes.length ||
        mapController == null)
      return;

    final points =
        _alternativeRoutes[_selectedRouteIndex]['polyline'] as List<LatLng>;
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _handlePlaceSelection(Map<String, dynamic> prediction) {
    setState(() {
      _showPlacesAutocomplete = false;
      _searchController.text = prediction['description'] ?? '';
      _isSearching = true;
    });

    _getPlaceDetails(prediction['place_id'] ?? '');
  }

  Future<void> _getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];

          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
          );
          setState(() => _currentPosition = LatLng(lat, lng));

          await _reverseGeocodeLocation(
            Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
          );

          await _fetchParkingSpots();

          setState(() {
            _showDirections = false;
            _polylines.clear();
            _alternativeRoutes = [];
            _mapMode = "search";
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting place details: $e')),
        );
      }
      setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showPlacesAutocomplete = false;
      _autocompletePredictions = [];
      _showDirections = false;
      _polylines.clear();
      _alternativeRoutes = [];
      _selectedSpot = null;
      _infoWindowSpot = null;
      _mapMode = "search";
    });
    _getCurrentLocation();
  }

  void _centerOnSpot(ParkingSpot spot) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(spot.latitude, spot.longitude), 16),
    );
    setState(() {
      _selectedSpot = spot;
      _infoWindowSpot = spot;
    });

    if (MediaQuery.of(context).size.width < 600) {
      _snapDrawerTo(_minChildSize);
    }
  }

  void _backToSearch() {
    setState(() {
      _showDirections = false;
      _polylines.clear();
      _alternativeRoutes = [];
      _mapMode = "search";
    });
  }

  void _snapDrawerTo(double position) {
    if (_draggableScrollableController.isAttached) {
      _draggableScrollableController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  double _getClosestSnapPosition(double currentPosition) {
    return _snapPositions.reduce((a, b) {
      return (currentPosition - a).abs() < (currentPosition - b).abs() ? a : b;
    });
  }

  Widget _buildDirectionsPanel() {
    if (_alternativeRoutes.isEmpty) return const SizedBox();

    final currentRoute = _alternativeRoutes[_selectedRouteIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Directions to ${_selectedSpot?.name ?? ""}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _backToSearch,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _alternativeRoutes.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final route = _alternativeRoutes[index];
              final isSelected = index == _selectedRouteIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRouteIndex = index;
                    _updatePolylines();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Route ${index + 1} (${route['duration']})',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentRoute['summary'] ?? 'Route',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${currentRoute['distance']} · ${currentRoute['duration']}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Selected',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            itemCount: (currentRoute['steps'] as List?)?.length ?? 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final step = currentRoute['steps'][index];
              final instructions = (step['html_instructions'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'<[^>]*>'), ' ')
                  .replaceAll('  ', ' ');

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            instructions,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${step['distance']['text']} · ${step['duration']['text']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParkingSpotCard(ParkingSpot spot, {bool isHorizontal = false}) {
    final isSelected = _selectedSpot?.id == spot.id;

    if (isHorizontal) {
      return Container(
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
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: spot.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.error),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          spot.availableTypes
                              .map(
                                (type) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spot.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      spot.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${spot.distance} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          spot.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RatingBar.builder(
                          initialRating: spot.rating,
                          minRating: 1,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemSize: 16,
                          ignoreGestures: true,
                          itemBuilder:
                              (context, _) =>
                                  const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) {},
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${spot.rating})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${spot.hourlyRate.toInt()}/hr',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.local_parking,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${spot.availableSlots} available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.location_on,
                            color: Colors.blue.shade700,
                          ),
                          onPressed: () => _centerOnSpot(spot),
                          tooltip: 'View on Map',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.directions,
                            color: Colors.blue.shade700,
                          ),
                          onPressed: () => _getDirections(spot),
                          tooltip: 'Get Directions',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ParkingDetailPage(
                                      parkingSpot: spot.data,
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(40, 36),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Book'),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: spot.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey.shade300,
                          height: 150,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          color: Colors.grey.shade300,
                          height: 150,
                          child: const Icon(Icons.error),
                        ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₹${spot.hourlyRate.toInt()}/hr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${spot.distance} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        spot.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RatingBar.builder(
                        initialRating: spot.rating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 16,
                        ignoreGestures: true,
                        itemBuilder:
                            (context, _) =>
                                const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {},
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${spot.rating})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.local_parking,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${spot.availableSlots} spots available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        spot.availableTypes
                            .map(
                              (type) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _centerOnSpot(spot),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('View on Map'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ParkingDetailPage(
                                      parkingSpot: spot.data,
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Book Now'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _getDirections(spot),
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
  }

  Widget _buildInfoWindow() {
    if (_infoWindowSpot == null) return const SizedBox();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _infoWindowSpot!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _infoWindowSpot!.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _infoWindowSpot = null);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${_infoWindowSpot!.hourlyRate.toInt()}/hr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_infoWindowSpot!.availableSlots} spots',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _getDirections(_infoWindowSpot!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Get Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ParkingDetailPage(
                                parkingSpot: _infoWindowSpot!.data,
                              ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Book Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchPlaces(String input) async {
    if (input.isEmpty) return;

    setState(() {
      _isLoadingPredictions = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleMapsApiKey&components=country:in',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _autocompletePredictions = List<Map<String, dynamic>>.from(
              data['predictions'],
            );
            _isLoadingPredictions = false;
          });
        } else {
          setState(() {
            _autocompletePredictions = [];
            _isLoadingPredictions = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _autocompletePredictions = [];
        _isLoadingPredictions = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching places: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet =
        MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) => mapController = controller,
              ),
          if (_isLoadingDirections)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (!_showPlacesAutocomplete)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_mapMode == "directions")
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _backToSearch,
                          ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showPlacesAutocomplete = true;
                              });
                            },
                            child: AbsorbPointer(
                              absorbing: true,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search for parking locations...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      _searchController.text.isNotEmpty
                                          ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: _clearSearch,
                                          )
                                          : _isSearching
                                          ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showPlacesAutocomplete)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() {
                                  _showPlacesAutocomplete = false;
                                  _autocompletePredictions = [];
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Search for locations',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    _searchPlaces(value);
                                  } else {
                                    setState(() {
                                      _autocompletePredictions = [];
                                    });
                                  }
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _autocompletePredictions = [];
                                  });
                                },
                              ),
                          ],
                        ),
                        if (_isLoadingPredictions)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_autocompletePredictions.isNotEmpty)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 300,
                              maxWidth: MediaQuery.of(context).size.width - 32,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _autocompletePredictions.length,
                              itemBuilder: (context, index) {
                                final prediction =
                                    _autocompletePredictions[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on,
                                    color: Colors.grey,
                                  ),
                                  title: Text(
                                    prediction['description'] ?? '',
                                    style: const TextStyle(fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    prediction['structured_formatting']?['secondary_text'] ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _handlePlaceSelection(prediction);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locationButton',
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          if (_infoWindowSpot != null && _mapMode == "search")
            _buildInfoWindow(),
          if (isDesktop && _mapMode == "search" && _parkingSpots.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              bottom: 16,
              width: 400,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.local_parking, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Nearby Parking Spots',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_parkingSpots.length} found',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: _parkingSpots.length,
                                itemBuilder: (context, index) {
                                  return _buildParkingSpotCard(
                                    _parkingSpots[index],
                                    isHorizontal: true,
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          if (isDesktop &&
              _mapMode == "directions" &&
              _alternativeRoutes.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              bottom: 16,
              width: 400,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildDirectionsPanel(),
              ),
            ),
          if (!isDesktop)
            DraggableScrollableSheet(
              initialChildSize: _initialChildSize,
              minChildSize: _minChildSize,
              maxChildSize: _maxChildSize,
              snap: true,
              snapSizes: _snapPositions,
              controller: _draggableScrollableController,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onVerticalDragUpdate: (details) {
                          final currentSize =
                              _draggableScrollableController.size;
                          final newSize =
                              currentSize -
                              (details.delta.dy /
                                  MediaQuery.of(context).size.height);
                          final clampedSize = newSize.clamp(
                            _minChildSize,
                            _maxChildSize,
                          );
                          if (_draggableScrollableController.isAttached) {
                            _draggableScrollableController.jumpTo(clampedSize);
                          }
                        },
                        onVerticalDragEnd: (details) {
                          if (_draggableScrollableController.isAttached) {
                            final closestPosition = _getClosestSnapPosition(
                              _draggableScrollableController.size,
                            );
                            _snapDrawerTo(closestPosition);
                          }
                        },
                        child: Container(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _mapMode == "directions"
                                              ? Icons.directions
                                              : Icons.local_parking,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _mapMode == "directions"
                                              ? 'Directions to ${_selectedSpot?.name ?? ""}'
                                              : 'Nearby Parking Spots',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (_mapMode == "search")
                                          Text(
                                            '${_parkingSpots.length} found',
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                          ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children:
                                              _snapPositions.map((position) {
                                                final isActive =
                                                    _draggableScrollableController
                                                        .isAttached &&
                                                    (_draggableScrollableController
                                                                    .size -
                                                                position)
                                                            .abs() <
                                                        0.05;
                                                return Container(
                                                  width: 8,
                                                  height: 8,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color:
                                                        isActive
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey
                                                                .shade300,
                                                  ),
                                                );
                                              }).toList(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _mapMode == "directions"
                                ? _buildDirectionsPanel()
                                : _parkingSpots.isEmpty
                                ? const Center(
                                  child: Text('No parking spots found'),
                                )
                                : GridView.builder(
                                  controller: scrollController,
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isTablet ? 2 : 1,
                                        childAspectRatio: isTablet ? 0.8 : 0.9,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: _parkingSpots.length,
                                  itemBuilder: (context, index) {
                                    return _buildParkingSpotCard(
                                      _parkingSpots[index],
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
