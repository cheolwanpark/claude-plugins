---
name: address-info
description: Use this skill when the user asks to "check balance", "what's the balance of", "is this a contract or EOA", "get address info", or mentions checking wallet balance or account type on blockchain. Requires an address and optional chain parameter.
allowed-tools: Bash
---

# Address Info Fetcher

Gets balance and account type (EOA vs contract) for an Ethereum address.

## Usage

Run the script with address and chain:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-address-info.sh <address> [chain]
```

## Arguments

- `address` (required): Wallet/contract address (0x...) or ENS name
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
- RPC URL must be set for the target chain:
  - `ETHEREUM_RPC_URL` for Ethereum
  - `POLYGON_RPC_URL` for Polygon
  - `ARBITRUM_RPC_URL` for Arbitrum
  - `OPTIMISM_RPC_URL` for Optimism
  - `BASE_RPC_URL` for Base
  - `BSC_RPC_URL` for BSC

## Examples

```bash
# Check vitalik.eth balance on Ethereum
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-address-info.sh vitalik.eth

# Check address on Arbitrum
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-address-info.sh 0x1234567890123456789012345678901234567890 arbitrum
```
