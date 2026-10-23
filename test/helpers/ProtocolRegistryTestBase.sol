// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {Test} from 'forge-std/Test.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';
import {MockProtocolPaymaster} from 'test/mocks/MockProtocolPaymaster.sol';

/// @notice Shared helpers for wiring a protocol registry in tests
abstract contract ProtocolRegistryTestBase is Test {
  /// @notice Initializes a registry with a coherent mock paymaster bundle
  function _initializeRegistry(
    PactoProtocolRegistry registry,
    address usernameNft,
    address paymaster,
    address pool,
    address bootstrapPool,
    address policy,
    address bootstrapPolicy,
    address entryPoint,
    address allowed7702
  ) internal {
    registry.initialize(
      IPactoProtocolRegistry.ProtocolAddresses({
        usernameNft: usernameNft,
        paymaster: paymaster,
        pool: pool,
        bootstrapPool: bootstrapPool,
        policy: policy,
        bootstrapPolicy: bootstrapPolicy,
        entryPoint: entryPoint,
        allowed7702Implementation: allowed7702,
        eip7702Enabled: allowed7702 != address(0)
      })
    );
  }

  /// @notice Deploys a mock paymaster whose getters match the supplied bundle
  function _deployMockPaymaster(
    PactoProtocolRegistry registry,
    address usernameNft,
    address pool,
    address bootstrapPool,
    address policy,
    address bootstrapPolicy,
    address entryPoint,
    address allowed7702
  ) internal returns (MockProtocolPaymaster mockPaymaster) {
    mockPaymaster = new MockProtocolPaymaster(
      registry,
      IPactoUsernameNFT(usernameNft),
      ISponsorPolicy(policy),
      ISponsorPolicy(bootstrapPolicy),
      IGlobalSponsorPool(pool),
      IBootstrapMintPool(bootstrapPool),
      IEntryPoint(entryPoint),
      allowed7702
    );
  }
}
