// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice Test harness exposing paymaster validation and postOp billing
contract PactoGlobalPaymasterHarness is PactoGlobalPaymaster {
  /// @notice Deploys the harness with the same wiring as the production paymaster
  constructor(
    IEntryPoint entryPoint,
    IPactoUsernameNFT usernameNft,
    IGlobalSponsorPool pool,
    IBootstrapMintPool bootstrapPool,
    ISponsorPolicy defaultPolicy,
    ISponsorPolicy bootstrapPolicy,
    address allowed7702Implementation
  )
    PactoGlobalPaymaster(
      entryPoint, usernameNft, pool, bootstrapPool, defaultPolicy, bootstrapPolicy, allowed7702Implementation
    )
  {}

  /// @notice Exposes internal paymaster validation for unit tests
  function exposedValidate(
    PackedUserOperation calldata userOp,
    uint256 maxCost
  ) external returns (bytes memory context, uint256 validationData) {
    return _validatePaymasterUserOp(userOp, bytes32(0), maxCost);
  }

  /// @notice Exposes internal postOp billing for unit tests
  function exposedPostOp(
    IPaymaster.PostOpMode mode,
    bytes calldata context,
    uint256 actualGasCost
  ) external {
    _postOp(mode, context, actualGasCost, 0);
  }
}
