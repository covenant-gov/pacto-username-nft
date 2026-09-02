// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

/// @notice Minimal EntryPoint stub for paymaster unit tests
contract MockEntryPoint is IERC165 {
  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) external pure returns (bool supported) {
    return interfaceId == type(IEntryPoint).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
