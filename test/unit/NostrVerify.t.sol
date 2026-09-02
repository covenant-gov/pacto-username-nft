// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {NostrClaimLink} from 'contracts/utils/NostrClaimLink.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitNostrVerify is Test {
  bytes32 internal constant _PUBKEY = 0xb267276ecc95e5768557a2e7ae9a4eb4f78c72cf9594685ee6d61fd47a5715a6;
  address internal constant _EVM_ADDRESS = 0xA11Ce00000000000000000000000000000000000;
  string internal constant _NAME = 'alice';
  uint256 internal constant _NONCE = 1;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  bytes32 internal constant _NOSTR_CLAIM_DIGEST = 0x67670cabdad054800aa8f039aebae7e02666bd27f42e502ca7f21dafc57b63d5;
  bytes32 internal constant _NPUB_HASH = 0x4ae9e893ea446df7672ba9b42a912c4db69ce3dd411e3760858cced0be5b3456;
  bytes internal constant _SIGNATURE =
    hex'4d5923622ae38f1fc18ce25d2d11a843f18a660c2651c0cdfa344ccd08fe93ab4f88f2cdd8bcc10d489bdfcbc57a9d1211611f81f438a391abc89a0a6cba4c09';

  function test_HashNostrClaim_MatchesGoldenVector() external pure {
    bytes32 _digest = NostrClaimLink.hashNostrClaim(_PUBKEY, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT);

    assertEq(_digest, _NOSTR_CLAIM_DIGEST);
  }

  function test_NpubHashFromPubkey_MatchesGoldenVector() external pure {
    assertEq(NostrClaimLink.npubHashFromPubkey(_PUBKEY), _NPUB_HASH);
  }

  function test_VerifyNostrClaimSignature_WhenSignatureIsValid() external view {
    NostrClaimLink.verifyNostrClaimSignature(_PUBKEY, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT, _SIGNATURE);
  }

  function test_VerifyNostrClaimSignature_WhenSignatureIsInvalid() external {
    bytes memory _badSignature = bytes(_SIGNATURE);
    _badSignature[0] = bytes1(uint8(_badSignature[0]) ^ 0xff);

    vm.expectRevert(NostrClaimLink.NostrClaimLink_InvalidSignature.selector);
    this._verifyHelper(_badSignature);
  }

  function test_VerifyNostrClaimSignature_WhenSignatureLengthIsInvalid() external {
    vm.expectRevert(NostrClaimLink.NostrClaimLink_InvalidSignatureLength.selector);
    this._verifyHelper(hex'010203');
  }

  function test_VerifyNostrClaimSignature_WhenNameDoesNotMatchDigest() external {
    vm.expectRevert(NostrClaimLink.NostrClaimLink_InvalidSignature.selector);
    NostrClaimLink.verifyNostrClaimSignature(_PUBKEY, _EVM_ADDRESS, 'bob', _NONCE, _ISSUED_AT, _SALT, _SIGNATURE);
  }

  function _verifyHelper(bytes memory signature) external view {
    NostrClaimLink.verifyNostrClaimSignature(_PUBKEY, _EVM_ADDRESS, _NAME, _NONCE, _ISSUED_AT, _SALT, signature);
  }
}
