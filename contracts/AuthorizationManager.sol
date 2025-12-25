// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AuthorizationManager
 * @notice Validates withdrawal permissions and tracks authorization usage
 * @dev Ensures each authorization is consumed exactly once
 */
contract AuthorizationManager {
    // Maps authorization hash to consumed status
    mapping(bytes32 => bool) public usedAuthorizations;
    
    // Event emitted when authorization is consumed
    event AuthorizationConsumed(
        bytes32 indexed authorizationHash,
        address indexed vault,
        address indexed recipient,
        uint256 amount
    );

    // Event emitted when authorization verification fails
    event AuthorizationFailed(
        bytes32 indexed authorizationHash,
        string reason
    );

    /**
     * @notice Verifies if a withdrawal authorization is valid and marks it as consumed
     * @param vault Address of the vault contract
     * @param recipient Address to receive the funds
     * @param amount Amount to withdraw
     * @param authorizationId Unique authorization identifier
     * @param signature Off-chain generated signature bytes
     * @return true if authorization is valid and not yet consumed
     */
    function verifyAuthorization(
        address vault,
        address recipient,
        uint256 amount,
        uint256 authorizationId,
        bytes calldata signature
    ) external returns (bool) {
        // Create deterministic message hash encoding all parameters
        bytes32 authHash = keccak256(
            abi.encodePacked(
                vault,
                recipient,
                amount,
                authorizationId,
                block.chainid
            )
        );

        // Check if authorization has already been used
        if (usedAuthorizations[authHash]) {
            emit AuthorizationFailed(authHash, "Authorization already consumed");
            return false;
        }

        // Verify signature (basic validation - in production, use proper ECDSA)
        if (signature.length == 0) {
            emit AuthorizationFailed(authHash, "Invalid signature");
            return false;
        }

        // Mark authorization as consumed to prevent reuse
        usedAuthorizations[authHash] = true;

        // Emit success event for observability
        emit AuthorizationConsumed(authHash, vault, recipient, amount);
        return true;
    }

    /**
     * @notice Checks if an authorization has been used
     * @param vault Address of the vault contract
     * @param recipient Address to receive the funds
     * @param amount Amount to withdraw
     * @param authorizationId Unique authorization identifier
     * @return true if authorization has been consumed
     */
    function isAuthorizationUsed(
        address vault,
        address recipient,
        uint256 amount,
        uint256 authorizationId
    ) external view returns (bool) {
        bytes32 authHash = keccak256(
            abi.encodePacked(
                vault,
                recipient,
                amount,
                authorizationId,
                block.chainid
            )
        );
        return usedAuthorizations[authHash];
    }
}
