# Flutter App Integration Guide

This guide explains how to integrate crypto (USDT/USDC) payments into your Flutter application using this payment listener server.

## Overview

The payment flow works as follows:

1. **User initiates payment** in your Flutter app
2. **Flutter app generates a unique wallet address** or uses a payment address
3. **Flutter app calls your server** to start monitoring that address
4. **User sends USDT/USDC** from their wallet (MetaMask, Trust Wallet, etc.)
5. **Payment listener detects** the transaction on the blockchain
6. **Server notifies your Flutter app** (via webhook or polling)
7. **Flutter app confirms payment** and completes the order

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│   Flutter   │────────▶│   Railway    │────────▶│   Blockchain    │
│     App     │         │   Payment    │         │   (Ethereum/    │
│             │◀────────│   Listener   │◀────────│    BSC/Polygon) │
└─────────────┘         └──────────────┘         └─────────────────┘
      │                        │
      │                        │
      ▼                        ▼
┌─────────────┐         ┌──────────────┐
│  Your API   │         │   BTCPay     │
│  (Backend)  │         │   Server     │
└─────────────┘         └──────────────┘
```

## Prerequisites

### 1. Flutter Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  web3dart: ^2.7.0  # For wallet integration
  qr_flutter: ^4.1.0  # To show payment QR codes
  url_launcher: ^6.2.0  # To open wallet apps
```

### 2. Server URL

After deploying to Railway, you'll have a URL like:
```
https://your-app.up.railway.app
```

Store this in your Flutter app config.

## Implementation

### Step 1: Create Payment Service Class

Create `lib/services/crypto_payment_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CryptoPaymentService {
  final String baseUrl;

  CryptoPaymentService({required this.baseUrl});

  // Start monitoring a payment address
  Future<Map<String, dynamic>> startMonitoring({
    required String address,
    required String invoiceId,
    required String expectedAmount,
    String network = 'polygon',  // polygon is cheapest
    String token = 'usdt',
  }) async {
    try {
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
    } catch (e) {
      throw Exception('Error starting payment monitoring: $e');
    }
  }

  // Check balance of an address
  Future<Map<String, dynamic>> checkBalance({
    required String address,
    required String network,
    required String token,
  }) async {
    try {
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
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check balance: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking balance: $e');
    }
  }

  // Get active payments being monitored
  Future<Map<String, dynamic>> getActivePayments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/active-payments'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get active payments: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting active payments: $e');
    }
  }

  // Health check
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

### Step 2: Create Payment Screen

Create `lib/screens/crypto_payment_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/crypto_payment_service.dart';

class CryptoPaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String paymentAddress;  // Your business wallet address

  const CryptoPaymentScreen({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.paymentAddress,
  }) : super(key: key);

  @override
  State<CryptoPaymentScreen> createState() => _CryptoPaymentScreenState();
}

class _CryptoPaymentScreenState extends State<CryptoPaymentScreen> {
  final CryptoPaymentService _paymentService = CryptoPaymentService(
    baseUrl: 'https://your-app.up.railway.app',
  );

  String selectedNetwork = 'polygon';
  String selectedToken = 'usdt';
  bool isMonitoring = false;
  bool paymentReceived = false;
  Timer? _pollingTimer;

  final Map<String, String> networkNames = {
    'polygon': 'Polygon',
    'bsc': 'BSC (Binance Smart Chain)',
    'ethereum': 'Ethereum',
  };

  final Map<String, Map<String, String>> tokenContracts = {
    'polygon': {
      'usdt': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      'usdc': '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    },
    'bsc': {
      'usdt': '0x55d398326f99059fF775485246999027B3197955',
      'usdc': '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    },
    'ethereum': {
      'usdt': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      'usdc': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    },
  };

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    try {
      await _paymentService.startMonitoring(
        address: widget.paymentAddress,
        invoiceId: widget.orderId,
        expectedAmount: widget.amount.toString(),
        network: selectedNetwork,
        token: selectedToken,
      );

      setState(() {
        isMonitoring = true;
      });

      // Start polling for balance updates
      _startPolling();

    } catch (e) {
      _showError('Failed to start monitoring: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final balance = await _paymentService.checkBalance(
          address: widget.paymentAddress,
          network: selectedNetwork,
          token: selectedToken,
        );

        final currentBalance = double.parse(balance['balance'] ?? '0');

        if (currentBalance >= widget.amount) {
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
        title: const Text('Payment Received!'),
        content: const Text('Your payment has been confirmed. Thank you!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to previous screen
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getDeepLink() {
    // Create deep link for MetaMask/Trust Wallet
    final tokenAddress = tokenContracts[selectedNetwork]![selectedToken]!;
    return 'ethereum:$tokenAddress@${_getChainId()}/transfer?address=${widget.paymentAddress}&uint256=${widget.amount}';
  }

  String _getChainId() {
    switch (selectedNetwork) {
      case 'ethereum':
        return '1';
      case 'bsc':
        return '56';
      case 'polygon':
        return '137';
      default:
        return '1';
    }
  }

  Future<void> _openWallet() async {
    final deepLink = _getDeepLink();
    final uri = Uri.parse(deepLink);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('No compatible wallet app found');
    }
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: widget.paymentAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Payment'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Amount to Pay',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.amount} ${selectedToken.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order ID: ${widget.orderId}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Network Selection
            const Text(
              'Select Network',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedNetwork,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: networkNames.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: isMonitoring ? null : (value) {
                setState(() {
                  selectedNetwork = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Token Selection
            const Text(
              'Select Token',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'usdt', label: Text('USDT')),
                ButtonSegment(value: 'usdc', label: Text('USDC')),
              ],
              selected: {selectedToken},
              onSelectionChanged: isMonitoring ? null : (Set<String> selection) {
                setState(() {
                  selectedToken = selection.first;
                });
              },
            ),

            const SizedBox(height: 24),

            // QR Code
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Scan with your wallet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: widget.paymentAddress,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.paymentAddress,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _copyAddress,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Open Wallet Button
            ElevatedButton.icon(
              onPressed: _openWallet,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Open Wallet App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Status
            if (isMonitoring && !paymentReceived)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waiting for payment...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send exactly ${widget.amount} ${selectedToken.toUpperCase()} to the address above',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (paymentReceived)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Payment received and confirmed!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Step 3: Usage Example

In your checkout flow:

```dart
// In your cart/checkout screen
ElevatedButton(
  onPressed: () async {
    // Navigate to payment screen
    final paymentCompleted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CryptoPaymentScreen(
          orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
          amount: 10.00, // $10 worth of USDT/USDC
          paymentAddress: '0xYourBusinessWalletAddress', // Your receiving address
        ),
      ),
    );

    if (paymentCompleted == true) {
      // Payment successful, complete the order
      _completeOrder();
    }
  },
  child: const Text('Pay with Crypto'),
)
```

## Important Considerations

### 1. Payment Address Strategy

You have two options for payment addresses:

**Option A: Single Business Wallet (Simpler)**
- Use one wallet address for all payments
- Track payments by amount and timing
- Simpler but requires careful amount matching
- Good for low-volume businesses

**Option B: Unique Address Per Order (Recommended)**
- Generate a new address for each order
- Easy to track which payment belongs to which order
- Requires HD wallet implementation
- Better for high-volume businesses

### 2. Amount Precision

Crypto transactions may have rounding issues:

```dart
// Instead of exact match
if (receivedAmount >= expectedAmount * 0.999) {  // 0.1% tolerance
  // Payment confirmed
}
```

### 3. Network Selection

**Gas Fees Comparison:**
- Polygon: ~$0.01 per transaction (Recommended for small amounts)
- BSC: ~$0.20 per transaction
- Ethereum: $5-50+ per transaction (Only for large amounts)

**Recommendation:** Default to Polygon for best user experience.

### 4. Security

- Never store private keys in your Flutter app
- Use separate wallet addresses for each environment (dev/prod)
- Implement webhook authentication if using webhooks
- Validate all amounts on your backend

### 5. User Experience

- Show estimated confirmation time (Polygon: ~30 seconds, Ethereum: ~5 minutes)
- Provide transaction status updates
- Allow users to check payment status later
- Show clear instructions for first-time crypto users

## Testing

### Testnet Setup

For testing, use testnets:

1. **Polygon Mumbai Testnet**
   - RPC: `https://rpc-mumbai.maticvigil.com`
   - Get test MATIC: https://faucet.polygon.technology

2. **BSC Testnet**
   - RPC: `https://data-seed-prebsc-1-s1.binance.org:8545`
   - Get test BNB: https://testnet.binance.org/faucet-smart

3. **Ethereum Goerli Testnet**
   - RPC: `https://goerli.infura.io/v3/YOUR_INFURA_KEY`
   - Get test ETH: https://goerlifaucet.com

### Testing Checklist

- [ ] Test payment detection on each network
- [ ] Test with different amounts
- [ ] Test confirmation monitoring
- [ ] Test network switching
- [ ] Test error handling (insufficient balance, wrong network, etc.)
- [ ] Test deep linking to wallet apps
- [ ] Test QR code scanning
- [ ] Test payment timeout scenarios

## Production Checklist

- [ ] Deploy server to Railway
- [ ] Set all environment variables
- [ ] Add MongoDB for persistence
- [ ] Configure proper confirmation blocks (12+ for production)
- [ ] Set up monitoring/alerts
- [ ] Test with real small amounts first
- [ ] Implement proper error tracking (Sentry, etc.)
- [ ] Add webhook endpoint to your backend
- [ ] Implement automatic refund logic for overpayments
- [ ] Set up customer support for payment issues

## Webhook Integration (Alternative to Polling)

Instead of polling, you can set up webhooks:

### 1. Add Webhook Endpoint to Your Backend

```dart
// Your backend API (Node.js, Django, etc.)
app.post('/api/payment-webhook', (req, res) => {
  const payment = req.body;

  // Verify webhook signature
  // Update order status in database
  // Notify Flutter app via Firebase/Pusher/WebSocket

  res.json({ received: true });
});
```

### 2. Configure Server to Send Webhooks

Modify the payment listener to send webhooks to your backend instead of BTCPay.

## Support

For issues or questions:
1. Check Railway logs for server errors
2. Test API endpoints with Postman
3. Verify network and token configurations
4. Check blockchain explorer for transaction status
