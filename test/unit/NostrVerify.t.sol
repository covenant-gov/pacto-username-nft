// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {NostrClaimLink} from 'contracts/utils/NostrClaimLink.sol';
import {NostrEventHash} from 'contracts/utils/NostrEventHash.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitNostrVerify is Test {
  bytes32 internal constant _PUBKEY = 0x405bcf3a770f36af12782423b7c8a32f1ec5accc0d8301007a2f5b460a4537da;
  uint256 internal constant _CREATED_AT = 1_735_689_600;
  address internal constant _EVM_ADDRESS = 0xA11Ce00000000000000000000000000000000000;
  string internal constant _NAME = 'alice';
  uint256 internal constant _NONCE = 1;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  bytes32 internal constant _EVENT_ID = 0x54be0aa6a88d9361c996540d3b0c2711f8135af3c171d87e8c2f3ca98df16403;
  bytes32 internal constant _NPUB_HASH = 0xc959a9bcacf71c88b2e1fbb220231aa89b7384ed980d05360c8eecc38ab17477;
  bytes internal constant _SIGNATURE =
    hex'0eb8623d18164c3bbba0dfdae6992a42d2d7498ddcbe743f1090de503ea55a65f9cef3b4dc07f2a40a0d5a3260b791a116a9cae7c3276dc46bd81c52355569c7';

  function test_ClaimLinkEventId_MatchesGoldenVector() external pure {
    bytes32 _eventId = NostrEventHash.claimLinkEventId(
      _PUBKEY, _CREATED_AT, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT
    );

    assertEq(_eventId, _EVENT_ID);
  }

  function test_NpubHashFromPubkey_MatchesGoldenVector() external pure {
    assertEq(NostrClaimLink.npubHashFromPubkey(_PUBKEY), _NPUB_HASH);
  }

  function test_VerifyBinding_WhenSignatureIsValid() external view {
    NostrClaimLink.verifyBinding(
      _PUBKEY, _CREATED_AT, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT, _SIGNATURE
    );
  }

  function test_Verify_WhenEncodedEventIsValid() external view {
    bytes memory _encoded = NostrClaimLink.encodeEvent(
      _PUBKEY, _CREATED_AT, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT, _SIGNATURE
    );

    NostrClaimLink.ClaimBinding memory _binding = NostrClaimLink.verify(_encoded);

    assertEq(_binding.npubHash, _NPUB_HASH);
    assertEq(_binding.pubkey, _PUBKEY);
    assertEq(_binding.evmAddress, _EVM_ADDRESS);
    assertEq(_binding.name, _NAME);
    assertEq(_binding.nonce, _NONCE);
    assertEq(_binding.issuedAt, _ISSUED_AT);
    assertEq(_binding.salt, _SALT);
    assertEq(_binding.createdAt, _CREATED_AT);
  }

  function test_VerifyBinding_WhenSignatureIsInvalid() external {
    bytes memory _badSignature = bytes(_SIGNATURE);
    _badSignature[0] = bytes1(uint8(_badSignature[0]) ^ 0xff);

    vm.expectRevert(NostrClaimLink.NostrClaimLink_InvalidSignature.selector);
    this._verifyBindingHelper(_badSignature);
  }

  function test_VerifyBinding_WhenSignatureLengthIsInvalid() external {
    vm.expectRevert(NostrClaimLink.NostrClaimLink_InvalidSignatureLength.selector);
    this._verifyBindingHelper(hex'010203');
  }

  function _verifyBindingHelper(bytes memory signature) external view {
    NostrClaimLink.verifyBinding(
      _PUBKEY, _CREATED_AT, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT, signature
    );
  }
}
