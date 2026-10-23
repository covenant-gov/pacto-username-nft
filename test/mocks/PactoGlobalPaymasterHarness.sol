// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {PactoGlobalPaymaster} from 'contracts/PactoGlobalPaymaster.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice Test harness exposing paymaster validation and postOp billing
contract PactoGlobalPaymasterHarness is PactoGlobalPaymaster {
  /// @notice Deploys the harness with the same wiring as the production paymaster
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param registry The protocol registry for this generation
  /// @param usernameNft The username NFT used for membership
  /// @param policy The member-path sponsor policy
  /// @param bootstrapPolicy The bootstrap-claim sponsor policy
  /// @param pool The member-path sponsor pool
  /// @param bootstrapPool The bootstrap-claim sponsor pool
  /// @param allowed7702 The allowlisted EIP-7702 account implementation
  constructor(
    IEntryPoint entryPoint,
    IPactoProtocolRegistry registry,
    IPactoUsernameNFT usernameNft,
    ISponsorPolicy policy,
    ISponsorPolicy bootstrapPolicy,
    IGlobalSponsorPool pool,
    IBootstrapMintPool bootstrapPool,
    address allowed7702
  )
    PactoGlobalPaymaster(entryPoint, registry, usernameNft, policy, bootstrapPolicy, pool, bootstrapPool, allowed7702)
  {}

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
