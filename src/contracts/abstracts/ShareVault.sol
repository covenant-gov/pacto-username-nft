// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IShareVault} from 'interfaces/IShareVault.sol';
import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';

/// @notice Shared pro-rata share accounting for sponsor ETH vaults
abstract contract ShareVault is IShareVault {
  /// @inheritdoc IShareVault
  uint256 public override totalShares;

  /// @inheritdoc IShareVault
  mapping(address sponsor => uint256 shares) public override sponsorShares;

  /// @inheritdoc IShareVault
  uint256 public override spendablePoolWei;

  /// @notice Mints pro-rata shares and credits the deposited wei
  /// @param sponsor The account receiving shares
  /// @param amount The wei amount being deposited
  /// @return shares The shares minted for this deposit
  function _mintDepositShares(address sponsor, uint256 amount) internal returns (uint256 shares) {
    if (amount == 0) revert ISponsorCommon.Sponsor_ZeroAmount();

    uint256 _balanceBefore = spendablePoolWei;
    if (totalShares != 0 && _balanceBefore != 0) {
      shares = (amount * totalShares) / _balanceBefore;
    } else {
      shares = amount;
    }

    sponsorShares[sponsor] += shares;
    totalShares += shares;
    spendablePoolWei = _balanceBefore + amount;
  }

  /// @notice Debits the spendable balance
  /// @param amount The wei amount to debit
  function _debitSpendable(uint256 amount) internal {
    if (amount > spendablePoolWei) revert ISponsorCommon.Sponsor_InsufficientBalance();
    spendablePoolWei -= amount;
  }
}
