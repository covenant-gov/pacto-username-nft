// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {BootstrapClaimPolicy} from 'contracts/BootstrapClaimPolicy.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';
import {PactoGlobalPaymasterHarness} from 'test/mocks/PactoGlobalPaymasterHarness.sol';

contract UnitPactoGlobalPaymaster is ProtocolRegistryTestBase {
  uint256 internal constant _CLAIMER_PK = 0xA11CE;

  address internal _owner = makeAddr('owner');
  address internal _claimer;
  address internal _target = makeAddr('target');
  address internal _allowed7702 = makeAddr('allowed7702');
  bytes32 internal constant _PUBKEY = 0x391823cee659f38512ccde6c2bb6f4e32e917478ee2e96d4f5e05656e7adb2ae;
  bytes32 internal constant _NPUB_HASH = 0x540d126644e922328318f1870ba0c9de3b2d5c0c271e27af7efea3e44025fdc1;
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  string internal constant _NAME = 'daopunk';

  bytes internal constant _NOSTR_SIGNATURE =
    hex'715358459e600817a7e0fb4371b594a9e36f8c4f0272a41e4248fc3b1021accf6cdf2d2718424a5491d94ae1935fbb1b569c3e92b23269143e71e3635be3efb2';

  MockEntryPoint internal _entryPoint;
  PactoProtocolRegistry internal _registry;
  PactoUsernameNFT internal _nft;
  GlobalSponsorPool internal _pool;
  BootstrapMintPool internal _bootstrapPool;
  SponsorPolicyRegistry internal _policy;
  BootstrapClaimPolicy internal _bootstrapPolicy;
  PactoGlobalPaymasterHarness internal _paymaster;

  function setUp() external {
    _claimer = vm.addr(_CLAIMER_PK);
    vm.warp(_ISSUED_AT);

    _entryPoint = new MockEntryPoint();
    _registry = new PactoProtocolRegistry(_owner, address(this));
    _pool = new GlobalSponsorPool(_registry);
    _bootstrapPool = new BootstrapMintPool(_registry);
    _nft = new PactoUsernameNFT();
    _policy = new SponsorPolicyRegistry(_owner);
    _bootstrapPolicy = new BootstrapClaimPolicy(_registry);

    _paymaster = new PactoGlobalPaymasterHarness(IEntryPoint(address(_entryPoint)), _registry);

    _initializeRegistry(
      _registry,
      address(_nft),
      address(_paymaster),
      address(_pool),
      address(_bootstrapPool),
      address(_policy),
      address(_bootstrapPolicy),
      address(_entryPoint),
      _allowed7702
    );

    vm.deal(address(this), 20 ether);
    _pool.deposit{value: 10 ether}();
    _bootstrapPool.deposit{value: 10 ether}();
  }

  function test_ExposedValidate_WhenMemberIsEligibleAndPolicyAllowsTheCall() external {
    _claimUsername();
    vm.prank(_owner);
    _policy.registerTarget(_target);

    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _target, hex'', 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    (bytes memory _context, uint256 _validationData) = _paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, hex'01');
  }

  function test_ExposedValidate_WhenPolicyDeniesTheCall() external {
    _claimUsername();

    address _deniedTarget = makeAddr('denied');
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _deniedTarget, hex'', 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_MemberNotSponsorable.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenCustomPolicyIsProvidedOnMemberPath() external {
    _claimUsername();
    vm.prank(_owner);
    _policy.registerTarget(_target);

    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _target, hex'', 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, makeAddr('customPolicy'));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_CustomPolicyNotAllowed.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenBootstrapClaimIsValidWithoutAnNft() external {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    (bytes memory _context, uint256 _validationData) = _paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, hex'00');
  }

  function test_ExposedValidate_WhenBootstrapExecuteValueIsNonZero() external {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 1);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_NonZeroValue.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenBootstrapNpubHashDoesNotMatchPayload() external {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(keccak256('other-npub'), _claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_InvalidClaimPayload.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenBootstrapPoolHasInsufficientHeadroom() external {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    uint256 _required = (10 ether * 11_500) / 10_000;
    vm.expectRevert(
      abi.encodeWithSelector(
        IPactoGlobalPaymaster.GlobalPaymaster_InsufficientBootstrapPool.selector, 10 ether, _required
      )
    );
    _paymaster.exposedValidate(_userOp, 10 ether);
  }

  function test_ExposedValidate_WhenBootstrapTargetIsNotRegistryNft() external {
    PactoUsernameNFT _otherNft = new PactoUsernameNFT();
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_otherNft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_BootstrapNotSponsorable.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenEip7702DelegationMatchesAllowlist() external {
    bytes memory _stub = abi.encodePacked(bytes3(0xef0100), bytes20(_allowed7702));
    vm.etch(_claimer, _stub);

    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    (bytes memory _context, uint256 _validationData) = _paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, hex'00');
  }

  function test_ExposedValidate_WhenEip7702DelegationImplIsWrong() external {
    address _wrongImpl = makeAddr('wrong7702');
    bytes memory _stub = abi.encodePacked(bytes3(0xef0100), bytes20(_wrongImpl));
    vm.etch(_claimer, _stub);

    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    vm.expectRevert(
      abi.encodeWithSelector(IPactoGlobalPaymaster.GlobalPaymaster_Invalid7702Implementation.selector, _wrongImpl)
    );
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedValidate_WhenMemberIsZero() external {
    bytes memory _innerCallData = _claimCalldata(_NAME, _NPUB_HASH, _NOSTR_SIGNATURE);
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, address(_nft), _innerCallData, 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, address(0), address(0));

    vm.expectRevert(IPactoGlobalPaymaster.GlobalPaymaster_ZeroMember.selector);
    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_ExposedPostOp_WhenBootstrapPathBillsBootstrapPool() external {
    uint256 _poolBefore = _bootstrapPool.spendablePoolWei();
    uint256 _paymasterBefore = address(_paymaster).balance;

    _paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, hex'00', 0.25 ether);

    assertEq(_bootstrapPool.spendablePoolWei(), _poolBefore - 0.25 ether);
    assertEq(address(_paymaster).balance, _paymasterBefore + 0.25 ether);
    assertEq(_pool.spendablePoolWei(), 10 ether);
  }

  function test_ExposedPostOp_WhenMemberPathBillsGlobalPool() external {
    uint256 _poolBefore = _pool.spendablePoolWei();
    uint256 _paymasterBefore = address(_paymaster).balance;

    _paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, hex'01', 0.25 ether);

    assertEq(_pool.spendablePoolWei(), _poolBefore - 0.25 ether);
    assertEq(address(_paymaster).balance, _paymasterBefore + 0.25 ether);
    assertEq(_bootstrapPool.spendablePoolWei(), 10 ether);
  }

  function _claimUsername() internal {
    bytes32 _digest = _nft.hashClaimBinding(_NPUB_HASH, _claimer, _NAME, 1, _ISSUED_AT, _SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    bytes memory _evmSignature = abi.encodePacked(_r, _s, _v);

    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
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

  function _buildUserOp(
    address sender,
    address target,
    bytes memory innerCallData,
    uint256 value
  ) internal pure returns (PackedUserOperation memory userOp) {
    bytes memory _accountCallData =
      abi.encodeWithSelector(UserOpCalldataLib.EXECUTE_SELECTOR, target, value, innerCallData);

    userOp = PackedUserOperation({
      sender: sender,
      nonce: 0,
      initCode: hex'',
      callData: _accountCallData,
      accountGasLimits: bytes32(uint256(0)),
      preVerificationGas: 0,
      gasFees: bytes32(uint256(0)),
      paymasterAndData: hex'',
      signature: hex''
    });
  }

  function _buildPaymasterData(bytes32 npubHash, address member, address policy) internal view returns (bytes memory) {
    return abi.encodePacked(
      bytes20(bytes20(address(_paymaster))),
      bytes16(uint128(150_000)),
      bytes16(uint128(50_000)),
      abi.encode(uint8(1), npubHash, member, policy)
    );
  }
}
