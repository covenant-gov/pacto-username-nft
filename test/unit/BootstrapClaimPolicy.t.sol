// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {BootstrapClaimPolicy} from 'contracts/BootstrapClaimPolicy.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitBootstrapClaimPolicy is Test {
  uint256 internal constant _CLAIMER_PK = 0xA11CE;

  address internal _owner = makeAddr('owner');
  address internal _claimer;
  address internal _other = makeAddr('other');

  bytes32 internal constant _PUBKEY = 0x391823cee659f38512ccde6c2bb6f4e32e917478ee2e96d4f5e05656e7adb2ae;
  bytes32 internal constant _NPUB_HASH = 0x540d126644e922328318f1870ba0c9de3b2d5c0c271e27af7efea3e44025fdc1;
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  string internal constant _NAME = 'daopunk';

  bytes internal constant _NOSTR_SIGNATURE =
    hex'715358459e600817a7e0fb4371b594a9e36f8c4f0272a41e4248fc3b1021accf6cdf2d2718424a5491d94ae1935fbb1b569c3e92b23269143e71e3635be3efb2';

  PactoUsernameNFT internal _nft;
  BootstrapClaimPolicy internal _policy;

  function setUp() external {
    _claimer = vm.addr(_CLAIMER_PK);
    vm.warp(_ISSUED_AT);

    vm.prank(_owner);
    _nft = new PactoUsernameNFT(_owner);
    _policy = new BootstrapClaimPolicy(_nft);
  }

  function _claimCalldata(
    string memory name,
    bytes32 npubHash,
    bytes memory nostrSignature
  ) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      bytes4(0x9824550d),
      name,
      npubHash,
      _PUBKEY,
      uint256(1),
      _ISSUED_AT,
      _SALT,
      nostrSignature,
      hex'0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233343536'
    );
  }

  function _executeCalldata(address target, uint256 value, bytes memory innerCallData)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(UserOpCalldataLib.EXECUTE_SELECTOR, target, value, innerCallData);
  }

  function _isBootstrapSponsorable(bytes calldata userOpCallData, address member) internal view returns (bool) {
    (address _target, uint256 _value, bytes calldata _innerCallData, bool _valid) =
      UserOpCalldataLib.decodeExecute(userOpCallData);
    if (!_valid || _value != 0) return false;
    return _policy.isSponsorable(_target, _innerCallData, member, 0);
  }

  function test_IsSponsorable_WhenClaimCalldataIsValid() external view {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);

    assertTrue(_policy.isSponsorable(address(_nft), _innerCallData, _claimer, 0));
  }

  function test_IsSponsorable_WhenWrappedExecuteValueIsZero() external view {
    assertTrue(
      this.exposedIsBootstrapSponsorable(
        _executeCalldata(address(_nft), 0, _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE)), _claimer
      )
    );
  }

  function test_IsSponsorable_WhenWrappedExecuteValueIsNonZero() external view {
    assertFalse(
      this.exposedIsBootstrapSponsorable(
        _executeCalldata(address(_nft), 1, _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE)), _claimer
      )
    );
  }

  function exposedIsBootstrapSponsorable(bytes calldata userOpCallData, address member) external view returns (bool) {
    return _isBootstrapSponsorable(userOpCallData, member);
  }

  function test_IsSponsorable_WhenTargetIsNotTheUsernameNft() external view {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(_other, _innerCallData, _claimer, 0));
  }

  function test_IsSponsorable_WhenSelectorIsNotClaim() external view {
    assertFalse(_policy.isSponsorable(address(_nft), hex'deadbeef', _claimer, 0));
  }

  function test_IsSponsorable_WhenTokenIdIsNonZero() external view {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _claimer, 1));
  }

  function test_IsSponsorable_WhenMemberAlreadyHasAnNpub() external {
    _claimUsername();

    bytes memory _innerCallData = _claimCalldata('othername', keccak256('npub1other'), _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _claimer, 0));
  }

  function test_IsSponsorable_WhenNpubIsAlreadyClaimed() external {
    _claimUsername();

    bytes memory _innerCallData = _claimCalldata('othername', _NPUB_HASH, _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _other, 0));
  }

  function test_IsSponsorable_WhenNameIsUnavailable() external {
    _claimUsername();

    bytes memory _innerCallData =
      _claimCalldata(_NAME, keccak256('npub1other'), _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _other, 0));
  }

  function test_IsSponsorable_WhenNameIsReserved() external {
    bytes32 _nameHash = keccak256(bytes(_NAME));
    vm.prank(_owner);
    _nft.setReservedName(_nameHash, true);

    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _claimer, 0));
  }

  function test_IsSponsorable_WhenNostrSignatureLengthIsInvalid() external view {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, hex'010203');

    assertFalse(_policy.isSponsorable(address(_nft), _innerCallData, _claimer, 0));
  }

  function _claimUsername() internal {
    bytes32 _digest = _nft.hashClaimBinding(_NPUB_HASH, _claimer, _NAME, 1, _ISSUED_AT, _SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    bytes memory _evmSignature = abi.encodePacked(_r, _s, _v);

    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }
}
