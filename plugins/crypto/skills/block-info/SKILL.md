---
name: block-info
description: Use this skill when the user asks "block info", "what's in block", "latest block", "get block details", or mentions viewing block data on blockchain. Optional block number/tag and chain parameter.
allowed-tools: Bash
---

# Block Info Fetcher

Gets information about a blockchain block.

## Usage

Run the script with optional block and chain:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-block-info.sh [block] [chain]
```

## Arguments

- `block` (optional): Block number, hex, or tag (latest, pending, earliest, finalized, safe). Default: latest
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
# Get latest block on Ethereum
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-block-info.sh

# Get specific block
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-block-info.sh 18000000

# Get latest block on Polygon
${CLAUDE_PLUGIN_ROOT}/scripts/crypto-block-info.sh latest polygon
```
