// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitSponsorPolicyRegistry is Test {
  address internal _owner = makeAddr('owner');
  address internal _target = makeAddr('target');

  SponsorPolicyRegistry internal _policy;

  function setUp() external {
    _policy = new SponsorPolicyRegistry(_owner);
  }

  function test_IsSponsorable_WhenTheTargetIsContractAllowed() external {
    vm.prank(_owner);
    _policy.registerTarget(_target);

    assertTrue(_policy.isSponsorable(_target, hex'1234', address(0), 0));
    assertEq(_policy.policyVersion(), 1);
  }

  function test_IsSponsorable_WhenTheSelectorIsRegistered() external {
    bytes4 _selector = bytes4(keccak256('doThing()'));

    vm.prank(_owner);
    _policy.registerSelector(_target, _selector);

    assertTrue(_policy.isSponsorable(_target, abi.encodeWithSelector(_selector), address(0), 0));
  }

  function test_IsSponsorable_WhenNothingIsRegistered() external view {
    assertFalse(_policy.isSponsorable(_target, hex'12345678', address(0), 0));
  }
}
