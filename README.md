# Meme Token Launch Platform

A decentralized platform for launching and trading meme tokens built with Solidity and Foundry.

## Features

- **Token Factory**: Deploy new meme tokens using minimal proxy pattern for gas efficiency
- **Automated Minting**: Users can mint tokens by paying ETH
- **Fee Distribution**: 1% platform fee, 99% to token creator
- **Supply Management**: Configurable total supply and per-mint amounts
- **Ownership**: Token creators maintain ownership of their tokens

## Architecture

### MemeFactory.sol
The main factory contract that:
- Deploys new meme tokens using OpenZeppelin's Clones library
- Manages token information and metadata
- Handles minting transactions and fee distribution
- Provides query functions for deployed tokens

### MemeToken.sol
ERC20 token implementation that:
- Uses minimal proxy pattern for gas-efficient deployment
- Supports configurable supply limits and minting amounts
- Integrates with factory for controlled minting
- Maintains creator ownership

## Usage

### Deploying a Meme Token

```solidity
// Deploy a new meme token
address tokenAddress = factory.deployMeme(
    "PEPE",           // symbol
    1000000 * 1e18,   // total supply (1M tokens)
    1000 * 1e18,      // per mint amount (1K tokens)
    1e15              // price per token unit (in wei)
);
```

### Minting Tokens

```solidity
// Calculate required payment
(uint256 totalCost, uint256 projectFee, uint256 creatorFee) = 
    factory.getMintingCost(tokenAddress);

// Mint tokens by sending ETH
factory.mintMeme{value: totalCost}(tokenAddress);
```

### Querying Information

```solidity
// Get token information
MemeFactory.TokenInfo memory info = factory.getTokenInfo(tokenAddress);

// Get all deployed tokens
address[] memory allTokens = factory.getAllDeployedTokens();

// Check remaining supply
uint256 remaining = MemeToken(tokenAddress).remainingSupply();
```

## Development

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Git](https://git-scm.com/)

### Installation

```bash
git clone <repository-url>
cd foundry_meme
forge install
```

### Testing

```bash
# Run all tests
forge test

# Run specific test with verbose output
forge test --match-test testMintMeme -vvv

# Run tests with gas reporting
forge test --gas-report
```

### Deployment

1. Set environment variables:
```bash
export PRIVATE_KEY=your_private_key
export PROJECT_WALLET=0x...  # Address to receive platform fees
```

2. Deploy to local network:
```bash
forge script script/DeployMemeFactory.s.sol --rpc-url http://localhost:8545 --broadcast
```

3. Deploy to testnet:
```bash
forge script script/DeployMemeFactory.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Contract Addresses

### Testnet (Sepolia)
- MemeFactory: `TBD`
- MemeToken Implementation: `TBD`

### Mainnet
- MemeFactory: `TBD`
- MemeToken Implementation: `TBD`

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks on minting
- **Access Control**: Only factory can mint tokens
- **Input Validation**: Comprehensive parameter validation
- **Safe Transfers**: Uses low-level calls with success checks
- **Overflow Protection**: Solidity 0.8+ built-in overflow protection

## Fee Structure

- **Platform Fee**: 1% of minting cost goes to project wallet
- **Creator Fee**: 99% of minting cost goes to token creator
- **Gas Optimization**: Minimal proxy pattern reduces deployment costs by ~90%

## Testing Coverage

The platform includes comprehensive tests covering:
- Token deployment with various parameters
- Minting functionality and edge cases
- Fee distribution and calculations
- Access control and security
- Supply management and limits
- Error handling and validation

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Disclaimer

This software is provided as-is for educational and development purposes. Use at your own risk. Always audit smart contracts before deploying to mainnet.
