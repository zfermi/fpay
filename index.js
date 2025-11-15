const express = require('express');
const { ethers } = require('ethers');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

// ERC20 ABI for USDT/USDC
const ERC20_ABI = [
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function balanceOf(address) view returns (uint256)"
];

// Network configurations
const networks = {
  ethereum: {
    rpc: process.env.ETHEREUM_RPC_URL,
    usdt: process.env.USDT_ETH_CONTRACT,
    usdc: process.env.USDC_ETH_CONTRACT,
    chainId: 1
  },
  bsc: {
    rpc: process.env.BSC_RPC_URL,
    usdt: process.env.USDT_BSC_CONTRACT,
    usdc: process.env.USDC_BSC_CONTRACT,
    chainId: 56
  },
  polygon: {
    rpc: process.env.POLYGON_RPC_URL,
    usdt: process.env.USDT_POLYGON_CONTRACT,
    usdc: process.env.USDC_POLYGON_CONTRACT,
    chainId: 137
  }
};

// Store active payment addresses
const activePayments = new Map();

class Web3Listener {
  constructor() {
    this.providers = {};
    this.contracts = {};
    this.initializeNetworks();
  }

  initializeNetworks() {
    console.log('Initializing Web3 listeners...');

    for (const [networkName, config] of Object.entries(networks)) {
      if (!config.rpc) {
        console.warn(`No RPC URL configured for ${networkName}, skipping...`);
        continue;
      }

      try {
        const provider = new ethers.JsonRpcProvider(config.rpc);
        this.providers[networkName] = provider;

        // Initialize USDT contract
        if (config.usdt) {
          const usdtContract = new ethers.Contract(config.usdt, ERC20_ABI, provider);
          this.contracts[`${networkName}_usdt`] = usdtContract;
          this.startListening(networkName, 'usdt', usdtContract);
        }

        // Initialize USDC contract
        if (config.usdc) {
          const usdcContract = new ethers.Contract(config.usdc, ERC20_ABI, provider);
          this.contracts[`${networkName}_usdc`] = usdcContract;
          this.startListening(networkName, 'usdc', usdcContract);
        }

        console.log(`✓ Initialized ${networkName}`);
      } catch (error) {
        console.error(`Failed to initialize ${networkName}:`, error.message);
      }
    }
  }

  startListening(network, token, contract) {
    console.log(`Starting listener for ${token.toUpperCase()} on ${network}`);

    contract.on('Transfer', async (from, to, value, event) => {
      await this.handleTransfer(network, token, from, to, value, event);
    });
  }

  async handleTransfer(network, token, from, to, value, event) {
    try {
      // Check if the recipient address is in our active payments
      const paymentInfo = activePayments.get(to.toLowerCase());

      if (!paymentInfo) {
        // Not a payment we're tracking
        return;
      }

      const decimals = await this.contracts[`${network}_${token}`].decimals();
      const amount = ethers.formatUnits(value, decimals);

      console.log(`
========================================
New ${token.toUpperCase()} Transfer Detected!
Network: ${network}
From: ${from}
To: ${to}
Amount: ${amount} ${token.toUpperCase()}
Tx Hash: ${event.log.transactionHash}
Block: ${event.log.blockNumber}
========================================
      `);

      // Get current block to check confirmations
      const currentBlock = await this.providers[network].getBlockNumber();
      const confirmations = currentBlock - event.log.blockNumber;
      const requiredConfirmations = parseInt(process.env.CONFIRMATION_BLOCKS) || 12;

      const paymentData = {
        network,
        token: token.toUpperCase(),
        from,
        to,
        amount,
        txHash: event.log.transactionHash,
        blockNumber: event.log.blockNumber,
        confirmations,
        requiredConfirmations,
        timestamp: new Date().toISOString(),
        invoiceId: paymentInfo.invoiceId,
        expectedAmount: paymentInfo.expectedAmount,
        status: confirmations >= requiredConfirmations ? 'confirmed' : 'pending'
      };

      // Notify BTCPay Server
      if (confirmations >= requiredConfirmations) {
        await this.notifyBTCPay(paymentData);
      } else {
        console.log(`Waiting for confirmations: ${confirmations}/${requiredConfirmations}`);
        // Monitor this transaction for confirmations
        this.monitorConfirmations(paymentData, network);
      }

    } catch (error) {
      console.error('Error handling transfer:', error);
    }
  }

  async monitorConfirmations(paymentData, network) {
    const checkConfirmations = async () => {
      try {
        const currentBlock = await this.providers[network].getBlockNumber();
        const confirmations = currentBlock - paymentData.blockNumber;

        console.log(`Tx ${paymentData.txHash}: ${confirmations}/${paymentData.requiredConfirmations} confirmations`);

        if (confirmations >= paymentData.requiredConfirmations) {
          paymentData.confirmations = confirmations;
          paymentData.status = 'confirmed';
          await this.notifyBTCPay(paymentData);
        } else {
          // Check again in 30 seconds
          setTimeout(checkConfirmations, 30000);
        }
      } catch (error) {
        console.error('Error monitoring confirmations:', error);
      }
    };

    setTimeout(checkConfirmations, 30000);
  }

  async notifyBTCPay(paymentData) {
    try {
      const btcpayUrl = process.env.BTCPAY_SERVER_URL;
      const apiKey = process.env.BTCPAY_API_KEY;

      if (!btcpayUrl || !apiKey) {
        console.log('BTCPay Server not configured, logging payment only:');
        console.log(JSON.stringify(paymentData, null, 2));
        return;
      }

      // Send webhook to BTCPay Server
      const response = await axios.post(
        `${btcpayUrl}/api/v1/webhooks/payment-received`,
        paymentData,
        {
          headers: {
            'Authorization': `token ${apiKey}`,
            'Content-Type': 'application/json'
          }
        }
      );

      console.log('✓ BTCPay Server notified successfully');

      // Remove from active payments after successful notification
      activePayments.delete(paymentData.to.toLowerCase());

    } catch (error) {
      console.error('Error notifying BTCPay Server:', error.message);
      // Store for retry logic if needed
    }
  }
}

// API Endpoints
app.post('/api/monitor-address', (req, res) => {
  const { address, invoiceId, expectedAmount, network, token } = req.body;

  if (!address || !invoiceId) {
    return res.status(400).json({ error: 'Address and invoiceId are required' });
  }

  activePayments.set(address.toLowerCase(), {
    invoiceId,
    expectedAmount,
    network,
    token,
    createdAt: new Date().toISOString()
  });

  console.log(`Now monitoring address: ${address} for invoice: ${invoiceId}`);

  res.json({
    success: true,
    message: 'Address is now being monitored',
    address,
    invoiceId
  });
});

app.get('/api/active-payments', (req, res) => {
  const payments = Array.from(activePayments.entries()).map(([address, info]) => ({
    address,
    ...info
  }));

  res.json({ count: payments.length, payments });
});

app.get('/api/health', (req, res) => {
  const networksStatus = Object.keys(networks).map(network => ({
    network,
    active: !!listener.providers[network]
  }));

  res.json({
    status: 'running',
    networks: networksStatus,
    activePayments: activePayments.size
  });
});

app.post('/api/check-balance', async (req, res) => {
  const { address, network, token } = req.body;

  if (!address || !network || !token) {
    return res.status(400).json({ error: 'Address, network, and token are required' });
  }

  try {
    const contract = listener.contracts[`${network}_${token}`];
    if (!contract) {
      return res.status(400).json({ error: `Invalid network or token: ${network}/${token}` });
    }

    const balance = await contract.balanceOf(address);
    const decimals = await contract.decimals();
    const formattedBalance = ethers.formatUnits(balance, decimals);

    res.json({
      address,
      network,
      token: token.toUpperCase(),
      balance: formattedBalance
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Initialize listener
const listener = new Web3Listener();

// Start server
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`
========================================
Web3 Listener Server Started
Port: ${PORT}
Networks: ${Object.keys(networks).join(', ')}
Monitoring: USDT, USDC
========================================
  `);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down gracefully...');
  process.exit(0);
});
