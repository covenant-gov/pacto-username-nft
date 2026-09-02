// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {Test} from 'forge-std/Test.sol';
import {ISponsorCommon} from 'interfaces/ISponsorCommon.sol';

contract UnitBootstrapMintPool is Test {
  address internal _factory = makeAddr('factory');
  address internal _paymaster = makeAddr('paymaster');
  address internal _depositor = makeAddr('depositor');

  BootstrapMintPool internal _pool;

  function setUp() external {
    _pool = new BootstrapMintPool(_factory);
    vm.prank(_factory);
    _pool.wirePaymaster(_paymaster);
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
}
