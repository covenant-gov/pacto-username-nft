// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Protocol ETH vault for sponsored username NFT bootstrap mints
interface IBootstrapMintPool {
  /// @notice Emitted when ETH is deposited into the pool
  event Deposited(address indexed sponsor, uint256 amount, uint256 shares);

  /// @notice Emitted when a sponsor withdraws their share
  event Withdrawn(address indexed sponsor, uint256 amount, uint256 shares);

  /// @notice Emitted when gas is spent from the pool
  event GasSpent(address indexed paymaster, uint256 amount);

  /// @notice Emitted when the paymaster address is wired
  event PaymasterWired(address indexed paymaster);

  /// @notice Returns the wired paymaster address
  function paymaster() external view returns (address paymasterAddress);

  /// @notice Returns total sponsor shares outstanding
  function totalShares() external view returns (uint256 shares);

  /// @notice Returns sponsor shares for an account
  /// @param sponsor The depositor address
  /// @return shares The sponsor share balance
  function sponsorShares(address sponsor) external view returns (uint256 shares);

  /// @notice Returns the pool wei available for bootstrap mint sponsorship
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

  /// @notice Wires the paymaster address once at system bootstrap
  /// @param paymasterAddress The global paymaster address
  function wirePaymaster(address paymasterAddress) external;
}
