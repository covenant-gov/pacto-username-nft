// SPDX-License-Identifier: MIT
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
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';
import {PactoGlobalPaymasterHarness} from 'test/mocks/PactoGlobalPaymasterHarness.sol';

/**
 * @notice Current-code gas baselines for the sponsorship hot path.
 * @dev Staging runs under `pauseGasMetering` in the same transaction as the measured call,
 *      so slots written during staging are warm. Refresh the baseline with
 *      `forge snapshot --match-contract UnitGasHotPaths --snap .gas-snapshot.baseline --offline`
 *      before changing production code. Do not regenerate that file afterward.
 */
contract UnitGasHotPaths is ProtocolRegistryTestBase {
  /// @notice Thrown when a metered call returns an unexpected value
  error GasHotPaths_Unexpected();

  uint256 internal constant _CLAIMER_PK = 0xA11CE;

  address internal _owner = makeAddr('owner');
  address internal _claimer;
  address internal _other = makeAddr('gasOther');
  address internal _pending = makeAddr('gasPending');
  address internal _target = makeAddr('gasTarget');
  address internal _module = makeAddr('gasModule');
  address internal _selectorTarget = makeAddr('gasSelectorTarget');
  address internal _factory = makeAddr('gasFactory');
  address internal _allowed7702 = makeAddr('allowed7702');

  bytes32 internal constant _PUBKEY = 0x391823cee659f38512ccde6c2bb6f4e32e917478ee2e96d4f5e05656e7adb2ae;
  bytes32 internal constant _NPUB_HASH = 0x540d126644e922328318f1870ba0c9de3b2d5c0c271e27af7efea3e44025fdc1;
  bytes32 internal constant _BOOTSTRAP_NPUB = keccak256('gas.bootstrap.npub');
  bytes32 internal constant _SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  uint256 internal constant _ISSUED_AT = 1_735_689_600;
  uint256 internal constant _TOP_HAT_ID = 99;
  string internal constant _NAME = 'daopunk';
  string internal constant _BOOTSTRAP_NAME = 'gasboot';

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

  /// @notice Accepts ETH returned by pool withdraw
  receive() external payable {}

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
    _paymaster = new PactoGlobalPaymasterHarness(
      IEntryPoint(address(_entryPoint)), _nft, _policy, _bootstrapPolicy, _pool, _bootstrapPool, _allowed7702
    );

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

    vm.deal(address(this), 30 ether);
    _pool.deposit{value: 10 ether}();
    _bootstrapPool.deposit{value: 10 ether}();

    vm.startPrank(_owner);
    _policy.registerTarget(_target);
    _policy.setAuthorizedRegistrar(_factory, true);
    vm.stopPrank();
  }

  function test_Gas_NameAvailable() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.resumeGasMetering();

    _require(!_nft.nameAvailable(_NAME));
  }

  function test_Gas_NpubOf() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.resumeGasMetering();

    _require(_nft.npubOf(_claimer) == _NPUB_HASH);
  }

  function test_Gas_EligibleMember() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.resumeGasMetering();

    (bytes32 _npubHash, uint256 _tokenId) = _nft.eligibleMember(_claimer);
    _require(_npubHash == _NPUB_HASH && _tokenId == 1);
  }

  function test_Gas_IsPendingTransfer() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.resumeGasMetering();

    _require(!_nft.isPendingTransfer(_NPUB_HASH));
  }

  function test_Gas_RecordOf() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.resumeGasMetering();

    IPactoUsernameNFT.UsernameRecord memory _record = _nft.recordOf(_NPUB_HASH);
    _require(_record.tokenId == 1);
  }

  function test_Gas_CanBootstrapClaim() external view {
    _require(_nft.canBootstrapClaim(_other, _BOOTSTRAP_NPUB));
  }

  function test_Gas_HashClaimBinding() external view {
    bytes32 _digest = _nft.hashClaimBinding(_NPUB_HASH, _claimer, _NAME, 1, _ISSUED_AT, _SALT);
    _require(_digest != bytes32(0));
  }

  function test_Gas_Claim() external {
    vm.pauseGasMetering();
    bytes memory _evmSignature = _claimSignature();
    vm.prank(_claimer);
    vm.resumeGasMetering();

    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function test_Gas_InitiateAddressTransfer() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.prank(_claimer);
    vm.resumeGasMetering();

    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);
  }

  function test_Gas_ClaimAddressTransfer() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);
    vm.prank(_pending);
    vm.resumeGasMetering();

    _nft.claimAddressTransfer(_NPUB_HASH);
  }

  function test_Gas_CancelAddressTransfer() external {
    vm.pauseGasMetering();
    _claimUsername();
    vm.prank(_claimer);
    _nft.initiateAddressTransfer(_NPUB_HASH, _pending);
    vm.prank(_claimer);
    vm.resumeGasMetering();

    _nft.cancelAddressTransfer(_NPUB_HASH);
  }

  function test_Gas_IsSponsorableContractAllowed() external view {
    _require(_policy.isSponsorable(_target, hex'12345678', address(0), 0));
  }

  function test_Gas_IsSponsorableSelector() external {
    bytes4 _selector = 0x12345678;

    vm.pauseGasMetering();
    vm.prank(_owner);
    _policy.registerSelector(_selectorTarget, _selector);
    vm.resumeGasMetering();

    _require(_policy.isSponsorable(_selectorTarget, abi.encodePacked(_selector), address(0), 0));
  }

  function test_Gas_IsSponsorableIndexedModule() external {
    vm.pauseGasMetering();
    _registerSponsoredModule();
    vm.resumeGasMetering();

    _require(_policy.isSponsorable(_module, hex'12345678', address(0), 0));
  }

  function test_Gas_IsSponsorableTopHatMissFallsThrough() external {
    vm.pauseGasMetering();
    address _fallthrough = makeAddr('gasFallthrough');

    vm.prank(_owner);
    _policy.registerTarget(_fallthrough);

    address[] memory _modules = new address[](1);
    _modules[0] = _fallthrough;
    vm.prank(_factory);
    _policy.registerModulesForTopHat(_TOP_HAT_ID, _modules);
    vm.resumeGasMetering();

    _require(_policy.isSponsorable(_fallthrough, hex'12345678', address(0), 0));
  }

  function test_Gas_BootstrapIsSponsorable() external view {
    _require(_bootstrapPolicy.isSponsorable(address(_nft), _bootstrapClaimCalldata(), _other, 0));
  }

  function test_Gas_PaymasterMemberValidation() external {
    vm.pauseGasMetering();
    _claimUsername();
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _target, hex'12345678', 0);
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));
    vm.resumeGasMetering();

    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_Gas_PaymasterBootstrapValidation() external {
    vm.pauseGasMetering();
    PackedUserOperation memory _userOp = _buildUserOp(_other, address(_nft), _bootstrapClaimCalldata(), 0);
    _userOp.paymasterAndData = _buildPaymasterData(_BOOTSTRAP_NPUB, _other, address(0));
    vm.resumeGasMetering();

    _paymaster.exposedValidate(_userOp, 1 ether);
  }

  function test_Gas_PaymasterPostOpMember() external {
    _paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, hex'01', 0.25 ether);
  }

  function test_Gas_PaymasterPostOpBootstrap() external {
    _paymaster.exposedPostOp(IPaymaster.PostOpMode.opSucceeded, hex'00', 0.25 ether);
  }

  function test_Gas_Allowed7702Implementation() external view {
    _require(_paymaster.ALLOWED_7702_IMPLEMENTATION() == _allowed7702);
  }

  function test_Gas_GlobalDeposit() external {
    _pool.deposit{value: 1 ether}();
  }

  function test_Gas_GlobalWithdraw() external {
    _pool.withdraw();
  }

  function test_Gas_GlobalSpendGas() external {
    vm.prank(address(_paymaster));
    _pool.spendGas(0.25 ether);
  }

  function test_Gas_GlobalWithdrawable() external view {
    _require(_pool.withdrawable(address(this)) == 10 ether);
  }

  function test_Gas_BootstrapDeposit() external {
    _bootstrapPool.deposit{value: 1 ether}();
  }

  function test_Gas_BootstrapWithdraw() external {
    _bootstrapPool.withdraw();
  }

  function test_Gas_BootstrapSpendGas() external {
    vm.prank(address(_paymaster));
    _bootstrapPool.spendGas(0.25 ether);
  }

  function test_Gas_BootstrapWithdrawable() external view {
    _require(_bootstrapPool.withdrawable(address(this)) == 10 ether);
  }

  /// @notice Reverts when a metered view returns an unexpected value so via-IR keeps the call
  function _require(bool ok) internal pure {
    if (!ok) revert GasHotPaths_Unexpected();
  }

  function _claimUsername() internal {
    bytes memory _evmSignature = _claimSignature();
    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, _PUBKEY, 1, _ISSUED_AT, _SALT, _NOSTR_SIGNATURE, _evmSignature);
  }

  function _claimSignature() internal view returns (bytes memory signature) {
    bytes32 _digest = _nft.hashClaimBinding(_NPUB_HASH, _claimer, _NAME, 1, _ISSUED_AT, _SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }

  function _bootstrapClaimCalldata() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      bytes4(0x9824550d),
      _BOOTSTRAP_NAME,
      _BOOTSTRAP_NPUB,
      _PUBKEY,
      uint256(1),
      _ISSUED_AT,
      _SALT,
      _NOSTR_SIGNATURE,
      hex'0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233343536'
    );
  }

  function _registerSponsoredModule() internal {
    address[] memory _modules = new address[](1);
    _modules[0] = _module;

    vm.startPrank(_factory);
    _policy.registerTopHat(_TOP_HAT_ID);
    _policy.registerModulesForTopHat(_TOP_HAT_ID, _modules);
    vm.stopPrank();
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
