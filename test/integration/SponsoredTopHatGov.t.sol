// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';
import {MockGovModule} from 'test/mocks/MockGovModule.sol';
import {MockNavePirataFactory} from 'test/mocks/MockNavePirataFactory.sol';
import {MockSquadSponsorFactory} from 'test/mocks/MockSquadSponsorFactory.sol';

contract IntegrationSponsoredTopHatGov is IntegrationBase {
  uint256 internal constant TOP_HAT_ID = 7;

  MockNavePirataFactory internal naveFactory;
  MockSquadSponsorFactory internal squadFactory;

  function setUp() public override {
    super.setUp();

    naveFactory = new MockNavePirataFactory(SponsorPolicyRegistry(address(policy)));
    squadFactory = new MockSquadSponsorFactory();

    vm.startPrank(owner);
    policy.setAuthorizedRegistrar(address(naveFactory), true);
    policy.registerTarget(address(naveFactory));
    policy.registerTarget(address(squadFactory));
    vm.stopPrank();
  }

  function test_SponsoredGovModuleWrite_AfterTopHatRegistration() external {
    executeClaim();

    (address _quartermaster,,) = naveFactory.deploySquad(TOP_HAT_ID);
    bytes memory _innerCallData = abi.encodeWithSelector(MockGovModule.setValue.selector, 99);
    PackedUserOperation memory _userOp = buildUserOp(claimer, _quartermaster, _innerCallData, 0);
    _userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));

    (bytes memory _context, uint256 _validationData) = paymaster.exposedValidate(_userOp, 1 ether);
    assertEq(_validationData, 0);
    assertEq(_context, hex'01');

    uint256 _globalBefore = pool.spendablePoolWei();
    vm.prank(claimer);
    MockGovModule(_quartermaster).setValue(99);

    paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, _context, 0.1 ether);

    assertEq(MockGovModule(_quartermaster).value(), 99);
    assertEq(pool.spendablePoolWei(), _globalBefore - 0.1 ether);
  }

  function test_SponsoredFactoryDeploy_WhenSquadSponsorFactoryTargetAllowed() external {
    executeClaim();

    bytes memory _innerCallData = abi.encodeWithSelector(MockSquadSponsorFactory.createSquadSponsor.selector);
    PackedUserOperation memory _userOp = buildUserOp(claimer, address(squadFactory), _innerCallData, 0);
    _userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));

    (bytes memory _context, uint256 _validationData) = paymaster.exposedValidate(_userOp, 1 ether);
    assertEq(_validationData, 0);
    assertEq(_context, hex'01');
  }

  function test_SponsoredGovModuleWrite_WhenTopHatIsNotRegistered() external {
    executeClaim();

    MockGovModule _module = new MockGovModule();
    address[] memory _modules = new address[](1);
    _modules[0] = address(_module);

    vm.prank(address(naveFactory));
    policy.registerModulesForTopHat(TOP_HAT_ID, _modules);

    bytes memory _innerCallData = abi.encodeWithSelector(MockGovModule.setValue.selector, 1);
    PackedUserOperation memory _userOp = buildUserOp(claimer, address(_module), _innerCallData, 0);
    _userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_MemberNotSponsorable.selector);
    paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_SponsoredGovModuleWrite_WhenMemberIsIneligible() external {
    executeClaim();
    (address _quartermaster,,) = naveFactory.deploySquad(TOP_HAT_ID);

    bytes memory _innerCallData = abi.encodeWithSelector(MockGovModule.setValue.selector, 1);
    PackedUserOperation memory _userOp = buildUserOp(claimer, _quartermaster, _innerCallData, 0);
    _userOp.paymasterAndData = buildPaymasterData(keccak256('wrong-npub'), claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_IneligibleMember.selector);
    paymaster.exposedValidate(_userOp, 1 ether);
  }
}
