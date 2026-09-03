// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Mutable protocol address book for alpha upgradeability
interface IPactoProtocolRegistry {
  /// @notice Live protocol contract addresses
  struct ProtocolAddresses {
    /// @notice Username NFT used for membership and claims
    address usernameNft;
    /// @notice Global ERC-4337 paymaster
    address paymaster;
    /// @notice Member-path sponsor pool
    address pool;
    /// @notice Bootstrap-claim sponsor pool
    address bootstrapPool;
    /// @notice Member-path sponsor policy registry
    address policy;
    /// @notice Bootstrap-claim sponsor policy
    address bootstrapPolicy;
    /// @notice ERC-4337 EntryPoint v0.7
    address entryPoint;
    /// @notice Allowlisted EIP-7702 account implementation (zero allowed)
    address allowed7702Implementation;
  }

  /// @notice Emitted when the installer writes the initial address book
  event ProtocolInitialized(ProtocolAddresses addresses);

  /// @notice Emitted when the username NFT address is updated
  event UsernameNftUpdated(address indexed usernameNft);

  /// @notice Emitted when the paymaster address is updated
  event PaymasterUpdated(address indexed paymaster);

  /// @notice Emitted when the global sponsor pool address is updated
  event PoolUpdated(address indexed pool);

  /// @notice Emitted when the bootstrap mint pool address is updated
  event BootstrapPoolUpdated(address indexed bootstrapPool);

  /// @notice Emitted when the member policy registry address is updated
  event PolicyUpdated(address indexed policy);

  /// @notice Emitted when the bootstrap claim policy address is updated
  event BootstrapPolicyUpdated(address indexed bootstrapPolicy);

  /// @notice Emitted when the EntryPoint address is updated
  event EntryPointUpdated(address indexed entryPoint);

  /// @notice Emitted when the allowlisted EIP-7702 implementation is updated
  event Allowed7702ImplementationUpdated(address indexed allowed7702Implementation);

  /// @notice Thrown when a required address is zero
  error ProtocolRegistry_ZeroAddress();

  /// @notice Thrown when the caller is not the installer
  error ProtocolRegistry_NotInstaller();

  /// @notice Thrown when initialize is called more than once
  error ProtocolRegistry_AlreadyInitialized();

  /// @notice Returns the one-time installer allowed to call initialize
  function INSTALLER() external view returns (address installerAddress);

  /// @notice Returns whether initialize has been called
  function initialized() external view returns (bool isInitialized);

  /// @notice Returns the live username NFT address
  function usernameNft() external view returns (address usernameNftAddress);

  /// @notice Returns the live paymaster address
  function paymaster() external view returns (address paymasterAddress);

  /// @notice Returns the live global sponsor pool address
  function pool() external view returns (address poolAddress);

  /// @notice Returns the live bootstrap mint pool address
  function bootstrapPool() external view returns (address bootstrapPoolAddress);

  /// @notice Returns the live member policy registry address
  function policy() external view returns (address policyAddress);

  /// @notice Returns the live bootstrap claim policy address
  function bootstrapPolicy() external view returns (address bootstrapPolicyAddress);

  /// @notice Returns the recorded EntryPoint address
  function entryPoint() external view returns (address entryPointAddress);

  /// @notice Returns the recorded EIP-7702 allowlist address
  function allowed7702Implementation() external view returns (address allowed7702);

  /// @notice Writes the initial protocol address book
  /// @param addresses The initial protocol addresses
  function initialize(ProtocolAddresses calldata addresses) external;

  /// @notice Updates the username NFT address
  /// @param usernameNftAddress The new username NFT
  function setUsernameNft(address usernameNftAddress) external;

  /// @notice Updates the paymaster address
  /// @param paymasterAddress The new paymaster
  function setPaymaster(address paymasterAddress) external;

  /// @notice Updates the global sponsor pool address
  /// @param poolAddress The new global sponsor pool
  function setPool(address poolAddress) external;

  /// @notice Updates the bootstrap mint pool address
  /// @param bootstrapPoolAddress The new bootstrap mint pool
  function setBootstrapPool(address bootstrapPoolAddress) external;

  /// @notice Updates the member policy registry address
  /// @param policyAddress The new member policy registry
  function setPolicy(address policyAddress) external;

  /// @notice Updates the bootstrap claim policy address
  /// @param bootstrapPolicyAddress The new bootstrap claim policy
  function setBootstrapPolicy(address bootstrapPolicyAddress) external;

  /// @notice Updates the recorded EntryPoint address
  /// @param entryPointAddress The new EntryPoint
  function setEntryPoint(address entryPointAddress) external;

  /// @notice Updates the recorded EIP-7702 allowlist address
  /// @param allowed7702 The new allowlisted implementation
  function setAllowed7702Implementation(address allowed7702) external;
}
