import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'booking_confirmation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PaymentGatewayPage extends StatefulWidget {
  final double fare;
  final String parkingSpotName;
  final String selectedDate;
  final String selectedSlot;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int parkingAreaId;

  const PaymentGatewayPage({
    Key? key,
    required this.fare,
    required this.parkingSpotName,
    required this.selectedDate,
    required this.selectedSlot,
    required this.startTime,
    required this.endTime,
    required this.parkingAreaId,
  }) : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  // Existing fields
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // Add phone controller
  
  String _selectedPaymentMethod = 'Credit Card';
  bool _isMakingPayment = false;
  String _errorMessage = '';
  double _totalAmount = 0;

  // Add loading state
  bool _isCreatingBooking = false;
  
  @override
  void initState() {
    super.initState();
    _calculateTotalAmount();
    
    // Prefill the phone controller with +91 prefix
    _phoneController.text = '+91';
  }
  
  void _calculateTotalAmount() {
    // Calculate the total based on fare and any additional fees
    setState(() {
      _totalAmount = widget.fare + (widget.fare * 0.05); // 5% service fee
    });
  }

  // Update the _createBooking method with better error logging and handling

  Future<void> _createBooking() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    setState(() {
      _isCreatingBooking = true;
      _errorMessage = '';
    });

    try {
      // Format times as HH:MM:SS
      String formatTimeOfDay(TimeOfDay time) {
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        return '$hour:$minute:00';
      }

      final startTimeStr = formatTimeOfDay(widget.startTime);
      final endTimeStr = formatTimeOfDay(widget.endTime);

      // Ensure phone number has +91 prefix
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+91')) {
        // If phone number doesn't start with +91, add it
        if (phoneNumber.startsWith('91')) {
          phoneNumber = '+$phoneNumber';
        } else if (phoneNumber.startsWith('0')) {
          phoneNumber = '+91${phoneNumber.substring(1)}';
        } else {
          phoneNumber = '+91$phoneNumber';
        }
      }

      // Create payload in the exact format specified
      final payload = {
        "slot": int.parse(widget.selectedSlot),
        "req_time_start": startTimeStr,
        "req_time_end": endTimeStr,
        "phone_number": phoneNumber
      };
      print("Sending booking request with payload: $payload");
      
      // Send booking request
      final response = await AuthService.protectedApiCall(() async {
        return await http.post(
          Uri.parse('${AuthService.baseUrl}/reservation/booking/'),
          headers: {
            ...await AuthService.getAuthHeader(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );
      });

      print("Booking response status: ${response.statusCode}");
      print("Booking response body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Booking successful
        final bookingData = jsonDecode(response.body);
        print("Booking data: $bookingData");
        final bookingId = bookingData['booking_id']?.toString() ?? '';
        
        if (bookingId.isEmpty) {
          throw Exception("Booking ID not found in response");
        }
        
        print("Fetching details for booking ID: $bookingId");
        // Fetch the booking details to get the QR code
        final bookingDetailsResponse = await AuthService.protectedApiCall(() async {
          return await http.get(
            Uri.parse('${AuthService.baseUrl}/reservation/booking/$bookingId'),
            headers: await AuthService.getAuthHeader(),
          );
        });
        
        print("Booking details response status: ${bookingDetailsResponse.statusCode}");
        print("Booking details response body: ${bookingDetailsResponse.body}");
        
        setState(() {
          _isCreatingBooking = false;
        });
        
        if (bookingDetailsResponse.statusCode == 200) {
          final bookingDetails = jsonDecode(bookingDetailsResponse.body);
          final qrCodeUrl = bookingDetails['qr_code']?.toString() ?? '';
          print("QR Code URL: $qrCodeUrl");
          
          try {
            // Navigate to confirmation page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BookingConfirmationPage(
                  parkingSpotName: widget.parkingSpotName,
                  selectedDate: widget.selectedDate,
                  selectedSlot: widget.selectedSlot,
                  startTimeStr: formatTimeOfDay(widget.startTime),
                  endTimeStr: formatTimeOfDay(widget.endTime),
                  bookingId: bookingId,
                  totalAmount: _totalAmount,
                  paymentMethod: _selectedPaymentMethod,
                  qrCode: qrCodeUrl,
                  transactionId: bookingDetails['transaction_id']?.toString() ?? 'Unknown',
                  bookingTime: DateTime.now().toString(),
                ),
              ),
            );
          } catch (e) {
            print("Error navigating to confirmation page: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Booking successful but unable to show confirmation: $e')),
            );
          }
        } else {
          throw Exception("Failed to fetch booking details: ${bookingDetailsResponse.statusCode}");
        }
      } else {
        // Failed - show error message
        setState(() {
          _isCreatingBooking = false;
        });
        
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['detail'] ?? 'Booking failed: ${response.statusCode}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print("Error in booking process: $e");
      setState(() {
        _isCreatingBooking = false;
        _errorMessage = 'Error creating booking: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  // Update submitPayment to call createBooking

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _phoneController.dispose(); // Dispose the phone controller
    super.dispose();
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
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Booking Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Parking Spot', widget.parkingSpotName),
                      _buildSummaryRow('Date', widget.selectedDate),
                      _buildSummaryRow(
                        'Time Slot',
                        '${widget.startTime.format(context)} - ${widget.endTime.format(context)}',
                      ),
                      _buildSummaryRow('Parking Slot', widget.selectedSlot),
                      const Divider(height: 24),
                      _buildSummaryRow('Base Fare', '₹${widget.fare.toStringAsFixed(2)}'),
                      _buildSummaryRow('Tax (18%)', '₹${(_totalAmount - widget.fare).toStringAsFixed(2)}'),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Total Amount',
                        '₹${_totalAmount.toStringAsFixed(2)}',
                        isBold: true,
                        textColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPaymentMethodChip('Credit Card', Icons.credit_card),
                  _buildPaymentMethodChip('PayPal', Icons.payment),
                  _buildPaymentMethodChip('Google Pay', Icons.account_balance_wallet),
                ],
              ),
              const SizedBox(height: 24),
              if (_selectedPaymentMethod == 'Credit Card') ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Cardholder Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    border: OutlineInputBorder(),
                    hintText: '1234 5678 9012 3456',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CardNumberFormatter(),
                  ],
                  validator: (value) => (value?.replaceAll(' ', '').length ?? 0) != 16
                      ? 'Invalid card number'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date',
                          border: OutlineInputBorder(),
                          hintText: 'MM/YY',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          CardExpiryFormatter(),
                        ],
                        validator: (value) => (value?.replaceAll('/', '').length ?? 0) != 4
                            ? 'Invalid date'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          border: OutlineInputBorder(),
                          hintText: '123',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) => (value?.length ?? 0) != 3 ? 'Invalid CVV' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              // Phone number field section (outside of the payment method condition)
              const SizedBox(height: 24),
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  hintText: '+918828600128',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Phone number is required' : null,
              ),
              const SizedBox(height: 24),
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
                  onPressed: _isCreatingBooking ? null : _submitPayment,
                  child: _isCreatingBooking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String method, IconData icon) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(method),
        ],
      ),
      selected: _selectedPaymentMethod == method,
      onSelected: (selected) {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      selectedColor: Colors.deepPurple.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _selectedPaymentMethod == method ? Colors.deepPurple : Colors.black,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _selectedPaymentMethod == method ? Colors.deepPurple : Colors.grey[300]!,
        ),
      ),
    );
  }

  void _submitPayment() {
    if (_selectedPaymentMethod == 'Credit Card' && !(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }

    // Create the booking after payment info is validated
    _createBooking();
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      text = text.substring(0, 4);
    }
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        formatted += '/';
      }
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}