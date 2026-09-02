// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {UsernameSystemFactory} from 'contracts/UsernameSystemFactory.sol';
import {Test} from 'forge-std/Test.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';

contract UnitUsernameSystemFactory is Test {
  address internal _owner = makeAddr('owner');

  MockEntryPoint internal _entryPoint;
  UsernameSystemFactory internal _factory;

  function setUp() external {
    _entryPoint = new MockEntryPoint();
    _factory = new UsernameSystemFactory(IEntryPoint(address(_entryPoint)), _owner, makeAddr('allowed7702'));
  }

  function test_Constructor_WiresDeployedContracts() external view {
    assertTrue(_factory.USERNAME_NFT() != address(0));
    assertTrue(_factory.POOL() != address(0));
    assertTrue(_factory.BOOTSTRAP_POOL() != address(0));
    assertTrue(_factory.POLICY() != address(0));
    assertTrue(_factory.BOOTSTRAP_POLICY() != address(0));
    assertTrue(_factory.PAYMASTER() != address(0));

    assertEq(GlobalSponsorPool(payable(_factory.POOL())).paymaster(), _factory.PAYMASTER());
    assertEq(BootstrapMintPool(payable(_factory.BOOTSTRAP_POOL())).paymaster(), _factory.PAYMASTER());
  }
}
