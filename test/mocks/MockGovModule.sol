// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Minimal gov module target for sponsorship integration tests
contract MockGovModule {
  uint256 public value;

  /// @notice Updates stored state
  /// @param newValue The value to store
  function setValue(uint256 newValue) external {
    value = newValue;
  }
}
