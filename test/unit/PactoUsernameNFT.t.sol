// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IPactoUsernameNFT, PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitPactoUsernameNFT is Test {
  using stdStorage for StdStorage;

  StdStorage internal _stdstore;
  uint256 internal constant _CLAIMER_PK = 0xA11CE;
  uint256 internal constant _OTHER_PK = 0xB0B;
  uint256 internal constant _PENDING_PK = 0xC0FFEE;

  address internal _owner;
  address internal _claimer;
  address internal _other;
  address internal _pending;

  bytes32 internal constant _PUBKEY = 0x391823cee659f38512ccde6c2bb6f4e32e917478ee2e96d4f5e05656e7adb2ae;
  bytes32 internal constant _NPUB_HASH = 0x540d126644e922328318f1870ba0c9de3b2d5c0c271e27af7efea3e44025fdc1;
  bytes32 internal constant _OTHER_NPUB_HASH = keccak256('npub1other');
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  string internal constant _NAME = 'daopunk';

  bytes internal constant _NOSTR_SIGNATURE =
    hex'715358459e600817a7e0fb4371b594a9e36f8c4f0272a41e4248fc3b1021accf6cdf2d2718424a5491d94ae1935fbb1b569c3e92b23269143e71e3635be3efb2';

  PactoUsernameNFT internal _nft;

  function setUp() external {
    _owner = makeAddr('owner');
    _claimer = vm.addr(_CLAIMER_PK);
    _other = vm.addr(_OTHER_PK);
    _pending = vm.addr(_PENDING_PK);

    vm.warp(_ISSUED_AT);

    vm.prank(_owner);
    _nft = new PactoUsernameNFT(_owner);

    assertEq(_claimer, 0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7);
  }

  function _claimSignature(
    address _evmAddress,
    string memory _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt
  ) internal view returns (bytes memory signature) {
    bytes32 _digest = _nft.hashClaimBinding(_npubHash, _evmAddress, _name, _nonce, _issuedAt, _salt);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }

  function _claim(
    address _caller,
    string memory _name,
    bytes32 _npubHash,
    bytes32 _pubkey,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt,
    bytes memory _nostrSignature,
    bytes memory _evmSignature,
    uint256 _value
  ) internal {
    vm.prank(_caller);
    _nft.claim{value: _value}(_name, _npubHash, _pubkey, _nonce, _issuedAt, _salt, _nostrSignature, _evmSignature);
  }

  function _defaultClaim(
    address _caller,
    string memory _name,
    bytes32 _npubHash,
    bytes32 _pubkey,
    uint256 _nonce,
    uint256 _value
  ) internal {
    _claim(
      _caller,
      _name,
      _npubHash,
      _pubkey,
      _nonce,
      _ISSUED_AT,
      _SALT,
      _NOSTR_SIGNATURE,
      _claimSignature(_caller, _name, _npubHash, _nonce, _ISSUED_AT, _SALT),
      _value
    );
  }

  modifier givenClaimedUsername() {
    _defaultClaim(_claimer, _NAME, _NPUB_HASH, _PUBKEY, 1, 0);
    _;
  }

  function test_Claim_WhenTheClaimIsValid() external {
    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectEmit(true, true, true, true, address(_nft));
    emit IPactoUsernameNFT.UsernameClaimed(_NPUB_HASH, _NAME, _claimer, 1);

    _claim(_claimer, _NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature, 0);

    IPactoUsernameNFT.UsernameRecord memory _record = _nft.recordOf(_NPUB_HASH);
    assertEq(_record.name, _NAME);
    assertEq(_record.evmAddress, _claimer);
    assertEq(_record.pendingAddress, address(0));
    assertEq(_record.tokenId, 1);
    assertEq(_nft.ownerOf(1), _claimer);
    assertEq(_nft.npubOf(_claimer), _NPUB_HASH);
    assertEq(_nft.usedNonce(_NPUB_HASH), 1);
    assertTrue(_nft.nameAvailable('unused'));
    assertTrue(_nft.nameAvailable('DaoPunk'));
    assertTrue(_nft.nameAvailable('ab'));
    assertTrue(_nft.nameAvailable('user-1'));
    assertFalse(_nft.nameAvailable(_NAME));
    assertTrue(_nft.canBootstrapClaim(_other, _OTHER_NPUB_HASH));
    assertFalse(_nft.canBootstrapClaim(_claimer, _OTHER_NPUB_HASH));
  }

  function test_NameAvailable_WhenTheNameIsShortUppercaseOrHasDigitsAndHyphens() external view {
    assertTrue(_nft.nameAvailable('ab'));
    assertTrue(_nft.nameAvailable('DaoPunk'));
    assertTrue(_nft.nameAvailable('user-1'));
  }

  function test_NameAvailable_WhenTheNameIsReserved() external {
    vm.prank(_owner);
    _nft.setReservedName(keccak256(bytes(_NAME)), true);

    assertFalse(_nft.nameAvailable(_NAME));
  }

  function test_Claim_WhenTheNameIsReserved() external {
    vm.prank(_owner);
    _nft.setReservedName(keccak256(bytes(_NAME)), true);

    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NameUnavailable.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheNameIsAlreadyClaimed() external givenClaimedUsername {
    bytes memory _evmSignature = _signForOther(_NAME, _OTHER_NPUB_HASH, 1, _ISSUED_AT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NameUnavailable.selector);
    vm.prank(_other);
    _nft.claim(_NAME, _OTHER_NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheNpubAlreadyHasARecord() external givenClaimedUsername {
    bytes memory _evmSignature = _signForOther('othername', _NPUB_HASH, 2, _ISSUED_AT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NpubAlreadyClaimed.selector);
    vm.prank(_other);
    _nft.claim('othername', _NPUB_HASH, _PUBKEY, 2, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheClaimerAddressAlreadyControlsARecord() external givenClaimedUsername {
    bytes memory _evmSignature = _claimSignature(_claimer, 'othername', _OTHER_NPUB_HASH, 2, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_AddressAlreadyClaimed.selector);
    vm.prank(_claimer);
    _nft.claim('othername', _OTHER_NPUB_HASH, _PUBKEY, 2, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheMintFeeIsNotPaid() external {
    vm.prank(_owner);
    _nft.setMintFee(1 ether);

    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InsufficientMintFee.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheEvmSignatureIsInvalid() external {
    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidClaimSignature.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, hex'010203');
  }

  function test_Claim_WhenTheNostrSignatureIsInvalid() external {
    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);
    bytes memory _badNostrSignature = bytes(_NOSTR_SIGNATURE);
    _badNostrSignature[0] = bytes1(uint8(_badNostrSignature[0]) ^ 0xff);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidNostrSignature.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _badNostrSignature, _evmSignature);
  }

  function test_Claim_WhenTheNpubHashDoesNotMatchThePubkey() external {
    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _OTHER_NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_InvalidNpubHash.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _OTHER_NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheNonceIsReused() external {
    _stdstore.target(address(_nft)).sig('usedNonce(bytes32)').with_key(_NPUB_HASH).checked_write(1);

    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_NonceAlreadyUsed.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Claim_WhenTheBindingIsExpired() external {
    vm.warp(_ISSUED_AT + _nft.MAX_BINDING_AGE() + 1);

    bytes memory _evmSignature = _claimSignature(_claimer, _NAME, _NPUB_HASH, 1, _ISSUED_AT, _SALT);

    vm.expectRevert(IPactoUsernameNFT.PactoUsernameNFT_BindingExpired.selector);
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
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

    _defaultClaim(_claimer, _NAME, _NPUB_HASH, _PUBKEY, 1, 0.01 ether);

    assertEq(_nft.ownerOf(1), _claimer);
  }

  function _signForOther(
    string memory _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt
  ) internal view returns (bytes memory signature) {
    bytes32 _digest = _nft.hashClaimBinding(_npubHash, _other, _name, _nonce, _issuedAt, _SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_OTHER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }
}
