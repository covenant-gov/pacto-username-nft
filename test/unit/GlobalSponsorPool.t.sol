// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';
import {MockProtocolPaymaster} from 'test/mocks/MockProtocolPaymaster.sol';

contract UnitGlobalSponsorPool is ProtocolRegistryTestBase {
  address internal _owner = makeAddr('owner');
  address internal _paymaster;
  address internal _depositor = makeAddr('depositor');
  address internal _nft = makeAddr('nft');
  address internal _bootstrapPool = makeAddr('bootstrapPool');
  address internal _policy = makeAddr('policy');
  address internal _bootstrapPolicy = makeAddr('bootstrapPolicy');
  address internal _entryPoint = makeAddr('entryPoint');
  address internal _allowed7702 = makeAddr('allowed7702');

  PactoProtocolRegistry internal _registry;
  GlobalSponsorPool internal _pool;

  function setUp() external {
    _registry = new PactoProtocolRegistry(_owner, address(this));
    _pool = new GlobalSponsorPool(_registry);
    _paymaster = address(
      _deployMockPaymaster(
        _registry, _nft, address(_pool), _bootstrapPool, _policy, _bootstrapPolicy, _entryPoint, _allowed7702
      )
    );
    _initializeRegistry(
      _registry, _nft, _paymaster, address(_pool), _bootstrapPool, _policy, _bootstrapPolicy, _entryPoint, _allowed7702
    );
  }

  function test_Deposit_WhenDepositingEth() external {
    vm.deal(_depositor, 1 ether);
    vm.prank(_depositor);
    _pool.deposit{value: 1 ether}();

    assertEq(_pool.spendablePoolWei(), 1 ether);
    assertEq(_pool.sponsorShares(_depositor), 1 ether);
    assertEq(_pool.totalShares(), 1 ether);
  }

  function test_SpendGas_WhenCalledByThePaymaster() external {
    vm.deal(_depositor, 1 ether);
    vm.prank(_depositor);
    _pool.deposit{value: 1 ether}();

    vm.prank(_paymaster);
    _pool.spendGas(0.25 ether);

    assertEq(_pool.spendablePoolWei(), 0.75 ether);
    assertEq(_paymaster.balance, 0.25 ether);
  }

  function test_SpendGas_WhenCalledByANonPaymaster() external {
    vm.expectRevert(ISponsorCommon.Sponsor_NotPaymaster.selector);
    vm.prank(_depositor);
    _pool.spendGas(1);
  }

  function test_SpendGas_WhenPaymasterIsUpdatedInTheRegistry() external {
    vm.deal(_depositor, 1 ether);
    vm.prank(_depositor);
    _pool.deposit{value: 1 ether}();

    MockProtocolPaymaster _nextPaymaster = _deployMockPaymaster(
      _registry, _nft, address(_pool), _bootstrapPool, _policy, _bootstrapPolicy, _entryPoint, _allowed7702
    );
    IPactoProtocolRegistry.ProtocolAddresses memory _next = IPactoProtocolRegistry.ProtocolAddresses({
      usernameNft: _nft,
      paymaster: address(_nextPaymaster),
      pool: address(_pool),
      bootstrapPool: _bootstrapPool,
      policy: _policy,
      bootstrapPolicy: _bootstrapPolicy,
      entryPoint: _entryPoint,
      allowed7702Implementation: _allowed7702
    });

    vm.prank(_owner);
    _registry.migrate(_next);

    vm.expectRevert(ISponsorCommon.Sponsor_NotPaymaster.selector);
    vm.prank(_paymaster);
    _pool.spendGas(0.1 ether);

    vm.prank(address(_nextPaymaster));
    _pool.spendGas(0.1 ether);

    assertEq(_pool.spendablePoolWei(), 0.9 ether);
    assertEq(address(_nextPaymaster).balance, 0.1 ether);
  }
}
