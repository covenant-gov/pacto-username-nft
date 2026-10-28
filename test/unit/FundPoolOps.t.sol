// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {UsernameSystemFactory} from 'contracts/UsernameSystemFactory.sol';

import {IUsernameSystemFactory} from 'interfaces/IUsernameSystemFactory.sol';

import {FundPoolOps} from 'script/FundPoolOps.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Test} from 'forge-std/Test.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';

/// @notice Exposes skip predicates and non-broadcast funding for unit coverage
contract FundPoolOpsHarness is FundPoolOps {
  function fund(
    IUsernameSystemFactory factory,
    GlobalSponsorPool global,
    BootstrapMintPool bootstrap,
    uint256 globalWei,
    uint256 bootstrapWei
  ) external {
    _fund(factory, global, bootstrap, globalWei, bootstrapWei, false);
  }

  function shouldSkipPoolDeposit(uint256 spendable, uint256 target) external pure returns (bool) {
    return _shouldSkipPoolDeposit(spendable, target);
  }
}

contract UnitFundPoolOps is Test {
  uint256 internal constant _DEPOSIT_WEI = 0.1 ether;

  UsernameSystemFactory internal _factory;
  GlobalSponsorPool internal _global;
  BootstrapMintPool internal _bootstrap;
  FundPoolOpsHarness internal _harness;

  function setUp() public {
    MockEntryPoint _ep = new MockEntryPoint();
    _factory = new UsernameSystemFactory(IEntryPoint(address(_ep)), makeAddr('owner'), makeAddr('allowed7702'));
    _global = GlobalSponsorPool(payable(_factory.POOL()));
    _bootstrap = BootstrapMintPool(payable(_factory.BOOTSTRAP_POOL()));
    _harness = new FundPoolOpsHarness();
    vm.deal(address(_harness), 1 ether);
  }

  function test_Unit_FundPool_SkipWhenAtTargetOrZero() external view {
    assertTrue(_harness.shouldSkipPoolDeposit(_DEPOSIT_WEI, _DEPOSIT_WEI));
    assertTrue(_harness.shouldSkipPoolDeposit(0, 0));
    assertFalse(_harness.shouldSkipPoolDeposit(_DEPOSIT_WEI - 1, _DEPOSIT_WEI));
  }

  function test_Unit_FundPool_BothAlreadyFundedSkipsCalls() external {
    vm.deal(address(this), 1 ether);
    _global.deposit{value: _DEPOSIT_WEI}();
    _bootstrap.deposit{value: _DEPOSIT_WEI}();

    vm.expectCall(address(_global), abi.encodeWithSelector(_global.deposit.selector), 0);
    vm.expectCall(address(_bootstrap), abi.encodeWithSelector(_bootstrap.deposit.selector), 0);

    _harness.fund(IUsernameSystemFactory(address(_factory)), _global, _bootstrap, _DEPOSIT_WEI, _DEPOSIT_WEI);

    assertEq(_global.spendablePoolWei(), _DEPOSIT_WEI);
    assertEq(_bootstrap.spendablePoolWei(), _DEPOSIT_WEI);
  }

  function test_Unit_FundPool_GlobalOkBootstrapShortOnlyDepositsBootstrap() external {
    vm.deal(address(this), 1 ether);
    _global.deposit{value: _DEPOSIT_WEI}();

    vm.expectCall(address(_global), abi.encodeWithSelector(_global.deposit.selector), 0);
    vm.expectCall(address(_bootstrap), _DEPOSIT_WEI, abi.encodeWithSelector(_bootstrap.deposit.selector));

    _harness.fund(IUsernameSystemFactory(address(_factory)), _global, _bootstrap, _DEPOSIT_WEI, _DEPOSIT_WEI);

    assertEq(_global.spendablePoolWei(), _DEPOSIT_WEI);
    assertEq(_bootstrap.spendablePoolWei(), _DEPOSIT_WEI);
  }

  function test_Unit_FundPool_EnvZeroGlobalOnlyDepositsBootstrap() external {
    vm.expectCall(address(_global), abi.encodeWithSelector(_global.deposit.selector), 0);
    vm.expectCall(address(_bootstrap), _DEPOSIT_WEI, abi.encodeWithSelector(_bootstrap.deposit.selector));

    _harness.fund(IUsernameSystemFactory(address(_factory)), _global, _bootstrap, 0, _DEPOSIT_WEI);

    assertEq(_global.spendablePoolWei(), 0);
    assertEq(_bootstrap.spendablePoolWei(), _DEPOSIT_WEI);
  }

  function test_Unit_FundPool_BothVacantFundsBoth() external {
    vm.expectCall(address(_global), _DEPOSIT_WEI, abi.encodeWithSelector(_global.deposit.selector));
    vm.expectCall(address(_bootstrap), _DEPOSIT_WEI, abi.encodeWithSelector(_bootstrap.deposit.selector));

    _harness.fund(IUsernameSystemFactory(address(_factory)), _global, _bootstrap, _DEPOSIT_WEI, _DEPOSIT_WEI);

    assertEq(_global.spendablePoolWei(), _DEPOSIT_WEI);
    assertEq(_bootstrap.spendablePoolWei(), _DEPOSIT_WEI);
  }
}
