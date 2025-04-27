import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'booking_confirmation.dart';

class PaymentGatewayPage extends StatefulWidget {
  final double fare;
  final String parkingSpotName;
  final String selectedDate;
  final String selectedSlot;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const PaymentGatewayPage({
    Key? key,
    required this.fare,
    required this.parkingSpotName,
    required this.selectedDate,
    required this.selectedSlot,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  String _selectedPaymentMethod = 'Credit Card';
  late double _totalAmount;

  @override
  void initState() {
    super.initState();
    _totalAmount = widget.fare * 1.18; // Including 18% tax
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
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
                  onPressed: _submitPayment,
                  child: const Text(
                    'Confirm Payment',
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

    final booking = {
      'parkingSpotName': widget.parkingSpotName,
      'selectedDate': widget.selectedDate,
      'selectedSlot': widget.selectedSlot,
      'totalAmount': _totalAmount,
      'paymentMethod': _selectedPaymentMethod,
      'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      'bookingTime': '${widget.startTime.format(context)} - ${widget.endTime.format(context)}',
      'status': 'Confirmed',
      'bookingDateTime': DateTime.now().toIso8601String(),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BookingConfirmationPage(
          parkingSpotName: widget.parkingSpotName,
          selectedDate: widget.selectedDate,
          selectedSlot: widget.selectedSlot,
          totalAmount: _totalAmount,
          paymentMethod: _selectedPaymentMethod,
          transactionId: booking['transactionId'] as String,
          bookingTime: booking['bookingTime'] as String,
        ),
      ),
    );
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