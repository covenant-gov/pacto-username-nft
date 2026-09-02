// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Shared errors for username NFT sponsor contracts
interface ISponsorCommon {
  /// @notice Thrown when a required address is zero
  error Sponsor_ZeroAddress();

  /// @notice Thrown when a required amount is zero
  error Sponsor_ZeroAmount();

  /// @notice Thrown when an ETH transfer fails
  error Sponsor_TransferFailed();

  /// @notice Thrown when the caller is not the paymaster
  error Sponsor_NotPaymaster();

  /// @notice Thrown when the caller is not the factory
  error Sponsor_NotFactory();

  /// @notice Thrown when a one-time initializer was already called
  error Sponsor_AlreadyInitialized();

  /// @notice Thrown when the pool balance is insufficient
  error Sponsor_InsufficientBalance();

  /// @notice Thrown when a sponsor has no shares to withdraw
  error Sponsor_NoShares();
}
