// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Protocol address book with atomic generation migration
interface IPactoProtocolRegistry {
  /// @notice Live protocol contract addresses for one coherent generation
  /// @param usernameNft Username NFT used for membership and claims
  /// @param paymaster Global ERC-4337 paymaster
  /// @param pool Member-path sponsor pool
  /// @param bootstrapPool Bootstrap-claim sponsor pool
  /// @param policy Member-path sponsor policy registry
  /// @param bootstrapPolicy Bootstrap-claim sponsor policy
  /// @param entryPoint ERC-4337 EntryPoint v0.7
  /// @param allowed7702Implementation Allowlisted EIP-7702 account implementation
  /// @param eip7702Enabled Whether EIP-7702 delegated senders are accepted
  struct ProtocolAddresses {
    address usernameNft;
    address paymaster;
    address pool;
    address bootstrapPool;
    address policy;
    address bootstrapPolicy;
    address entryPoint;
    address allowed7702Implementation;
    bool eip7702Enabled;
  }

  /// @notice Emitted when the installer writes the initial address book
  event ProtocolInitialized(ProtocolAddresses addresses);

  /// @notice Emitted when the owner migrates every address-book slot atomically
  event ProtocolMigrated(ProtocolAddresses addresses);

  /// @notice Emitted when the owner disables EIP-7702 sponsorship
  event Eip7702Disabled();

  /// @notice Thrown when a required address is zero
  error ProtocolRegistry_ZeroAddress();

  /// @notice Thrown when the caller is not the installer
  error ProtocolRegistry_NotInstaller();

  /// @notice Thrown when initialize is called more than once
  error ProtocolRegistry_AlreadyInitialized();

  /// @notice Thrown when migrate is called before initialize
  error ProtocolRegistry_NotInitialized();

  /// @notice Thrown when paymaster immutables do not match the address book
  error ProtocolRegistry_IncoherentBundle();

  /// @notice Thrown when EIP-7702 is enabled with a zero implementation
  error ProtocolRegistry_Invalid7702Config();

  /// @notice Thrown when disableEip7702 is called while already disabled
  error ProtocolRegistry_Eip7702AlreadyDisabled();

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

  /// @notice Returns whether EIP-7702 delegated senders are accepted
  function eip7702Enabled() external view returns (bool enabled);

  /// @notice Writes the initial protocol address book
  /// @param addresses The initial protocol addresses
  function initialize(ProtocolAddresses calldata addresses) external;

  /// @notice Atomically replaces every protocol address-book slot
  /// @param addresses The next coherent generation
  function migrate(ProtocolAddresses calldata addresses) external;

  /// @notice Disables EIP-7702 sponsorship for the current generation
  function disableEip7702() external;
}
