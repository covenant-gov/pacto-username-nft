// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Protocol-wide ETH vault for global username sponsorship
interface IGlobalSponsorPool {
  /// @notice Emitted when ETH is deposited into the pool
  event Deposited(address indexed sponsor, uint256 amount, uint256 shares);

  /// @notice Emitted when a sponsor withdraws their share
  event Withdrawn(address indexed sponsor, uint256 amount, uint256 shares);

  /// @notice Emitted when gas is spent from the pool
  event GasSpent(address indexed paymaster, uint256 amount);

  /// @notice Returns the live paymaster address from the protocol registry
  function paymaster() external view returns (address paymasterAddress);

  /// @notice Returns total sponsor shares outstanding
  function totalShares() external view returns (uint256 shares);

  /// @notice Returns sponsor shares for an account
  /// @param sponsor The depositor address
  /// @return shares The sponsor share balance
  function sponsorShares(address sponsor) external view returns (uint256 shares);

  /// @notice Returns the pool wei available for sponsorship
  function spendablePoolWei() external view returns (uint256 amount);

  /// @notice Returns withdrawable wei for a sponsor
  /// @param sponsor The depositor address
  /// @return amount The withdrawable wei amount
  function withdrawable(address sponsor) external view returns (uint256 amount);

  /// @notice Deposits ETH and mints pro-rata shares for the caller
  function deposit() external payable;

  /// @notice Deposits ETH and credits shares to a sponsor account
  /// @param sponsor The account receiving shares
  function depositFor(address sponsor) external payable;

  /// @notice Withdraws the caller's pro-rata share of the pool
  function withdraw() external;

  /// @notice Spends gas from the pool to reimburse the paymaster
  /// @param amount The wei amount to spend
  function spendGas(uint256 amount) external;
}
