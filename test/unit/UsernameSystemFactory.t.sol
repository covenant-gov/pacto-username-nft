// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {UsernameSystemFactory} from 'contracts/UsernameSystemFactory.sol';
import {Test} from 'forge-std/Test.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';

contract UnitUsernameSystemFactory is Test {
  address internal _owner = makeAddr('owner');
  address internal _allowed7702 = makeAddr('allowed7702');

  MockEntryPoint internal _entryPoint;
  UsernameSystemFactory internal _factory;

  function setUp() external {
    _entryPoint = new MockEntryPoint();
    _factory = new UsernameSystemFactory(IEntryPoint(address(_entryPoint)), _owner, _allowed7702);
  }

  function test_Constructor_WiresDeployedContracts() external view {
    PactoProtocolRegistry _registry = PactoProtocolRegistry(address(_factory.REGISTRY()));

    assertTrue(address(_factory.REGISTRY()) != address(0));
    assertTrue(_factory.USERNAME_NFT() != address(0));
    assertTrue(_factory.POOL() != address(0));
    assertTrue(_factory.BOOTSTRAP_POOL() != address(0));
    assertTrue(_factory.POLICY() != address(0));
    assertTrue(_factory.BOOTSTRAP_POLICY() != address(0));
    assertTrue(_factory.PAYMASTER() != address(0));

    assertTrue(_registry.initialized());
    assertEq(_registry.owner(), _owner);
    assertEq(_registry.INSTALLER(), address(_factory));
    assertEq(_registry.usernameNft(), _factory.USERNAME_NFT());
    assertEq(_registry.paymaster(), _factory.PAYMASTER());
    assertEq(_registry.pool(), _factory.POOL());
    assertEq(_registry.bootstrapPool(), _factory.BOOTSTRAP_POOL());
    assertEq(_registry.policy(), _factory.POLICY());
    assertEq(_registry.bootstrapPolicy(), _factory.BOOTSTRAP_POLICY());
    assertEq(_registry.entryPoint(), address(_entryPoint));
    assertEq(_registry.allowed7702Implementation(), _allowed7702);

    assertEq(GlobalSponsorPool(payable(_factory.POOL())).paymaster(), _factory.PAYMASTER());
    assertEq(BootstrapMintPool(payable(_factory.BOOTSTRAP_POOL())).paymaster(), _factory.PAYMASTER());
    assertEq(address(GlobalSponsorPool(payable(_factory.POOL())).REGISTRY()), address(_registry));
  }
}
