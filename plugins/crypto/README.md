# Crypto Plugin

Multi-chain blockchain explorer integration supporting **EVM chains** (via Foundry's `cast`) and **Solana** (via Solana/Anchor CLI). Query contract source code, balances, transactions, fees, and blocks across multiple networks.

## Features

### EVM Chains (Ethereum, Polygon, Arbitrum, Optimism, Base, BSC)
- **Zero-config RPC**: Works out of the box with PublicNode fallback endpoints
- **Contract inspection**: Fetch verified source code from block explorers
- **Address information**: Check balances and account types (EOA vs contract)
- **Transaction lookup**: Get detailed transaction data
- **Gas prices**: Check current gas costs with transaction estimates
- **Block information**: Query block data

### Solana
- **Public RPC fallback**: Uses Solana public RPC by default
- **Account inspection**: Check SOL balances and account types
- **Transaction lookup**: Get transaction details by signature
- **Slot/Block info**: Query current slot and epoch data
- **Program IDL**: Fetch Anchor program IDL from on-chain

## Installation

### Prerequisites

1. **zsh** - Scripts use zsh for cross-platform compatibility
   - macOS: Pre-installed (default shell)
   - Linux: Install with your package manager if needed

2. **For EVM skills** - Install Foundry toolkit:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

3. **For Solana skills** - Install Solana CLI:
   ```bash
   sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
   export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
   ```

4. **For IDL fetching** - Install Anchor CLI (optional):
   ```bash
   cargo install --git https://github.com/coral-xyz/anchor anchor-cli --locked
   ```

5. **Verify installation**:
   ```bash
   zsh --version
   cast --version      # For EVM skills
   solana --version    # For Solana skills
   anchor --version    # For IDL skill (optional)
   ```

### Environment Variables

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

#### EVM RPC URLs (optional - has free fallback)

**No configuration required!** The plugin automatically uses [PublicNode](https://publicnode.com) as a free fallback.

| Chain | Fallback RPC URL |
|-------|------------------|
| Ethereum | `https://ethereum-rpc.publicnode.com` |
| Polygon | `https://polygon-bor-rpc.publicnode.com` |
| Arbitrum | `https://arbitrum-one-rpc.publicnode.com` |
| Optimism | `https://optimism-rpc.publicnode.com` |
| Base | `https://base-rpc.publicnode.com` |
| BSC | `https://bsc-rpc.publicnode.com` |

For higher rate limits, set your own RPC URLs:
```bash
export ETHEREUM_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export POLYGON_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"
# ... etc
```

#### Solana RPC URLs (optional - has free fallback)

| Chain | Fallback RPC URL |
|-------|------------------|
| Solana | `https://api.mainnet-beta.solana.com` |
| Solana Devnet | `https://api.devnet.solana.com` |

For better performance, configure a custom RPC:
```bash
export SOLANA_RPC_URL="https://your-helius-endpoint.com"
export SOLANA_DEVNET_RPC_URL="https://your-devnet-endpoint.com"
```

#### API Keys (required for evm-contract-source skill)

```bash
export ETHERSCAN_API_KEY="your-key"
export POLYGONSCAN_API_KEY="your-key"
export ARBISCAN_API_KEY="your-key"
export OPTIMISM_API_KEY="your-key"
export BASESCAN_API_KEY="your-key"
export BSCSCAN_API_KEY="your-key"
```

Get free API keys from: [Etherscan](https://etherscan.io/apis), [Polygonscan](https://polygonscan.com/apis), [Arbiscan](https://arbiscan.io/apis), [Optimism Etherscan](https://optimistic.etherscan.io/apis), [Basescan](https://basescan.org/apis), [BSCScan](https://bscscan.com/apis)

## Skills

All skills are **auto-triggered** by Claude based on your intent. No `/command` needed!

### EVM Skills (`evm-*`)

| Skill | Trigger Phrases | Requirements |
|-------|-----------------|--------------|
| `evm-contract-source` | "get contract source", "show verified contract" | API key |
| `evm-address-info` | "check balance", "is this a contract" | None |
| `evm-tx-info` | "transaction details", "show me tx" | None |
| `evm-gas-price` | "gas price", "current gas" | None |
| `evm-block-info` | "block info", "latest block" | None |

**Example prompts**:
- "Show me the source code for WETH at 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
- "What's the balance of vitalik.eth?"
- "What's the current gas price on Ethereum?"
- "Check gas fees on Arbitrum"

### Solana Skills (`sol-*`)

| Skill | Trigger Phrases | Requirements |
|-------|-----------------|--------------|
| `sol-account-info` | "solana balance", "is this a program" | `solana` CLI |
| `sol-tx-info` | "solana transaction", "signature details" | `solana` CLI |
| `sol-slot-info` | "current slot", "solana block" | `solana` CLI |
| `sol-fees` | "solana fees", "priority fees" | `solana` CLI |
| `sol-program-idl` | "fetch IDL", "anchor idl" | `anchor` CLI |

**Example prompts**:
- "What's the balance of vines1vzrYbzLMRdu58ou5XTby4qAqVRLmqo36NKPTg on Solana?"
- "Check current slot on Solana"
- "What are the current fees on Solana?"
- "Fetch the IDL for MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD"

## Supported Chains

### EVM Chains

| Chain | Aliases | Chain ID | Native Token | Explorer |
|-------|---------|----------|--------------|----------|
| ethereum | eth, mainnet | 1 | ETH | Etherscan |
| polygon | matic | 137 | MATIC | Polygonscan |
| arbitrum | arb | 42161 | ETH | Arbiscan |
| optimism | op | 10 | ETH | Optimism Etherscan |
| base | - | 8453 | ETH | Basescan |
| bsc | binance, bnb | 56 | BNB | BSCScan |

### Solana Chains

| Chain | Aliases | Network | Native Token | Explorer |
|-------|---------|---------|--------------|----------|
| solana | sol | mainnet-beta | SOL | Solana Explorer |
| solana-devnet | sol-devnet, devnet | devnet | SOL | Solana Explorer |

## Test Addresses

### EVM (Ethereum Mainnet)
- **WETH**: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- **USDC**: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- **Uniswap V2 Router**: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`

### Solana
- **Token Program**: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`
- **Marinade Finance (has IDL)**: `MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD`
- **Test Wallet**: `vines1vzrYbzLMRdu58ou5XTby4qAqVRLmqo36NKPTg`

## Troubleshooting

### "cast not found"
Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### "solana not found"
Install Solana CLI:
```bash
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
```

### "anchor not found"
Install Anchor CLI (requires Rust):
```bash
cargo install --git https://github.com/coral-xyz/anchor anchor-cli --locked
```

### "API key not configured"
Set the API key for contract source fetching:
```bash
export ETHERSCAN_API_KEY="your-key"
```

### Rate Limiting
If you hit rate limits with public fallback endpoints:
- Configure your own RPC endpoints (see Environment Variables)
- Use providers like Alchemy, Infura, QuickNode, or Helius
- Upgrade to a paid API plan for production use

## License

MIT
