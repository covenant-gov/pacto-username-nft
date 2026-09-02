// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';

/// @notice Shared ETH send helper for sponsor contracts
library ETHTransfer {
  /// @notice Sends ETH to a recipient and reverts on failure
  /// @param to The recipient address
  /// @param amount The wei amount to send
  function sendEth(address to, uint256 amount) internal {
    (bool _ok,) = to.call{value: amount}('');
    if (!_ok) revert ISponsorCommon.Sponsor_TransferFailed();
  }
}
