// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {Test} from 'forge-std/Test.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';
import {PactoGlobalPaymasterHarness} from 'test/mocks/PactoGlobalPaymasterHarness.sol';

contract UnitPactoGlobalPaymaster is Test {
  uint256 internal constant _CLAIMER_PK = 0xA11CE;

  address internal _owner = makeAddr('owner');
  address internal _factory = makeAddr('factory');
  address internal _claimer;
  address internal _target = makeAddr('target');
  bytes32 internal constant _NPUB_HASH = keccak256('npub1example');
  string internal constant _NAME = 'daopunk';

  MockEntryPoint internal _entryPoint;
  PactoUsernameNFT internal _nft;
  GlobalSponsorPool internal _pool;
  SponsorPolicyRegistry internal _policy;
  PactoGlobalPaymasterHarness internal _paymaster;

  function setUp() external {
    _claimer = vm.addr(_CLAIMER_PK);
    _entryPoint = new MockEntryPoint();
    _pool = new GlobalSponsorPool(_factory);
    _nft = new PactoUsernameNFT(_owner);
    _policy = new SponsorPolicyRegistry(_owner);

    _paymaster =
      new PactoGlobalPaymasterHarness(IEntryPoint(address(_entryPoint)), _nft, _pool, _policy, makeAddr('allowed7702'));

    vm.prank(_factory);
    _pool.wirePaymaster(address(_paymaster));

    vm.deal(address(this), 10 ether);
    _pool.deposit{value: 10 ether}();

    _claimUsername();
    vm.prank(_owner);
    _policy.registerTarget(_target);
  }

  function test_ExposedValidate_WhenMemberIsEligibleAndPolicyAllowsTheCall() external {
    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _target, hex'');
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    (bytes memory _context, uint256 _validationData) = _paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertGt(_context.length, 0);
  }

  function test_ExposedValidate_WhenPolicyDeniesTheCall() external {
    address _deniedTarget = makeAddr('denied');

    PackedUserOperation memory _userOp = _buildUserOp(_claimer, _deniedTarget, hex'');
    _userOp.paymasterAndData = _buildPaymasterData(_NPUB_HASH, _claimer, address(0));

    (bytes memory _context, uint256 _validationData) = _paymaster.exposedValidate(_userOp, 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
    assertEq(_context.length, 0);
  }

  function _claimUsername() internal {
    bytes32 _digest = _nft.hashClaimBinding(_NPUB_HASH, _claimer, _NAME, 1, block.timestamp);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_CLAIMER_PK, _digest);
    bytes memory _signature = abi.encodePacked(_r, _s, _v);

    vm.prank(_claimer);
    _nft.claim(_NAME, _NPUB_HASH, 1, block.timestamp, _signature);
  }

  function _buildUserOp(
    address sender,
    address target,
    bytes memory innerCallData
  ) internal pure returns (PackedUserOperation memory userOp) {
    bytes memory _accountCallData = abi.encodeWithSelector(UserOpCalldataLib.EXECUTE_SELECTOR, target, 0, innerCallData);

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
