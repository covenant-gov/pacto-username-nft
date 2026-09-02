// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice Test harness exposing paymaster validation
contract PactoGlobalPaymasterHarness is PactoGlobalPaymaster {
  /// @notice Deploys the harness with the same wiring as the production paymaster
  constructor(
    IEntryPoint entryPoint,
    IPactoUsernameNFT usernameNft,
    IGlobalSponsorPool pool,
    ISponsorPolicy defaultPolicy,
    address allowed7702Implementation
  ) PactoGlobalPaymaster(entryPoint, usernameNft, pool, defaultPolicy, allowed7702Implementation) {}

  /// @notice Exposes internal paymaster validation for unit tests
  /// @param userOp The packed user operation
  /// @param maxCost The maximum gas cost
  /// @return context The validation context bytes
  /// @return validationData The validation data word
  function exposedValidate(
    PackedUserOperation calldata userOp,
    uint256 maxCost
  ) external returns (bytes memory context, uint256 validationData) {
    return _validatePaymasterUserOp(userOp, bytes32(0), maxCost);
  }
}
