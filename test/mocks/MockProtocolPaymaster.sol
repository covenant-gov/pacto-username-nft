// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice Minimal paymaster getter bundle for registry coherence tests
contract MockProtocolPaymaster {
  /// @notice Protocol registry this mock claims to belong to
  IPactoProtocolRegistry public immutable REGISTRY;

  /// @notice Username NFT this mock pins
  IPactoUsernameNFT public immutable USERNAME_NFT;

  /// @notice Member-path policy this mock pins
  ISponsorPolicy public immutable POLICY;

  /// @notice Bootstrap-path policy this mock pins
  ISponsorPolicy public immutable BOOTSTRAP_POLICY;

  /// @notice Member-path pool this mock pins
  IGlobalSponsorPool public immutable POOL;

  /// @notice Bootstrap-path pool this mock pins
  IBootstrapMintPool public immutable BOOTSTRAP_POOL;

  /// @notice EntryPoint this mock pins
  IEntryPoint public immutable entryPoint;

  /// @notice EIP-7702 implementation this mock pins
  address public immutable ALLOWED_7702_IMPLEMENTATION;

  /// @notice Stores a coherent paymaster getter bundle
  /// @param registry_ The protocol registry
  /// @param usernameNft The username NFT
  /// @param policy_ The member-path policy
  /// @param bootstrapPolicy The bootstrap-path policy
  /// @param pool_ The member-path pool
  /// @param bootstrapPool The bootstrap-path pool
  /// @param entryPoint_ The EntryPoint
  /// @param allowed7702 The EIP-7702 implementation
  constructor(
    IPactoProtocolRegistry registry_,
    IPactoUsernameNFT usernameNft,
    ISponsorPolicy policy_,
    ISponsorPolicy bootstrapPolicy,
    IGlobalSponsorPool pool_,
    IBootstrapMintPool bootstrapPool,
    IEntryPoint entryPoint_,
    address allowed7702
  ) {
    REGISTRY = registry_;
    USERNAME_NFT = usernameNft;
    POLICY = policy_;
    BOOTSTRAP_POLICY = bootstrapPolicy;
    POOL = pool_;
    BOOTSTRAP_POOL = bootstrapPool;
    entryPoint = entryPoint_;
    ALLOWED_7702_IMPLEMENTATION = allowed7702;
  }

  /// @notice Accepts ETH forwarded by sponsor pools during spendGas
  receive() external payable {}
}
