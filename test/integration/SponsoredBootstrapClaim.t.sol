// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {UsernameSystemFactory} from 'contracts/UsernameSystemFactory.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';

contract IntegrationSponsoredBootstrapClaim is IntegrationBase {
  function test_SponsoredBootstrapClaim_ValidatesUserOpMintsNftAndBillsBootstrapPool() external {
    assertTrue(nft.canBootstrapClaim(claimer, NPUB_HASH));
    assertEq(nft.npubOf(claimer), bytes32(0));

    PackedUserOperation memory _userOp = buildBootstrapClaimUserOp();
    uint256 _bootstrapBefore = bootstrapPool.spendablePoolWei();

    (bytes memory _context, uint256 _validationData) = paymaster.exposedValidate(_userOp, 1 ether);
    assertEq(_validationData, 0);
    assertEq(_context, hex'00');

    executeClaim();

    paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, _context, 0.25 ether);

    assertEq(nft.ownerOf(1), claimer);
    assertEq(nft.npubOf(claimer), NPUB_HASH);
    assertEq(nft.usedNonce(NPUB_HASH), 1);
    assertFalse(nft.canBootstrapClaim(claimer, NPUB_HASH));
    assertEq(bootstrapPool.spendablePoolWei(), _bootstrapBefore - 0.25 ether);
    assertEq(pool.spendablePoolWei(), 10 ether);
  }

  function test_SponsoredBootstrapClaim_WhenFactoryIsDeployedAndFunded() external {
    UsernameSystemFactory _factory =
      new UsernameSystemFactory(IEntryPoint(address(new MockEntryPoint())), owner, makeAddr('allowed7702'));

    vm.deal(address(this), 5 ether);
    BootstrapMintPool(payable(_factory.BOOTSTRAP_POOL())).deposit{value: 5 ether}();

    assertEq(BootstrapMintPool(payable(_factory.BOOTSTRAP_POOL())).paymaster(), _factory.PAYMASTER());
    PactoUsernameNFT _usernameNft = PactoUsernameNFT(_factory.USERNAME_NFT());
    assertTrue(_usernameNft.canBootstrapClaim(claimer, NPUB_HASH));

    bytes32 _digest = _usernameNft.hashClaimBinding(NPUB_HASH, claimer, USERNAME, 1, ISSUED_AT, SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(CLAIMER_PK, _digest);
    bytes memory _evmSignature = abi.encodePacked(_r, _s, _v);

    vm.prank(claimer);
    _usernameNft.claim(USERNAME, NPUB_HASH, PUBKEY, 1, ISSUED_AT, SALT, NOSTR_SIGNATURE, _evmSignature);

    assertEq(_usernameNft.ownerOf(1), claimer);
  }

  function test_SponsoredBootstrapClaim_WhenReplayAttemptUsesMemberPathAndFails() external {
    executeClaim();

    PackedUserOperation memory _replayUserOp = buildBootstrapClaimUserOp();
    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_MemberNotSponsorable.selector);
    paymaster.exposedValidate(_replayUserOp, 1 ether);
  }

  function test_SponsoredBootstrapClaim_WhenExecuteTargetIsNotRegistryNft() external {
    PactoUsernameNFT _otherNft = new PactoUsernameNFT(owner);
    PackedUserOperation memory _userOp =
      buildUserOp(claimer, address(_otherNft), claimCalldata(USERNAME, NPUB_HASH, NOSTR_SIGNATURE), 0);
    _userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_BootstrapNotSponsorable.selector);
    paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_SponsoredBootstrapClaim_WhenEip7702DelegationIsAllowlisted() external {
    bytes memory _stub = abi.encodePacked(bytes3(0xef0100), bytes20(allowed7702));
    vm.etch(claimer, _stub);

    PackedUserOperation memory _userOp = buildBootstrapClaimUserOp();
    (bytes memory _context, uint256 _validationData) = paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, hex'00');
  }

  function test_SponsoredMemberAction_AfterBootstrapMintUsesGlobalPool() external {
    executeClaim();

    bytes memory _innerCallData = abi.encodeWithSelector(INITIATE_ADDRESS_TRANSFER_SELECTOR, NPUB_HASH, pending);
    PackedUserOperation memory _userOp = buildUserOp(claimer, address(nft), _innerCallData, 0);
    _userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));

    (bytes memory _context, uint256 _validationData) = paymaster.exposedValidate(_userOp, 1 ether);
    assertEq(_validationData, 0);
    assertEq(_context, hex'01');

    uint256 _globalBefore = pool.spendablePoolWei();
    vm.prank(claimer);
    nft.initiateAddressTransfer(NPUB_HASH, pending);

    paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, _context, 0.1 ether);

    assertEq(nft.isPendingTransfer(NPUB_HASH), true);
    assertEq(pool.spendablePoolWei(), _globalBefore - 0.1 ether);
    assertEq(bootstrapPool.spendablePoolWei(), 10 ether);
  }

  function test_SponsoredMemberAction_WhenClaimSelectorIsNotRegisteredOnMemberPolicy() external view {
    bytes memory _claimInner = claimCalldata(USERNAME, NPUB_HASH, NOSTR_SIGNATURE);
    assertFalse(SponsorPolicyRegistry(address(policy)).isSponsorable(address(nft), _claimInner, claimer, 1));
  }
}
