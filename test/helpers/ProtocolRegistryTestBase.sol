// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {Test} from 'forge-std/Test.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @notice Shared helpers for wiring a protocol registry in tests
abstract contract ProtocolRegistryTestBase is Test {
  /// @notice Initializes a registry with the given addresses; zero 7702 is allowed
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
        allowed7702Implementation: allowed7702
      })
    );
  }
}
