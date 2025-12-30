---
name: tx-info
description: Use this skill when the user asks for "transaction details", "show me tx", "what happened in this transaction", "look up transaction", or mentions viewing transaction data on blockchain. Requires a transaction hash and optional chain parameter.
allowed-tools: Bash
---

# Transaction Info Fetcher

Gets detailed information about a blockchain transaction.

## Usage

Run the script with transaction hash and chain:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-tx-info.sh <tx_hash> [chain]
```

## Arguments

- `tx_hash` (required): Transaction hash (0x + 64 hex characters)
- `chain` (optional): Chain name - ethereum (default), polygon, arbitrum, optimism, base, bsc

## Supported Chains

| Chain | Aliases | Explorer |
|-------|---------|----------|
| ethereum | eth, mainnet | Etherscan |
| polygon | matic | Polygonscan |
| arbitrum | arb | Arbiscan |
| optimism | op | Optimism Etherscan |
| base | - | Basescan |
| bsc | binance | BSCScan |

## Requirements

- `cast` (Foundry) must be installed
- RPC URL must be set for the target chain

## Examples

```bash
# Get transaction on Ethereum
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-tx-info.sh 0x1234567890abcdef...

# Get transaction on Polygon
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-tx-info.sh 0x1234567890abcdef... polygon
```
