// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @notice Test harness exposing paymaster validation and postOp billing
contract PactoGlobalPaymasterHarness is PactoGlobalPaymaster {
  /// @notice Deploys the harness with the same wiring as the production paymaster
  constructor(IEntryPoint entryPoint, IPactoProtocolRegistry registry) PactoGlobalPaymaster(entryPoint, registry) {}

  /// @notice Exposes internal paymaster validation for unit tests
  function exposedValidate(
    PackedUserOperation calldata userOp,
    uint256 maxCost
  ) external returns (bytes memory context, uint256 validationData) {
    return _validatePaymasterUserOp(userOp, bytes32(0), maxCost);
  }

  /// @notice Exposes internal postOp billing for unit tests
  function exposedPostOp(IPaymaster.PostOpMode mode, bytes calldata context, uint256 actualGasCost) external {
    _postOp(mode, context, actualGasCost, 0);
  }
}
