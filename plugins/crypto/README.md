# Crypto Plugin

Multi-chain blockchain explorer integration using Foundry's `cast` CLI. Query contract source code, balances, transactions, gas prices, and blocks across Ethereum, Polygon, Arbitrum, Optimism, Base, and BSC.

## Features

- **Multi-chain support**: Ethereum, Polygon, Arbitrum, Optimism, Base, BSC
- **Zero-config RPC**: Works out of the box with PublicNode fallback endpoints
- **Auto-triggered skills**: Claude automatically uses these based on your intent
- **Contract inspection**: Fetch verified source code from block explorers
- **Address information**: Check balances and account types (EOA vs contract)
- **Transaction lookup**: Get detailed transaction data
- **Gas prices**: Check current gas costs with transaction estimates
- **Block information**: Query block data

## Installation

### Prerequisites

1. **zsh** - Scripts use zsh for cross-platform compatibility
   - macOS: Pre-installed (default shell)
   - Linux: Install with your package manager if needed

2. **Foundry (cast)** - Install the Foundry toolkit:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

3. **Verify installation**:
   ```bash
   zsh --version
   cast --version
   ```

### Environment Variables

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

#### RPC URLs (optional - has free fallback)

**No configuration required!** The plugin automatically uses [PublicNode](https://publicnode.com) as a free fallback when environment variables are not set.

The fallback endpoints are:
| Chain | Fallback RPC URL |
|-------|------------------|
| Ethereum | `https://ethereum-rpc.publicnode.com` |
| Polygon | `https://polygon-bor-rpc.publicnode.com` |
| Arbitrum | `https://arbitrum-one-rpc.publicnode.com` |
| Optimism | `https://optimism-rpc.publicnode.com` |
| Base | `https://base-rpc.publicnode.com` |
| BSC | `https://bsc-rpc.publicnode.com` |

For higher rate limits or private endpoints, set your own RPC URLs:

```bash
# Optional: Override with your own RPC endpoints
export ETHEREUM_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export POLYGON_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"
export ARBITRUM_RPC_URL="https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY"
export OPTIMISM_RPC_URL="https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY"
export BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_KEY"
export BSC_RPC_URL="https://bsc-dataseed.binance.org"
```

You can get private RPC endpoints from:
- [Alchemy](https://www.alchemy.com/) (free tier available)
- [Infura](https://infura.io/) (free tier available)
- [QuickNode](https://www.quicknode.com/) (free tier available)

#### API Keys (required for contract-source skill)

```bash
export ETHERSCAN_API_KEY="your-key"
export POLYGONSCAN_API_KEY="your-key"
export ARBISCAN_API_KEY="your-key"
export OPTIMISM_API_KEY="your-key"
export BASESCAN_API_KEY="your-key"
export BSCSCAN_API_KEY="your-key"
```

Get free API keys from:
- [Etherscan](https://etherscan.io/apis)
- [Polygonscan](https://polygonscan.com/apis)
- [Arbiscan](https://arbiscan.io/apis)
- [Optimism Etherscan](https://optimistic.etherscan.io/apis)
- [Basescan](https://basescan.org/apis)
- [BSCScan](https://bscscan.com/apis)

## Skills

These skills are **auto-triggered** by Claude based on your intent. No `/command` needed!

### Contract Source

Fetch verified contract source code from block explorers.

**Trigger phrases**: "get contract source", "show verified contract", "fetch source from etherscan"

**Requirements**: API key for the target chain

**Example prompts**:
- "Show me the source code for WETH at 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
- "Get the verified contract code for Uniswap Router on Polygon"

### Address Info

Get balance and account type (EOA vs contract) for an address.

**Trigger phrases**: "check balance", "what's the balance of", "is this a contract"

**Requirements**: None (uses PublicNode fallback if RPC not configured)

**Example prompts**:
- "What's the balance of vitalik.eth?"
- "Check if 0x1234... is a contract or EOA on Arbitrum"

### Transaction Info

Get detailed information about a transaction.

**Trigger phrases**: "transaction details", "show me tx", "what happened in this transaction"

**Requirements**: None (uses PublicNode fallback if RPC not configured)

**Example prompts**:
- "Show me the details of transaction 0x1234...abcd"
- "What happened in this tx on Polygon: 0x5678..."

### Gas Price

Get current gas price with transaction cost estimates.

**Trigger phrases**: "gas price", "how much is gas", "current gas"

**Requirements**: None (uses PublicNode fallback if RPC not configured)

**Example prompts**:
- "What's the current gas price on Ethereum?"
- "Check gas fees on Arbitrum"

### Block Info

Get information about a specific block.

**Trigger phrases**: "block info", "what's in block", "latest block"

**Requirements**: None (uses PublicNode fallback if RPC not configured)

**Example prompts**:
- "Show me the latest block on Ethereum"
- "Get block 18000000 details"

## Supported Chains

| Chain | Aliases | Chain ID | Explorer |
|-------|---------|----------|----------|
| ethereum | eth, mainnet | 1 | Etherscan |
| polygon | matic | 137 | Polygonscan |
| arbitrum | arb | 42161 | Arbiscan |
| optimism | op | 10 | Optimism Etherscan |
| base | - | 8453 | Basescan |
| bsc | binance, bnb | 56 | BSCScan |

## Test Addresses

Use these well-known addresses to verify your setup:

### Ethereum Mainnet
- **WETH**: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- **USDC**: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- **Uniswap V2 Router**: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`

### Polygon
- **USDC**: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`
- **QuickSwap Router**: `0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff`

## Troubleshooting

### "cast not found"

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### "API key not configured"

Set the API key for contract source fetching:
```bash
export ETHERSCAN_API_KEY="your-key"
```

### "Contract not verified"

The contract source is not available on the block explorer. You can still:
- Check the address balance with the address-info skill
- View transaction data with the tx-info skill

### Rate Limiting

If you hit rate limits with the PublicNode fallback:
- Configure your own RPC endpoints (see Environment Variables section)
- Use providers with higher free tier limits (Alchemy, Infura, QuickNode)
- Upgrade to a paid API plan for production use

## License

MIT
