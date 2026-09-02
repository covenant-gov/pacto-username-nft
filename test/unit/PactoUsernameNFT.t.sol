// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IPactoUsernameNFT, PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitPactoUsernameNFT is Test {
  uint256 internal constant _CLAIMER_PK = 0xA11CE;
  uint256 internal constant _OTHER_PK = 0xB0B;
  uint256 internal constant _PENDING_PK = 0xC0FFEE;

  address internal _owner;
  address internal _claimer;
  address internal _other;
  address internal _pending;

  bytes32 internal constant _NPUB_HASH = keccak256('npub1example');
  bytes32 internal constant _OTHER_NPUB_HASH = keccak256('npub1other');
  string internal constant _NAME = 'daopunk';

  PactoUsernameNFT internal _nft;

  function setUp() external {
    _owner = makeAddr('owner');
    _claimer = vm.addr(_CLAIMER_PK);
    _other = vm.addr(_OTHER_PK);
    _pending = vm.addr(_PENDING_PK);

    vm.prank(_owner);
    _nft = new PactoUsernameNFT(_owner);
  }

  function _claimSignature(
    address _evmAddress,
    string memory _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt
  ) internal view returns (bytes memory signature) {
    bytes32 _digest = _nft.hashClaimBinding(_npubHash, _evmAddress, _name, _nonce, _issuedAt);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }

  function _claim(
    address _caller,
    string memory _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes memory _signature,
    uint256 _value
  ) internal {
    vm.prank(_caller);
    _nft.claim{value: _value}(_name, _npubHash, _nonce, _issuedAt, _signature);
  }

  modifier givenClaimedUsername() {
    _claim(
      _claimer,
      _NAME,
      _NPUB_HASH,
      1,
      block.timestamp,
      _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, block.timestamp),
      0
    );
    _;
  }

  function test_Claim_WhenTheClaimIsValid() external {
    bytes memory _signature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, block.timestamp);

    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.UsernameClaimed(_NPUB_HASH, _NAME, _claimer, 1);

    _claim(_claimer, _NAME, _NPUB_HASH, 1, block.timestamp, _signature, 0);

    IPactoUsernameNFT.UsernameRecord memory _record = _nft.recordOf(_NPUB_HASH);
    assertEq(_record.name, _NAME);
    assertEq(_record.evmAddress, _claimer);
    assertEq(_record.pendingAddress, address(0));
    assertEq(_record.tokenId, 1);
    assertEq(_nft.ownerOf(1), _claimer);
    assertEq(_nft.npubOf(_claimer), _NPUB_HASH);
    assertTrue(_nft.nameAvailable('unused') == true);
    assertFalse(_nft.nameAvailable(_NAME));
  }

  function test_Claim_WhenTheNameIsTooShort() external {
    bytes memory _signature = _claimSignature(_claimer, 'ab', _NPUB_HASH, 1, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidName.selector);
    vm.prank(_claimer);
    _nft.claim('ab', _NPUB_HASH, 1, block.timestamp, _signature);
  }

  function test_Claim_WhenTheNameContainsUppercaseLetters() external {
    bytes memory _signature = _claimSignature(_claimer, 'DaoPunk', _NPUB_HASH, 1, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidName.selector);
    vm.prank(_claimer);
    _nft.claim('DaoPunk', _NPUB_HASH, 1, block.timestamp, _signature);
  }

  function test_Claim_WhenTheNameIsAlreadyClaimed() external givenClaimedUsername {
    bytes memory _signature = _signForOther(_NAME, _OTHER_NPUB_HASH, 1, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NameUnavailable.selector);
    vm.prank(_other);
    _nft.claim(_NAME, _OTHER_NPUB_HASH, 1, block.timestamp, _signature);
  }

  function test_Claim_WhenTheNpubAlreadyHasARecord() external givenClaimedUsername {
    bytes memory _signature = _signForOther('othername', _NPUB_HASH, 2, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NpubAlreadyClaimed.selector);
    vm.prank(_other);
    _nft.claim('othername', _NPUB_HASH, 2, block.timestamp, _signature);
  }

  function test_Claim_WhenTheClaimerAddressAlreadyControlsARecord() external givenClaimedUsername {
    bytes memory _signature = _claimSignature(_claimer, 'othername', _OTHER_NPUB_HASH, 2, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_AddressAlreadyClaimed.selector);
    vm.prank(_claimer);
    _nft.claim('othername', _OTHER_NPUB_HASH, 2, block.timestamp, _signature);
  }

  function test_Claim_WhenTheMintFeeIsNotPaid() external {
    vm.prank(_owner);
    _nft.setMintFee(1 ether);

    bytes memory _signature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, block.timestamp);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InsufficientMintFee.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, 1, block.timestamp, _signature);
  }

  function test_Claim_WhenTheClaimSignatureIsInvalid() external {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidClaimSignature.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, 1, block.timestamp, hex'010203');
  }

  function test_InitiateAddressTransfer_WhenCalledByTheActiveControllerWithAValidPendingAddress()
    external
    givenClaimedUsername
  {
    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.AddressTransferInitiated(_NPUB_HASH, _claimer, _pending);

    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);

    IPactoUsernameNFT.UsernameRecord memory _record = _nft.recordOf(_NPUB_HASH);
    assertEq(_record.pendingAddress, _pending);
    assertTrue(_nft.isPendingTransfer(_NPUB_HASH));
  }

  function test_InitiateAddressTransfer_WhenCalledByANonController() external givenClaimedUsername {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NotActiveController.selector);
    vm.prank(_other);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);
  }

  function test_InitiateAddressTransfer_WhenAPendingTransferAlreadyExists() external givenClaimedUsername {
    vm.startPrank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_PendingTransferExists.selector);
    _nft.initiateAddressTransfer(_NPUB_HASH, _other);
    vm.stopPrank();
  }

  function test_ClaimAddressTransfer_WhenCalledByThePendingRecipient() external givenClaimedUsername {
    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);

    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.AddressTransferClaimed(_NPUB_HASH, _claimer, _pending);

    vm.prank(_pending);
    _nft.claimAddressTransfer(_NPUB_HASH);

    IPactoUsernameNFT.UsernameRecord memory _record = _nft.recordOf(_NPUB_HASH);
    assertEq(_record.evmAddress, _pending);
    assertEq(_record.pendingAddress, address(0));
    assertEq(_nft.ownerOf(1), _pending);
    assertEq(_nft.npubOf(_pending), _NPUB_HASH);
    assertEq(_nft.npubOf(_claimer), bytes32(0));
  }

  function test_ClaimAddressTransfer_WhenCalledByANonPendingAddress() external givenClaimedUsername {
    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NotPendingRecipient.selector);
    vm.prank(_other);
    _nft.claimAddressTransfer(_NPUB_HASH);
  }

  function test_ClaimAddressTransfer_WhenNoPendingTransferExists() external givenClaimedUsername {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NoPendingTransfer.selector);
    vm.prank(_pending);
    _nft.claimAddressTransfer(_NPUB_HASH);
  }

  function test_CancelAddressTransfer_WhenCalledByTheActiveController() external givenClaimedUsername {
    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);

    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.AddressTransferCancelled(_NPUB_HASH, _claimer);

    vm.prank(_claimer);
    _nft.cancelAddressTransfer(_NPUB_HASH);

    assertFalse(_nft.isPendingTransfer(_NPUB_HASH));
  }

  function test_CancelAddressTransfer_WhenNoPendingTransferExists() external givenClaimedUsername {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NoPendingTransfer.selector);
    vm.prank(_claimer);
    _nft.cancelAddressTransfer(_NPUB_HASH);
  }

  function test_Transfer_WhenAStandardErc721TransferIsAttempted() external givenClaimedUsername {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_TransferDisabled.selector);
    vm.prank(_claimer);
    _nft.transferFrom(_claimer, _other, 1);
  }

  function test_SetMintFee_WhenCalledByOwner() external {
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.MintFeeUpdated(0.01 ether);
    _nft.setMintFee(0.01 ether);
    assertEq(_nft.mintFee(), 0.01 ether);
  }

  function test_Claim_WhenMintFeeIsPaid() external {
    vm.prank(_owner);
    _nft.setMintFee(0.01 ether);

    vm.deal(_claimer, 0.01 ether);

    bytes memory _signature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, block.timestamp);

    vm.prank(_claimer);
    _nft.claim{value: 0.01 ether}(_NAME, _NPUB_HASH, 1, block.timestamp, _signature);

    assertEq(_nft.ownerOf(1), _claimer);
  }

  function _signForOther(
    string memory _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt
  ) internal view returns (bytes memory signature) {
    bytes32 _digest = _nft.hashClaimBinding(_npubHash, _other, _name, _nonce, _issuedAt);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_OTHER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }
}
