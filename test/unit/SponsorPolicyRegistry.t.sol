// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {ISponsorPolicyRegistry} from 'interfaces/ISponsorPolicyRegistry.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitSponsorPolicyRegistry is Test {
  address internal _owner = makeAddr('owner');
  address internal _other = makeAddr('other');
  address internal _target = makeAddr('target');
  address internal _factory = makeAddr('factory');
  address internal _module = makeAddr('module');

  uint256 internal constant _TOP_HAT_ID = 42;

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

  function test_IsSponsorable_WhenTopHatModuleIsIndexedAndSponsored() external {
    _authorizeFactory();
    _registerTopHatWithModule();

    assertTrue(_policy.isSponsorable(_module, hex'12345678', address(0), 0));
    assertEq(_policy.topHatOfModule(_module), _TOP_HAT_ID);
    assertTrue(_policy.isTopHatSponsored(_TOP_HAT_ID));
  }

  function test_IsSponsorable_WhenModuleIsIndexedButTopHatIsNotSponsored() external {
    _authorizeFactory();

    address[] memory _modules = new address[](1);
    _modules[0] = _module;

    vm.prank(_factory);
    _policy.registerModulesForTopHat(_TOP_HAT_ID, _modules);

    assertFalse(_policy.isSponsorable(_module, hex'12345678', address(0), 0));
  }

  function test_IsSponsorable_WhenNothingIsRegistered() external view {
    assertFalse(_policy.isSponsorable(_target, hex'12345678', address(0), 0));
  }

  function test_RegisterTopHat_WhenCallerIsUnauthorized() external {
    vm.expectRevert(abi.encodeWithSelector(ISponsorPolicyRegistry.SponsorPolicyRegistry_UnauthorizedRegistrar.selector, _other));
    vm.prank(_other);
    _policy.registerTopHat(_TOP_HAT_ID);
  }

  function test_RegisterModulesForTopHat_WhenModuleAlreadyIndexedToDifferentTopHat() external {
    _authorizeFactory();

    address[] memory _modules = new address[](1);
    _modules[0] = _module;

    vm.startPrank(_factory);
    _policy.registerModulesForTopHat(_TOP_HAT_ID, _modules);
    vm.expectRevert(
      abi.encodeWithSelector(
        ISponsorPolicyRegistry.SponsorPolicyRegistry_ModuleAlreadyIndexed.selector, _module, _TOP_HAT_ID
      )
    );
    _policy.registerModulesForTopHat(_TOP_HAT_ID + 1, _modules);
    vm.stopPrank();
  }

  function test_DeregisterModules_WhenAuthorized() external {
    _authorizeFactory();
    _registerTopHatWithModule();

    address[] memory _modules = new address[](1);
    _modules[0] = _module;

    vm.prank(_factory);
    _policy.deregisterModules(_modules);

    assertEq(_policy.topHatOfModule(_module), 0);
    assertFalse(_policy.isSponsorable(_module, hex'12345678', address(0), 0));
  }

  function test_PolicyVersion_BumpsOnTopHatRegistration() external {
    _authorizeFactory();

    vm.prank(_factory);
    _policy.registerTopHat(_TOP_HAT_ID);

    assertEq(_policy.policyVersion(), 1);
  }

  function test_TransferOwnership_TwoStep() external {
    address _newOwner = makeAddr('newOwner');

    vm.prank(_owner);
    _policy.transferOwnership(_newOwner);

    assertEq(_policy.owner(), _owner);
    assertEq(_policy.pendingOwner(), _newOwner);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _other));
    vm.prank(_other);
    _policy.acceptOwnership();

    vm.prank(_newOwner);
    _policy.acceptOwnership();

    assertEq(_policy.owner(), _newOwner);
    assertEq(_policy.pendingOwner(), address(0));
  }

  function _authorizeFactory() internal {
    vm.prank(_owner);
    _policy.setAuthorizedRegistrar(_factory, true);
  }

  function _registerTopHatWithModule() internal {
    address[] memory _modules = new address[](1);
    _modules[0] = _module;

    vm.startPrank(_factory);
    _policy.registerTopHat(_TOP_HAT_ID);
    _policy.registerModulesForTopHat(_TOP_HAT_ID, _modules);
    vm.stopPrank();
  }
}
