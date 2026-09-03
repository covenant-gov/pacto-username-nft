// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Mutable protocol address book for alpha upgradeability
interface IPactoProtocolRegistry {
  /// @notice Protocol address-book slots that can be updated via set
  /// @param UsernameNft Username NFT used for membership and claims
  /// @param Paymaster Global ERC-4337 paymaster
  /// @param Pool Member-path sponsor pool
  /// @param BootstrapPool Bootstrap-claim sponsor pool
  /// @param Policy Member-path sponsor policy registry
  /// @param BootstrapPolicy Bootstrap-claim sponsor policy
  /// @param EntryPoint ERC-4337 EntryPoint v0.7
  /// @param Allowed7702Implementation Allowlisted EIP-7702 account implementation
  enum ProtocolComponent {
    UsernameNft,
    Paymaster,
    Pool,
    BootstrapPool,
    Policy,
    BootstrapPolicy,
    EntryPoint,
    Allowed7702Implementation
  }

  /// @notice Live protocol contract addresses
  /// @param usernameNft Username NFT used for membership and claims
  /// @param paymaster Global ERC-4337 paymaster
  /// @param pool Member-path sponsor pool
  /// @param bootstrapPool Bootstrap-claim sponsor pool
  /// @param policy Member-path sponsor policy registry
  /// @param bootstrapPolicy Bootstrap-claim sponsor policy
  /// @param entryPoint ERC-4337 EntryPoint v0.7
  /// @param allowed7702Implementation Allowlisted EIP-7702 account implementation (zero allowed)
  struct ProtocolAddresses {
    address usernameNft;
    address paymaster;
    address pool;
    address bootstrapPool;
    address policy;
    address bootstrapPolicy;
    address entryPoint;
    address allowed7702Implementation;
  }

  /// @notice Emitted when the installer writes the initial address book
  event ProtocolInitialized(ProtocolAddresses addresses);

  /// @notice Emitted when any protocol address-book slot is updated
  event ProtocolAddressUpdated(ProtocolComponent indexed component, address indexed addr);

  /// @notice Thrown when a required address is zero
  error ProtocolRegistry_ZeroAddress();

  /// @notice Thrown when the caller is not the installer
  error ProtocolRegistry_NotInstaller();

  /// @notice Thrown when initialize is called more than once
  error ProtocolRegistry_AlreadyInitialized();

  /// @notice Thrown when set receives an unrecognized component
  error ProtocolRegistry_InvalidComponent();

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

  /// @notice Updates a single protocol address-book slot
  /// @param component The slot to update
  /// @param addr The new address (zero allowed only for Allowed7702Implementation)
  function set(ProtocolComponent component, address addr) external;
}
