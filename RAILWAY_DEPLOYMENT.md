# Railway Deployment Guide

This guide will help you deploy the Web3 Payment Listener service to Railway.

## Prerequisites

1. [Railway account](https://railway.app/) (sign up with GitHub)
2. MongoDB database (Railway plugin or MongoDB Atlas)
3. BTCPay Server instance running
4. Blockchain RPC provider API keys (Alchemy recommended for Ethereum)

## Quick Start

### Option 1: Deploy via Railway Dashboard

1. **Create a new project on Railway**
   - Go to [Railway Dashboard](https://railway.app/dashboard)
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Connect your GitHub account and select this repository

2. **Add MongoDB**
   - In your Railway project, click "New"
   - Select "Database" → "Add MongoDB"
   - Railway will automatically set the `MONGODB_URI` environment variable

3. **Configure Environment Variables**
   - Click on your web3-listener service
   - Go to "Variables" tab
   - Add the following variables (see details below)

4. **Deploy**
   - Railway will automatically build and deploy using the Dockerfile
   - Your service will be available at the generated Railway URL

### Option 2: Deploy via Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login to Railway
railway login

# Initialize project
railway init

# Add MongoDB
railway add

# Set environment variables (or use Railway dashboard)
railway variables set ETHEREUM_RPC_URL=your_value_here

# Deploy
railway up
```

## Required Environment Variables

Set these in Railway Dashboard → Your Service → Variables:

### Blockchain RPC URLs
```
ETHEREUM_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
BSC_RPC_URL=https://bsc-dataseed1.binance.org
POLYGON_RPC_URL=https://polygon-rpc.com
```

**Get Alchemy API Key:**
1. Sign up at [Alchemy](https://www.alchemy.com/)
2. Create a new app for Ethereum Mainnet
3. Copy the HTTPS URL

### Token Contract Addresses (Mainnet - Pre-configured)
```
USDT_ETH_CONTRACT=0xdAC17F958D2ee523a2206206994597C13D831ec7
USDC_ETH_CONTRACT=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT_BSC_CONTRACT=0x55d398326f99059fF775485246999027B3197955
USDC_BSC_CONTRACT=0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
USDT_POLYGON_CONTRACT=0xc2132D05D31c914a87C6611C10748AEb04B58e8F
USDC_POLYGON_CONTRACT=0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
```

### BTCPay Server Configuration
```
BTCPAY_SERVER_URL=https://your-btcpay-server.com
BTCPAY_API_KEY=your_btcpay_api_key
BTCPAY_STORE_ID=your_store_id
```

**Get BTCPay credentials:**
1. Log into your BTCPay Server
2. Go to Account → Manage Account → API Keys
3. Create new API key with required permissions
4. Copy Store ID from Store Settings

### MongoDB Configuration
```
MONGODB_URI=mongodb://username:password@host:port/database
```

Railway's MongoDB plugin will automatically set this variable.

Alternatively, use MongoDB Atlas:
1. Create cluster at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Get connection string
3. Set as `MONGODB_URI`

### Server Configuration
```
PORT=3001
NODE_ENV=production
```

**Note:** Railway automatically sets `PORT` - you don't need to set this manually.

### Monitoring Configuration (Optional)
```
CONFIRMATION_BLOCKS=12
POLL_INTERVAL=15000
```

### Webhook Configuration (Optional)
```
WEBHOOK_SECRET=your_webhook_secret_here
```

## Post-Deployment Steps

### 1. Get Your Railway Service URL

After deployment, Railway will provide a URL like:
```
https://your-service-name.up.railway.app
```

### 2. Test the Health Endpoint

```bash
curl https://your-service-name.up.railway.app/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2025-11-15T..."
}
```

### 3. Test the Balance Check Endpoint

```bash
curl -X POST https://your-service-name.up.railway.app/api/check-balance \
  -H "Content-Type: application/json" \
  -d '{
    "network": "ethereum",
    "address": "0x...",
    "token": "USDT"
  }'
```

### 4. Configure BTCPay Server Webhook (if needed)

If BTCPay Server needs to call your listener:
1. Go to BTCPay Store Settings → Webhooks
2. Add webhook URL: `https://your-service-name.up.railway.app/api/webhook`
3. Set the webhook secret (same as `WEBHOOK_SECRET` env var)

### 5. Monitor Your Service

**View Logs:**
- Railway Dashboard → Your Service → Deployments → View Logs
- Or use CLI: `railway logs`

**Metrics:**
- Railway Dashboard → Your Service → Metrics
- Monitor CPU, Memory, and Network usage

## API Endpoints

Once deployed, your service exposes these endpoints:

### Monitor Payment Address
```bash
POST https://your-service.railway.app/api/monitor-address
Content-Type: application/json

{
  "network": "ethereum",
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "invoiceId": "INV-001",
  "expectedAmount": "100.00",
  "token": "USDT"
}
```

### Get Active Payments
```bash
GET https://your-service.railway.app/api/active-payments
```

### Health Check
```bash
GET https://your-service.railway.app/api/health
```

### Check Token Balance
```bash
POST https://your-service.railway.app/api/check-balance
Content-Type: application/json

{
  "network": "ethereum",
  "address": "0x...",
  "token": "USDT"
}
```

## Troubleshooting

### Deployment Fails

**Check build logs:**
```bash
railway logs --deployment
```

**Common issues:**
- Missing environment variables
- Invalid MongoDB connection string
- Docker build errors

### Service Crashes

**Check runtime logs:**
```bash
railway logs
```

**Common issues:**
- Invalid RPC URLs (test them separately)
- BTCPay Server unreachable
- MongoDB connection timeout
- Insufficient memory (upgrade plan if needed)

### Can't Connect to MongoDB

1. Verify `MONGODB_URI` is set correctly
2. Check MongoDB service is running
3. Test connection string locally first
4. Ensure MongoDB allows connections from Railway IPs

### RPC Connection Issues

1. Verify RPC URLs are correct and accessible
2. Check API key limits (Alchemy free tier has limits)
3. Test RPC endpoints:
```bash
curl -X POST YOUR_RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### BTCPay Integration Issues

1. Verify BTCPay Server URL is accessible
2. Check API key permissions
3. Ensure Store ID is correct
4. Test API key with curl:
```bash
curl https://your-btcpay.com/api/v1/stores \
  -H "Authorization: token YOUR_API_KEY"
```

## Scaling Considerations

### Free Tier Limits
- 500 hours/month execution time
- $5 credit
- Shared CPU/memory

### Production Recommendations
- Upgrade to Hobby plan ($5/month) or higher
- Enable auto-scaling if traffic is variable
- Monitor resource usage in Railway dashboard
- Consider Redis for caching if processing many payments

### High Availability
- Railway automatically restarts crashed services
- Configure `restartPolicyMaxRetries` in [railway.json](railway.json)
- Set up monitoring alerts

## Security Best Practices

1. **Never commit `.env` files** - Use Railway environment variables
2. **Rotate API keys regularly** - Especially BTCPay and RPC keys
3. **Use HTTPS only** - Railway provides SSL by default
4. **Set webhook secrets** - Validate incoming requests
5. **Monitor logs** - Watch for suspicious activity
6. **Restrict MongoDB access** - Use strong passwords and IP whitelist

## Cost Estimation

**Railway Pricing:**
- Starter: $5/month (500 hours execution)
- Hobby: $5/month + usage
- Pro: $20/month + usage

**MongoDB Atlas (if not using Railway plugin):**
- Free tier: 512MB storage (sufficient for testing)
- Shared: $9/month (2GB storage)

**Alchemy RPC:**
- Free tier: 300M compute units/month (sufficient for moderate usage)
- Growth: $49/month (starts at)

**Estimated monthly cost for small-scale deployment:**
- Railway Hobby: $5-10
- MongoDB Atlas Free: $0
- Alchemy Free: $0
- **Total: $5-10/month**

## Support

- [Railway Documentation](https://docs.railway.app/)
- [Railway Discord](https://discord.gg/railway)
- [BTCPay Server Docs](https://docs.btcpayserver.org/)

## Additional Resources

- [Example .env file](.env.example)
- [Main README](README.md)
- [Package dependencies](package.json)
