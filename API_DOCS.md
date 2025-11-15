# API Documentation

Complete API reference for the Crypto Payment Listener Server.

## Base URL

```
https://your-app.up.railway.app
```

Replace with your actual Railway deployment URL.

## Authentication

Currently, the API endpoints are public. For production, consider adding API key authentication:

```
Authorization: Bearer YOUR_API_KEY
```

---

## Endpoints

### 1. Start Monitoring Payment Address

Start monitoring a wallet address for incoming USDT/USDC payments.

**Endpoint:** `POST /api/monitor-address`

**Request Body:**
```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "invoiceId": "ORD-123456",
  "expectedAmount": "10.50",
  "network": "polygon",
  "token": "usdt"
}
```

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `address` | string | Yes | Wallet address to monitor (checksummed or lowercase) |
| `invoiceId` | string | Yes | Your unique order/invoice ID |
| `expectedAmount` | string | No | Expected payment amount (for validation) |
| `network` | string | No | Network: `ethereum`, `bsc`, or `polygon` (default: any) |
| `token` | string | No | Token: `usdt` or `usdc` (default: both) |

**Success Response (200):**
```json
{
  "success": true,
  "message": "Address is now being monitored",
  "address": "0x742d35cc6634c0532925a3b844bc9e7595f0beb",
  "invoiceId": "ORD-123456"
}
```

**Error Response (400):**
```json
{
  "error": "Address and invoiceId are required"
}
```

**Example (cURL):**
```bash
curl -X POST https://your-app.railway.app/api/monitor-address \
  -H "Content-Type: application/json" \
  -d '{
    "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
    "invoiceId": "ORD-123456",
    "expectedAmount": "10.50",
    "network": "polygon",
    "token": "usdt"
  }'
```

**Example (Dart/Flutter):**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/monitor-address'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'address': '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
    'invoiceId': 'ORD-123456',
    'expectedAmount': '10.50',
    'network': 'polygon',
    'token': 'usdt',
  }),
);
```

---

### 2. Check Token Balance

Check the USDT/USDC balance of a specific address.

**Endpoint:** `POST /api/check-balance`

**Request Body:**
```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "network": "polygon",
  "token": "usdt"
}
```

**Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `address` | string | Yes | Wallet address to check |
| `network` | string | Yes | Network: `ethereum`, `bsc`, or `polygon` |
| `token` | string | Yes | Token: `usdt` or `usdc` |

**Success Response (200):**
```json
{
  "address": "0x742d35cc6634c0532925a3b844bc9e7595f0beb",
  "network": "polygon",
  "token": "USDT",
  "balance": "125.500000"
}
```

**Error Response (400):**
```json
{
  "error": "Address, network, and token are required"
}
```

**Error Response (400) - Invalid Network/Token:**
```json
{
  "error": "Invalid network or token: invalid/usdt"
}
```

**Error Response (500):**
```json
{
  "error": "Error message from blockchain provider"
}
```

**Example (cURL):**
```bash
curl -X POST https://your-app.railway.app/api/check-balance \
  -H "Content-Type: application/json" \
  -d '{
    "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
    "network": "polygon",
    "token": "usdt"
  }'
```

**Example (Dart/Flutter):**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/check-balance'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'address': '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
    'network': 'polygon',
    'token': 'usdt',
  }),
);

final data = jsonDecode(response.body);
print('Balance: ${data['balance']} ${data['token']}');
```

---

### 3. Get Active Payments

Get list of all addresses currently being monitored.

**Endpoint:** `GET /api/active-payments`

**No Request Body Required**

**Success Response (200):**
```json
{
  "count": 2,
  "payments": [
    {
      "address": "0x742d35cc6634c0532925a3b844bc9e7595f0beb",
      "invoiceId": "ORD-123456",
      "expectedAmount": "10.50",
      "network": "polygon",
      "token": "usdt",
      "createdAt": "2025-11-15T10:30:00.000Z"
    },
    {
      "address": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      "invoiceId": "ORD-123457",
      "expectedAmount": "25.00",
      "network": "ethereum",
      "token": "usdc",
      "createdAt": "2025-11-15T10:35:00.000Z"
    }
  ]
}
```

**Example (cURL):**
```bash
curl https://your-app.railway.app/api/active-payments
```

**Example (Dart/Flutter):**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/active-payments'),
);

final data = jsonDecode(response.body);
print('Monitoring ${data['count']} payments');
```

---

### 4. Health Check

Check if the server is running and which networks are active.

**Endpoint:** `GET /api/health`

**No Request Body Required**

**Success Response (200):**
```json
{
  "status": "running",
  "networks": [
    {
      "network": "ethereum",
      "active": true
    },
    {
      "network": "bsc",
      "active": true
    },
    {
      "network": "polygon",
      "active": true
    }
  ],
  "activePayments": 5
}
```

**Example (cURL):**
```bash
curl https://your-app.railway.app/api/health
```

**Example (Dart/Flutter):**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/health'),
);

if (response.statusCode == 200) {
  print('Server is healthy');
} else {
  print('Server is down');
}
```

---

## Payment Flow

### How Payment Detection Works

1. **Start Monitoring:**
   - Call `POST /api/monitor-address` with the payment address
   - Server adds address to monitoring list
   - Blockchain event listeners are already running

2. **Payment Sent:**
   - User sends USDT/USDC from their wallet
   - Transaction is broadcast to blockchain
   - Transaction gets mined into a block

3. **Payment Detected:**
   - Server's event listener catches the Transfer event
   - Server checks if recipient is in monitoring list
   - Server logs the payment details

4. **Confirmation Monitoring:**
   - Server waits for required confirmations (default: 12 blocks)
   - After confirmations, payment status changes to "confirmed"
   - Server sends notification (if BTCPay or webhook configured)
   - Address is removed from monitoring list

5. **Flutter App Polling:**
   - Your Flutter app polls `POST /api/check-balance` every 10-30 seconds
   - When balance >= expected amount, show payment success
   - Alternatively, use webhooks to push updates

---

## Supported Networks

### Ethereum Mainnet
- **Chain ID:** 1
- **USDT Contract:** `0xdAC17F958D2ee523a2206206994597C13D831ec7`
- **USDC Contract:** `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- **Gas Fees:** High ($5-50+)
- **Confirmation Time:** ~1-5 minutes
- **Recommended For:** Large transactions only

### BSC (Binance Smart Chain)
- **Chain ID:** 56
- **USDT Contract:** `0x55d398326f99059fF775485246999027B3197955`
- **USDC Contract:** `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d`
- **Gas Fees:** Low (~$0.20)
- **Confirmation Time:** ~15-30 seconds
- **Recommended For:** Medium transactions

### Polygon (Matic)
- **Chain ID:** 137
- **USDT Contract:** `0xc2132D05D31c914a87C6611C10748AEb04B58e8F`
- **USDC Contract:** `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`
- **Gas Fees:** Very Low (~$0.01)
- **Confirmation Time:** ~10-30 seconds
- **Recommended For:** Small to medium transactions (Recommended default)

---

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request - Missing or invalid parameters |
| 500 | Internal Server Error - Blockchain provider error |

---

## Rate Limiting

Currently no rate limiting is implemented. Consider adding rate limiting in production:

```javascript
// Example: 100 requests per minute per IP
```

---

## Webhooks (Future Feature)

Currently, the server notifies BTCPay Server. To receive webhooks in your own backend:

**Webhook Payload (When Payment Confirmed):**
```json
{
  "network": "polygon",
  "token": "USDT",
  "from": "0x1234...",
  "to": "0x742d35cc6634c0532925a3b844bc9e7595f0beb",
  "amount": "10.500000",
  "txHash": "0xabcd...",
  "blockNumber": 12345678,
  "confirmations": 12,
  "requiredConfirmations": 12,
  "timestamp": "2025-11-15T10:30:00.000Z",
  "invoiceId": "ORD-123456",
  "expectedAmount": "10.50",
  "status": "confirmed"
}
```

To enable webhooks to your backend, modify the `notifyBTCPay` function in `index.js` to point to your webhook endpoint.

---

## Best Practices

### 1. Polling Strategy
```dart
// Poll every 10 seconds for first 2 minutes
// Then every 30 seconds for next 5 minutes
// Then every 60 seconds
```

### 2. Amount Tolerance
```dart
// Allow 0.1% tolerance for rounding
if (receivedAmount >= expectedAmount * 0.999) {
  // Consider paid
}
```

### 3. Timeout Handling
```dart
// Cancel monitoring after 30 minutes of no payment
Timer(Duration(minutes: 30), () {
  // Show timeout message
  // Allow retry or cancel
});
```

### 4. Error Handling
```dart
try {
  final response = await apiCall();
  // Handle success
} on SocketException {
  // No internet
} on TimeoutException {
  // Request timeout
} catch (e) {
  // Generic error
}
```

---

## Testing with Postman

Import this Postman collection:

```json
{
  "info": {
    "name": "Crypto Payment API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Start Monitoring",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"address\": \"0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb\",\n  \"invoiceId\": \"TEST-001\",\n  \"expectedAmount\": \"10.00\",\n  \"network\": \"polygon\",\n  \"token\": \"usdt\"\n}"
        },
        "url": {
          "raw": "{{baseUrl}}/api/monitor-address",
          "host": ["{{baseUrl}}"],
          "path": ["api", "monitor-address"]
        }
      }
    },
    {
      "name": "Check Balance",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"address\": \"0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb\",\n  \"network\": \"polygon\",\n  \"token\": \"usdt\"\n}"
        },
        "url": {
          "raw": "{{baseUrl}}/api/check-balance",
          "host": ["{{baseUrl}}"],
          "path": ["api", "check-balance"]
        }
      }
    },
    {
      "name": "Active Payments",
      "request": {
        "method": "GET",
        "url": {
          "raw": "{{baseUrl}}/api/active-payments",
          "host": ["{{baseUrl}}"],
          "path": ["api", "active-payments"]
        }
      }
    },
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": {
          "raw": "{{baseUrl}}/api/health",
          "host": ["{{baseUrl}}"],
          "path": ["api", "health"]
        }
      }
    }
  ],
  "variable": [
    {
      "key": "baseUrl",
      "value": "https://your-app.railway.app"
    }
  ]
}
```

---

## Support

For API issues:
1. Check Railway deployment logs
2. Verify environment variables are set
3. Test with Postman/cURL first
4. Check blockchain explorer for transaction status
