// Flutter Example: Complete Payment Flow
// This is a standalone example showing how to integrate crypto payments

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Payment Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProductScreen(),
    );
  }
}

// 1. Product/Checkout Screen
class ProductScreen extends StatelessWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProductCard(
            name: 'Premium Plan',
            price: 10.00,
            description: 'Monthly subscription',
            onBuy: () => _handlePurchase(context, 'Premium Plan', 10.00),
          ),
          const SizedBox(height: 16),
          ProductCard(
            name: 'Pro Plan',
            price: 25.00,
            description: 'Yearly subscription',
            onBuy: () => _handlePurchase(context, 'Pro Plan', 25.00),
          ),
          const SizedBox(height: 16),
          ProductCard(
            name: 'Enterprise Plan',
            price: 100.00,
            description: 'Lifetime access',
            onBuy: () => _handlePurchase(context, 'Enterprise Plan', 100.00),
          ),
        ],
      ),
    );
  }

  void _handlePurchase(BuildContext context, String productName, double price) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PaymentMethodSheet(
        productName: productName,
        price: price,
      ),
    );
  }
}

// 2. Payment Method Selection
class PaymentMethodSheet extends StatelessWidget {
  final String productName;
  final double price;

  const PaymentMethodSheet({
    Key? key,
    required this.productName,
    required this.price,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay for $productName',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '\$$price USD',
            style: const TextStyle(fontSize: 32, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Payment Method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CryptoPaymentScreen(
                    orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                    productName: productName,
                    amount: price,
                    // Replace with your actual business wallet address
                    paymentAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.currency_bitcoin),
            label: const Text('Pay with Crypto (USDT/USDC)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // Traditional payment methods
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Card payment not implemented in demo')),
              );
            },
            icon: const Icon(Icons.credit_card),
            label: const Text('Pay with Card'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Product Card Widget
class ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final String description;
  final VoidCallback onBuy;

  const ProductCard({
    Key? key,
    required this.name,
    required this.price,
    required this.description,
    required this.onBuy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$$price USD',
                  style: const TextStyle(fontSize: 24, color: Colors.blue),
                ),
                ElevatedButton(
                  onPressed: onBuy,
                  child: const Text('Buy Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Crypto Payment Service
class CryptoPaymentService {
  // Replace with your Railway deployment URL
  static const String baseUrl = 'https://your-app.up.railway.app';

  Future<Map<String, dynamic>> startMonitoring({
    required String address,
    required String invoiceId,
    required String expectedAmount,
    String network = 'polygon',
    String token = 'usdt',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/monitor-address'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'invoiceId': invoiceId,
        'expectedAmount': expectedAmount,
        'network': network,
        'token': token,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start monitoring: ${response.body}');
    }
  }

  Future<double> checkBalance({
    required String address,
    required String network,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/check-balance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'network': network,
        'token': token,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return double.parse(data['balance'] ?? '0');
    } else {
      throw Exception('Failed to check balance: ${response.body}');
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// 5. Main Payment Screen
class CryptoPaymentScreen extends StatefulWidget {
  final String orderId;
  final String productName;
  final double amount;
  final String paymentAddress;

  const CryptoPaymentScreen({
    Key? key,
    required this.orderId,
    required this.productName,
    required this.amount,
    required this.paymentAddress,
  }) : super(key: key);

  @override
  State<CryptoPaymentScreen> createState() => _CryptoPaymentScreenState();
}

class _CryptoPaymentScreenState extends State<CryptoPaymentScreen> {
  final CryptoPaymentService _paymentService = CryptoPaymentService();

  String selectedNetwork = 'polygon';
  String selectedToken = 'usdt';
  bool isMonitoring = false;
  bool paymentReceived = false;
  bool hasError = false;
  String errorMessage = '';
  Timer? _pollingTimer;
  int _elapsedSeconds = 0;
  double currentBalance = 0.0;

  final Map<String, String> networkNames = {
    'polygon': 'Polygon (Recommended)',
    'bsc': 'BSC',
    'ethereum': 'Ethereum',
  };

  final Map<String, String> networkFees = {
    'polygon': '~\$0.01',
    'bsc': '~\$0.20',
    'ethereum': '\$5-50',
  };

  @override
  void initState() {
    super.initState();
    _checkServerAndStart();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkServerAndStart() async {
    final isHealthy = await _paymentService.checkServerHealth();
    if (!isHealthy) {
      setState(() {
        hasError = true;
        errorMessage = 'Payment server is currently unavailable';
      });
      return;
    }
    await _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    try {
      setState(() {
        hasError = false;
        isMonitoring = false;
      });

      await _paymentService.startMonitoring(
        address: widget.paymentAddress,
        invoiceId: widget.orderId,
        expectedAmount: widget.amount.toString(),
        network: selectedNetwork,
        token: selectedToken,
      );

      setState(() {
        isMonitoring = true;
        _elapsedSeconds = 0;
      });

      _startPolling();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Failed to start payment monitoring: $e';
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    // Poll every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      setState(() {
        _elapsedSeconds += 10;
      });

      // Timeout after 30 minutes
      if (_elapsedSeconds > 1800) {
        timer.cancel();
        _showTimeoutDialog();
        return;
      }

      try {
        final balance = await _paymentService.checkBalance(
          address: widget.paymentAddress,
          network: selectedNetwork,
          token: selectedToken,
        );

        setState(() {
          currentBalance = balance;
        });

        // Check if payment received (with 0.1% tolerance)
        if (balance >= widget.amount * 0.999) {
          timer.cancel();
          setState(() {
            paymentReceived = true;
          });
          _onPaymentReceived();
        }
      } catch (e) {
        print('Error checking balance: $e');
      }
    });
  }

  void _onPaymentReceived() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Text('Payment Received!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment has been confirmed.'),
            const SizedBox(height: 16),
            Text('Order: ${widget.orderId}'),
            Text('Product: ${widget.productName}'),
            Text('Amount: ${widget.amount} ${selectedToken.toUpperCase()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
              // Navigate to success screen or home
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Timeout'),
        content: const Text(
          'The payment session has expired. Please try again or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startMonitoring();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: widget.paymentAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Payment'),
        backgroundColor: Colors.blue,
      ),
      body: hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Info
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.productName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.amount.toStringAsFixed(2)} ${selectedToken.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order: ${widget.orderId}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Network Selection
                  const Text(
                    'Network',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...networkNames.entries.map((entry) {
                    return RadioListTile<String>(
                      title: Text(entry.value),
                      subtitle: Text('Gas fee: ${networkFees[entry.key]}'),
                      value: entry.key,
                      groupValue: selectedNetwork,
                      onChanged: isMonitoring
                          ? null
                          : (value) {
                              setState(() {
                                selectedNetwork = value!;
                              });
                            },
                    );
                  }).toList(),

                  const SizedBox(height: 16),

                  // Token Selection
                  const Text(
                    'Token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'usdt',
                        label: Text('USDT'),
                        icon: Icon(Icons.currency_exchange),
                      ),
                      ButtonSegment(
                        value: 'usdc',
                        label: Text('USDC'),
                        icon: Icon(Icons.attach_money),
                      ),
                    ],
                    selected: {selectedToken},
                    onSelectionChanged: isMonitoring
                        ? null
                        : (Set<String> selection) {
                            setState(() {
                              selectedToken = selection.first;
                            });
                          },
                  ),

                  if (!isMonitoring) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _startMonitoring,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Start Payment'),
                    ),
                  ],

                  if (isMonitoring) ...[
                    const SizedBox(height: 24),

                    // Payment Instructions
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Address',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.paymentAddress,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: _copyAddress,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Send exactly ${widget.amount.toStringAsFixed(2)} ${selectedToken.toUpperCase()} on ${networkNames[selectedNetwork]}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Card
                    Card(
                      color: paymentReceived ? Colors.green[50] : Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (!paymentReceived) ...[
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Waiting for payment...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Elapsed: ${_formatTime(_elapsedSeconds)}'),
                              if (currentBalance > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Received: ${currentBalance.toStringAsFixed(2)} ${selectedToken.toUpperCase()}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ] else ...[
                              Icon(Icons.check_circle,
                                  color: Colors.green[700], size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Payment Confirmed!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
