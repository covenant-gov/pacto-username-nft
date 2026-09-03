// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';
import {BootstrapClaimPolicy} from 'contracts/BootstrapClaimPolicy.sol';
import {BootstrapMintPool} from 'contracts/BootstrapMintPool.sol';
import {GlobalSponsorPool} from 'contracts/GlobalSponsorPool.sol';
import {PactoProtocolRegistry} from 'contracts/PactoProtocolRegistry.sol';
import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';
import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {ProtocolRegistryTestBase} from 'test/helpers/ProtocolRegistryTestBase.sol';
import {MockEntryPoint} from 'test/mocks/MockEntryPoint.sol';
import {PactoGlobalPaymasterHarness} from 'test/mocks/PactoGlobalPaymasterHarness.sol';

/// @notice Shared full-system wiring for integration tests
contract IntegrationBase is ProtocolRegistryTestBase {
  uint256 internal constant CLAIMER_PK = 0xA11CE;
  uint256 internal constant PENDING_PK = 0xC0FFEE;

  bytes32 internal constant PUBKEY = 0x391823cee659f38512ccde6c2bb6f4e32e917478ee2e96d4f5e05656e7adb2ae;
  bytes32 internal constant NPUB_HASH = 0x540d126644e922328318f1870ba0c9de3b2d5c0c271e27af7efea3e44025fdc1;
  bytes32 internal constant SALT = 0x1111111111111111111111111111111111111111111111111111111111111111;
  uint256 internal constant ISSUED_AT = 1_735_689_600;
  string internal constant USERNAME = 'daopunk';

  bytes internal constant NOSTR_SIGNATURE =
    hex'715358459e600817a7e0fb4371b594a9e36f8c4f0272a41e4248fc3b1021accf6cdf2d2718424a5491d94ae1935fbb1b569c3e92b23269143e71e3635be3efb2';

  bytes4 internal constant INITIATE_ADDRESS_TRANSFER_SELECTOR = 0xa4df29b5;
  bytes4 internal constant CLAIM_ADDRESS_TRANSFER_SELECTOR = 0xbf010955;
  bytes4 internal constant CANCEL_ADDRESS_TRANSFER_SELECTOR = 0xd88208dc;

  address internal owner = makeAddr('owner');
  address internal claimer;
  address internal pending;
  address internal allowed7702 = makeAddr('allowed7702');

  MockEntryPoint internal entryPoint;
  PactoProtocolRegistry internal registry;
  PactoUsernameNFT internal nft;
  GlobalSponsorPool internal pool;
  BootstrapMintPool internal bootstrapPool;
  SponsorPolicyRegistry internal policy;
  BootstrapClaimPolicy internal bootstrapPolicy;
  PactoGlobalPaymasterHarness internal paymaster;

  function setUp() public virtual {
    claimer = vm.addr(CLAIMER_PK);
    pending = vm.addr(PENDING_PK);
    vm.warp(ISSUED_AT);

    entryPoint = new MockEntryPoint();
    registry = new PactoProtocolRegistry(owner, address(this));
    pool = new GlobalSponsorPool(registry);
    bootstrapPool = new BootstrapMintPool(registry);
    nft = new PactoUsernameNFT(owner);
    policy = new SponsorPolicyRegistry(owner);
    bootstrapPolicy = new BootstrapClaimPolicy(registry);

    paymaster = new PactoGlobalPaymasterHarness(IEntryPoint(address(entryPoint)), registry);

    _initializeRegistry(
      registry,
      address(nft),
      address(paymaster),
      address(pool),
      address(bootstrapPool),
      address(policy),
      address(bootstrapPolicy),
      address(entryPoint),
      allowed7702
    );

    vm.startPrank(owner);
    policy.registerSelector(address(nft), INITIATE_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(address(nft), CLAIM_ADDRESS_TRANSFER_SELECTOR);
    policy.registerSelector(address(nft), CANCEL_ADDRESS_TRANSFER_SELECTOR);
    vm.stopPrank();

    vm.deal(address(this), 20 ether);
    pool.deposit{value: 10 ether}();
    bootstrapPool.deposit{value: 10 ether}();
  }

  function claimSignature(
    address evmAddress,
    string memory name,
    bytes32 npubHash,
    uint256 nonce
  ) internal view returns (bytes memory signature) {
    bytes32 _digest = nft.hashClaimBinding(npubHash, evmAddress, name, nonce, ISSUED_AT, SALT);
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(CLAIMER_PK, _digest);
    signature = abi.encodePacked(_r, _s, _v);
  }

  function claimCalldata(
    string memory name,
    bytes32 npubHash,
    bytes memory nostrSignature
  ) internal view returns (bytes memory) {
    return abi.encodeWithSelector(
      bytes4(0x9824550d),
      name,
      npubHash,
      PUBKEY,
      uint256(1),
      ISSUED_AT,
      SALT,
      nostrSignature,
      claimSignature(claimer, name, npubHash, 1)
    );
  }

  function executeClaim() internal {
    bytes memory _innerCallData = claimCalldata(USERNAME, NPUB_HASH, NOSTR_SIGNATURE);
    vm.prank(claimer);
    (bool _success,) = address(nft).call(_innerCallData);
    assertTrue(_success);
  }

  function buildUserOp(
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

  function buildPaymasterData(
    bytes32 npubHash,
    address member,
    address policyAddr
  ) internal view returns (bytes memory) {
    return abi.encodePacked(
      bytes20(bytes20(address(paymaster))),
      bytes16(uint128(150_000)),
      bytes16(uint128(50_000)),
      abi.encode(uint8(1), npubHash, member, policyAddr)
    );
  }

  function buildBootstrapClaimUserOp() internal view returns (PackedUserOperation memory userOp) {
    userOp = buildUserOp(claimer, address(nft), claimCalldata(USERNAME, NPUB_HASH, NOSTR_SIGNATURE), 0);
    userOp.paymasterAndData = buildPaymasterData(NPUB_HASH, claimer, address(0));
  }
}
