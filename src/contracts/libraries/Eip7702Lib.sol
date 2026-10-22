// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice EIP-7702 delegation-designation helpers
library Eip7702Lib {
  /// @notice Designated-code length, including the implementation address
  uint256 internal constant _CODE_LENGTH = 23;

  /// @notice Designated-code magic prefix
  bytes3 internal constant _PREFIX = 0xef0100;

  /// @notice Returns true when code is an EIP-7702 delegation stub
  /// @param code The account bytecode
  /// @return delegation Whether the code matches the designated format
  function isDelegation(bytes memory code) internal pure returns (bool delegation) {
    delegation = code.length == _CODE_LENGTH && bytes3(code) == _PREFIX;
  }

  /// @notice Extracts the implementation address from an EIP-7702 delegation stub
  /// @param code The 23-byte designated code
  /// @return delegatedTo The delegated implementation address
  function implementation(bytes memory code) internal pure returns (address delegatedTo) {
    assembly ('memory-safe') {
      delegatedTo := shr(96, mload(add(code, 35)))
    }
  }
}
