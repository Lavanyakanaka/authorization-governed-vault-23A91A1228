// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AuthorizationManager.sol";

/**
 * @title SecureVault
 * @notice Holds funds and executes withdrawals only after authorization validation
 * @dev Uses AuthorizationManager for permission verification
 */
contract SecureVault {
    // Reference to the authorization manager contract
    AuthorizationManager public authorizationManager;
    
    // Total balance tracked internally
    uint256 public totalBalance;
    
    // Track individual balances if needed
    mapping(address => uint256) public balances;
    
    // Initialization flag to prevent re-initialization
    bool private initialized;
    
    // Events for observability
    event Deposit(
        address indexed depositor,
        uint256 amount,
        uint256 timestamp
    );
    
    event Withdrawal(
        address indexed recipient,
        uint256 amount,
        uint256 authorizationId,
        uint256 timestamp
    );
    
    event WithdrawalFailed(
        address indexed recipient,
        uint256 amount,
        string reason
    );
    
    event Initialized(address indexed authorizationManager);
    
    /**
     * @notice Initialize the vault with authorization manager address
     * @param _authorizationManager Address of the deployed AuthorizationManager
     * @dev Can only be called once
     */
    function initialize(address _authorizationManager) external {
        require(!initialized, "Already initialized");
        require(_authorizationManager != address(0), "Invalid address");
        
        authorizationManager = AuthorizationManager(_authorizationManager);
        initialized = true;
        
        emit Initialized(_authorizationManager);
    }
    
    /**
     * @notice Accept deposits of native currency
     * @dev Automatically callable via receive() or send() function
     */
    receive() external payable {
        require(msg.value > 0, "Invalid deposit amount");
        
        totalBalance += msg.value;
        balances[msg.sender] += msg.value;
        
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @notice Withdraw funds after authorization validation
     * @param recipient Address to receive the withdrawn funds
     * @param amount Amount to withdraw
     * @param authorizationId Unique authorization identifier
     * @param signature Off-chain generated signature bytes
     */
    function withdraw(
        address payable recipient,
        uint256 amount,
        uint256 authorizationId,
        bytes calldata signature
    ) external {
        require(initialized, "Vault not initialized");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(totalBalance >= amount, "Insufficient balance");
        
        // Request authorization validation from the manager
        bool authorized = authorizationManager.verifyAuthorization(
            address(this),
            recipient,
            amount,
            authorizationId,
            signature
        );
        
        if (!authorized) {
            emit WithdrawalFailed(recipient, amount, "Authorization failed");
            revert("Withdrawal not authorized");
        }
        
        // Update state BEFORE transferring funds (checks-effects-interactions pattern)
        totalBalance -= amount;
        
        // Transfer funds to recipient
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        
        // Emit withdrawal event for observability
        emit Withdrawal(recipient, amount, authorizationId, block.timestamp);
    }
    
    /**
     * @notice Get the current vault balance
     * @return Current balance in wei
     */
    function getBalance() external view returns (uint256) {
        return totalBalance;
    }
    
    /**
     * @notice Check if vault is properly initialized
     * @return Initialization status
     */
    function isInitialized() external view returns (bool) {
        return initialized;
    }
}
