// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Paymaster pool-balance headroom against EntryPoint maxCost
library PaymasterHeadroomLib {
  /// @notice Required balance as a fraction of maxCost, in basis points (115%)
  uint256 internal constant _HEADROOM_BPS = 11_500;

  /// @notice Wei the pool must hold to cover maxCost plus headroom
  /// @param maxCost The EntryPoint maximum cost for the user operation
  /// @return required The required spendable balance
  function requiredWei(uint256 maxCost) internal pure returns (uint256 required) {
    required = (maxCost * _HEADROOM_BPS) / 10_000;
  }
}
