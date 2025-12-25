# Authorization-Governed Vault System

A secure multi-contract vault system that validates withdrawals through an external authorization manager. This implementation demonstrates secure smart contract architecture patterns where fund movement is restricted to only authorized transactions.

## Overview

### System Architecture

The system consists of two primary smart contracts:

1. **SecureVault** - Holds pooled funds and executes withdrawals
   - Accepts deposits via the `receive()` function
   - Validates withdrawals through the AuthorizationManager
   - Maintains internal accounting with state updates before fund transfers
   - Emits events for all deposit and withdrawal operations

2. **AuthorizationManager** - Validates and tracks withdrawal permissions
   - Verifies authorization uniqueness and validity
   - Prevents authorization reuse with consumed state tracking
   - Binds authorizations to specific vault, recipient, amount, and chain context

### Security Design

#### Separation of Concerns
- Vault holds no cryptographic logic; all signing validation delegated to AuthorizationManager
- Clear trust boundaries between contracts prevent coupling and reduce attack surface

#### Authorization Binding
Each authorization is deterministically bound to:
- Specific vault contract address
- Specific recipient address
- Specific withdrawal amount
- Unique authorization ID (nonce)
- Blockchain network (chain ID)

#### State Management
- Checks-effects-interactions pattern: state updated before fund transfers
- One-time consumption: used authorizations permanently marked as consumed
- No reentrancy vulnerabilities: state finalized before external calls

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git

### Installation & Deployment

```bash
# Clone the repository
git clone https://github.com/Lavanyakanaka/authorization-governed-vault-23A91A1228.git
cd authorization-governed-vault-23A91A1228

# Deploy using Docker Compose
docker-compose up
```

This will:
1. Start a local Hardhat blockchain node (port 8545)
2. Compile all smart contracts
3. Deploy AuthorizationManager
4. Deploy SecureVault
5. Initialize SecureVault with AuthorizationManager address
6. Write deployment details to `deployment.json`

### Deployment Output

After deployment completes, check `deployment.json` for:
```json
{
  "network": {
    "id": 31337,
    "name": "localhost",
    "timestamp": "2025-01-01T00:00:00.000Z"
  },
  "contracts": {
    "AuthorizationManager": {
      "address": "0x..."
    },
    "SecureVault": {
      "address": "0x...",
      "authorizationManagerAddress": "0x..."
    }
  },
  "deployer": "0x..."
}
```

## Contract Interfaces

### SecureVault

#### `receive() external payable`
Accepts deposits of native currency.
- **Event**: `Deposit(address indexed depositor, uint256 amount, uint256 timestamp)`

#### `initialize(address _authorizationManager) external`
Initializes the vault with the authorization manager address. Can only be called once.
- **Requirements**: Not already initialized, valid address
- **Event**: `Initialized(address indexed authorizationManager)`

#### `withdraw(address payable recipient, uint256 amount, uint256 authorizationId, bytes calldata signature) external`
Withdraws funds after authorization validation.
- **Requirements**: Vault initialized, valid recipient, valid amount, sufficient balance
- **Process**:
  1. Requests authorization verification from manager
  2. Updates internal balance before transfer
  3. Transfers funds to recipient
  4. Emits withdrawal event
- **Events**: `Withdrawal(...)` on success or `WithdrawalFailed(...)` on failure

#### `getBalance() external view returns (uint256)`
Returns current vault balance.

#### `isInitialized() external view returns (bool)`
Returns initialization status.

### AuthorizationManager

#### `verifyAuthorization(address vault, address recipient, uint256 amount, uint256 authorizationId, bytes calldata signature) external returns (bool)`
Verifies a withdrawal authorization and marks it as consumed.
- **Verification Steps**:
  1. Constructs deterministic authorization hash
  2. Checks if authorization has already been consumed
  3. Validates signature data
  4. Marks authorization as consumed
  5. Emits success or failure event
- **Events**: `AuthorizationConsumed(...)` on success or `AuthorizationFailed(...)` on failure

#### `isAuthorizationUsed(address vault, address recipient, uint256 amount, uint256 authorizationId) external view returns (bool)`
Checks if an authorization has been consumed.

## Authorization Flow

### Off-Chain: Generate Authorization

```javascript
const ethers = require('ethers');

// Parameters
const vaultAddress = '0x...';
const recipientAddress = '0x...';
const withdrawAmount = ethers.utils.parseEther('1.0');
const authorizationId = 1;  // Unique nonce
const chainId = 31337;  // From deployment.json

// Construct message
const messageData = ethers.utils.solidityPack(
  ['address', 'address', 'uint256', 'uint256', 'uint256'],
  [vaultAddress, recipientAddress, withdrawAmount, authorizationId, chainId]
);

const messageHash = ethers.utils.keccak256(messageData);

// Sign with private key (in production, use proper signing mechanisms)
const signature = await signer.signMessage(ethers.utils.arrayify(messageHash));
```

### On-Chain: Execute Withdrawal

```javascript
const vault = new ethers.Contract(
  vaultAddress,
  SecureVaultABI,
  signer
);

// Call withdraw with generated authorization
const tx = await vault.withdraw(
  recipientAddress,
  withdrawAmount,
  authorizationId,
  signature
);

await tx.wait();
console.log('Withdrawal completed:', tx.transactionHash);
```

## Testing & Validation

### Manual Validation Steps

1. **Test Deposit**
```bash
# Send 1 ETH to vault
cast send <VAULT_ADDRESS> --value 1ether --rpc-url http://localhost:8545

# Check balance
cast call <VAULT_ADDRESS> "getBalance()" --rpc-url http://localhost:8545
```

2. **Test Withdrawal (Success Case)**
```bash
# Generate authorization and call withdraw()
# Should emit Withdrawal event
```

3. **Test Withdrawal (Reuse Prevention)**
```bash
# Attempt to reuse same authorization ID
# Should revert with "Authorization already consumed"
```

4. **Test Withdrawal (Invalid Authorization)**
```bash
# Call withdraw with invalid signature
# Should revert with "Withdrawal not authorized"
```

## Key Security Properties

✓ **No Double Spending**: Each authorization consumed exactly once  
✓ **Cross-Chain Safety**: Chain ID bound to authorization hash  
✓ **Reentrancy Safe**: State updates before external calls  
✓ **Network Isolation**: Authorizations non-transferable between chains  
✓ **Parameter Binding**: Amount, recipient, vault all verified  
✓ **Initialization Guard**: Vault setup only once  
✓ **Clear Observability**: All state changes emit events  

## Project Structure

```
.
├── contracts/
│   ├── AuthorizationManager.sol    # Authorization validator
│   └── SecureVault.sol             # Fund custody contract
├── scripts/
│   └── deploy.js                   # Deployment automation
├── docker-compose.yml              # Local environment setup
├── hardhat.config.js               # Hardhat configuration
├── package.json                    # Dependencies
└── README.md                       # This file
```

## Development Notes

### Extending the System

- **Signature Verification**: Replace basic signature check with proper ECDSA verification
- **Multi-Signature Support**: Add support for m-of-n authorization
- **Time Locks**: Add expiration times to authorizations
- **Tiered Withdrawal Limits**: Implement per-recipient or time-based limits
- **Batch Operations**: Support withdrawing to multiple recipients in single transaction

### Gas Optimization

- Authorization hash computation is deterministic and efficient
- Single state write per withdrawal (no redundant updates)
- Event indexing enables off-chain authorization tracking

## Compliance & Standards

- **Solidity Version**: ^0.8.19
- **License**: MIT
- **Pattern**: Checks-Effects-Interactions
- **Code Comments**: Comprehensive inline documentation

## Troubleshooting

**Deployment fails with "already initialized"**
- Another deployment is in progress. Wait for completion and verify `deployment.json`

**Withdrawal reverts with "Insufficient balance"**
- Deposit more funds to the vault using `receive()` function

**Authorization verification fails**
- Verify authorization hash matches: `keccak256(abi.encodePacked(vault, recipient, amount, id, chainId))`
- Ensure signature is from authorized signer
- Check authorization hasn't been consumed previously

## Support & Contribution

For issues, questions, or improvements, please open an issue on GitHub.

---

**Deployed by**: Lavanya Kanaka  
**Task**: Create an Authorization-Governed Vault System for Controlled Asset Withdrawals  
**Network**: Localhost (Hardhat Node)  
**Date**: 2025
