// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Pro-rata share accounting exposed by sponsor ETH vaults
interface IShareVault {
  /// @notice Returns total sponsor shares outstanding
  /// @return shares The share supply
  function totalShares() external view returns (uint256 shares);

  /// @notice Returns sponsor shares for an account
  /// @param sponsor The depositor address
  /// @return shares The sponsor share balance
  function sponsorShares(address sponsor) external view returns (uint256 shares);

  /// @notice Returns the wei available to spend on sponsorship
  /// @return amount The spendable pool balance
  function spendablePoolWei() external view returns (uint256 amount);
}
