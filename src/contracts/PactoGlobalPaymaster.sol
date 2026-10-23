// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Eip7702Lib} from 'contracts/libraries/Eip7702Lib.sol';
import {PaymasterHeadroomLib} from 'contracts/libraries/PaymasterHeadroomLib.sol';
import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

import {BasePaymaster} from '@account-abstraction/core/BasePaymaster.sol';
import {UserOperationLib} from '@account-abstraction/core/UserOperationLib.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

/// @title PactoGlobalPaymaster
/// @notice ERC-4337 paymaster with bootstrap mint and member sponsorship lanes
contract PactoGlobalPaymaster is IPactoGlobalPaymaster, BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  /// @inheritdoc IPactoGlobalPaymaster
  uint8 public constant PAYMASTER_DATA_VERSION = 1;

  /// @notice `claim(string,bytes32,bytes32,uint256,uint256,bytes32,bytes,bytes)` selector
  bytes4 internal constant _CLAIM_SELECTOR = 0x9824550d;

  /// @notice PostOp context tag for bootstrap lane billing
  bytes1 internal constant _BOOTSTRAP_CONTEXT = 0x00;

  /// @notice PostOp context tag for member lane billing
  bytes1 internal constant _MEMBER_CONTEXT = 0x01;

  /// @inheritdoc IPactoGlobalPaymaster
  IPactoProtocolRegistry public immutable REGISTRY;

  /// @inheritdoc IPactoGlobalPaymaster
  IPactoUsernameNFT public immutable USERNAME_NFT;

  /// @inheritdoc IPactoGlobalPaymaster
  ISponsorPolicy public immutable POLICY;

  /// @inheritdoc IPactoGlobalPaymaster
  ISponsorPolicy public immutable BOOTSTRAP_POLICY;

  /// @inheritdoc IPactoGlobalPaymaster
  IGlobalSponsorPool public immutable POOL;

  /// @inheritdoc IPactoGlobalPaymaster
  IBootstrapMintPool public immutable BOOTSTRAP_POOL;

  /// @inheritdoc IPactoGlobalPaymaster
  address public immutable ALLOWED_7702_IMPLEMENTATION;

  /// @notice Initializes the global paymaster
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param registry The protocol registry for this generation
  /// @param usernameNft The username NFT used for membership
  /// @param policy The member-path sponsor policy
  /// @param bootstrapPolicy The bootstrap-claim sponsor policy
  /// @param pool The member-path sponsor pool
  /// @param bootstrapPool The bootstrap-claim sponsor pool
  /// @param allowed7702 The allowlisted EIP-7702 account implementation
  constructor(
    IEntryPoint entryPoint,
    IPactoProtocolRegistry registry,
    IPactoUsernameNFT usernameNft,
    ISponsorPolicy policy,
    ISponsorPolicy bootstrapPolicy,
    IGlobalSponsorPool pool,
    IBootstrapMintPool bootstrapPool,
    address allowed7702
  ) BasePaymaster(entryPoint) {
    if (
      address(entryPoint) == address(0) || address(registry) == address(0) || address(usernameNft) == address(0)
        || address(policy) == address(0) || address(bootstrapPolicy) == address(0) || address(pool) == address(0)
        || address(bootstrapPool) == address(0) || allowed7702 == address(0)
    ) revert GlobalPaymaster_ZeroAddress();

    REGISTRY = registry;
    USERNAME_NFT = usernameNft;
    POLICY = policy;
    BOOTSTRAP_POLICY = bootstrapPolicy;
    POOL = pool;
    BOOTSTRAP_POOL = bootstrapPool;
    ALLOWED_7702_IMPLEMENTATION = allowed7702;
  }

  /// @notice Accepts ETH refunded from sponsor pools after spendGas
  receive() external payable {}

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded || context.length == 0) return;

    if (context[0] == _BOOTSTRAP_CONTEXT) {
      BOOTSTRAP_POOL.spendGas(actualGasCost);
      return;
    }

    if (context[0] == _MEMBER_CONTEXT) {
      POOL.spendGas(actualGasCost);
    }
  }

  /// @inheritdoc BasePaymaster
  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal view override returns (bytes memory context, uint256 validationData) {
    PaymasterData memory _data = _parsePaymasterData(userOp.paymasterAndData);

    _requireMemberBindingValid(userOp.getSender(), _data.member);

    (address _target, uint256 _value, bytes calldata _innerCallData, bool _validCall) =
      UserOpCalldataLib.decodeExecute(userOp.callData);
    if (!_validCall) revert GlobalPaymaster_InvalidCallData();

    (bytes32 _npubHash, uint64 _tokenId) = USERNAME_NFT.membership(_data.member);
    if (_npubHash == bytes32(0)) {
      return _validateBootstrapPath(_data, _target, _value, _innerCallData, maxCost);
    }

    return _validateMemberPath(_data, _npubHash, _tokenId, _target, _innerCallData, maxCost);
  }

  /// @notice Validates bootstrap mint sponsorship for pre-claim members
  /// @param data The parsed paymaster payload
  /// @param target The inner call target
  /// @param value The inner call value
  /// @param innerCallData The inner call payload
  /// @param maxCost The EntryPoint maximum cost
  /// @return context The bootstrap postOp context tag
  /// @return validationData Zero when the user operation is valid
  function _validateBootstrapPath(
    PaymasterData memory data,
    address target,
    uint256 value,
    bytes calldata innerCallData,
    uint256 maxCost
  ) internal view returns (bytes memory context, uint256 validationData) {
    {
      uint256 _requiredBalance = PaymasterHeadroomLib.requiredWei(maxCost);
      uint256 _spendable = BOOTSTRAP_POOL.spendablePoolWei();
      if (_spendable < _requiredBalance) {
        revert GlobalPaymaster_InsufficientBootstrapPool(_spendable, _requiredBalance);
      }
    }

    if (value != 0) revert GlobalPaymaster_NonZeroValue();

    {
      (bytes32 _claimNpubHash, bool _validClaim) = _decodeClaimNpubHash(innerCallData);
      if (!_validClaim || _claimNpubHash != data.npubHash) revert GlobalPaymaster_InvalidClaimPayload();
    }

    if (!BOOTSTRAP_POLICY.isSponsorable(target, innerCallData, data.member, 0)) {
      revert GlobalPaymaster_BootstrapNotSponsorable();
    }

    context = abi.encodePacked(_BOOTSTRAP_CONTEXT);
    validationData = 0;
  }

  /// @notice Validates member sponsorship for existing username NFT holders
  /// @param data The parsed paymaster payload
  /// @param npubHash The membership npub hash
  /// @param tokenId The membership token id
  /// @param target The inner call target
  /// @param innerCallData The inner call payload
  /// @param maxCost The EntryPoint maximum cost
  /// @return context The member postOp context tag
  /// @return validationData Zero when the user operation is valid
  function _validateMemberPath(
    PaymasterData memory data,
    bytes32 npubHash,
    uint64 tokenId,
    address target,
    bytes calldata innerCallData,
    uint256 maxCost
  ) internal view returns (bytes memory context, uint256 validationData) {
    if (data.policy != address(0)) revert GlobalPaymaster_CustomPolicyNotAllowed();

    {
      uint256 _requiredBalance = PaymasterHeadroomLib.requiredWei(maxCost);
      uint256 _spendable = POOL.spendablePoolWei();
      if (_spendable < _requiredBalance) {
        revert GlobalPaymaster_InsufficientMemberPool(_spendable, _requiredBalance);
      }
    }

    if (npubHash != data.npubHash) revert GlobalPaymaster_IneligibleMember();

    if (target == address(USERNAME_NFT) && innerCallData.length >= 4 && bytes4(innerCallData[:4]) == _CLAIM_SELECTOR) {
      revert GlobalPaymaster_MemberNotSponsorable();
    }

    if (!POLICY.isSponsorable(target, innerCallData, data.member, tokenId)) {
      revert GlobalPaymaster_MemberNotSponsorable();
    }

    context = abi.encodePacked(_MEMBER_CONTEXT);
    validationData = 0;
  }

  /// @notice Validates member binding for EOAs and EIP-7702 delegated senders
  /// @param sender The UserOp sender address
  /// @param member The member address from paymaster data
  function _requireMemberBindingValid(address sender, address member) internal view {
    if (member == address(0)) revert GlobalPaymaster_ZeroMember();

    bytes memory _code = sender.code;
    if (_code.length == 0) {
      if (sender != member) revert GlobalPaymaster_InvalidMemberBinding(sender, member);
      return;
    }

    if (Eip7702Lib.isDelegation(_code)) {
      if (sender != member) revert GlobalPaymaster_InvalidMemberBinding(sender, member);
      address _impl = Eip7702Lib.implementation(_code);
      if (_impl != ALLOWED_7702_IMPLEMENTATION) revert GlobalPaymaster_Invalid7702Implementation(_impl);
      return;
    }

    if (sender != member) revert GlobalPaymaster_InvalidMemberBinding(sender, member);
  }

  /// @notice Decodes the npub hash from a claim() calldata payload
  /// @param callData The inner call data
  /// @return npubHash The claim npub hash, or zero when the payload is not a claim
  /// @return valid True when the payload is a decodable claim
  function _decodeClaimNpubHash(bytes calldata callData) internal pure returns (bytes32 npubHash, bool valid) {
    if (callData.length < 4) return (bytes32(0), false);
    if (bytes4(callData[:4]) != _CLAIM_SELECTOR) return (bytes32(0), false);

    (, npubHash,,,,,,) = abi.decode(callData[4:], (string, bytes32, bytes32, uint256, uint256, bytes32, bytes, bytes));

    valid = true;
  }

  /// @notice Decodes global paymaster payload from paymasterAndData
  /// @param paymasterAndData The full ERC-4337 paymaster field
  /// @return data The parsed paymaster payload
  function _parsePaymasterData(bytes calldata paymasterAndData) internal pure returns (PaymasterData memory data) {
    bytes calldata _payload = paymasterAndData[UserOperationLib.PAYMASTER_DATA_OFFSET:];
    uint8 _version;
    (_version, data.npubHash, data.member, data.policy) = abi.decode(_payload, (uint8, bytes32, address, address));
    if (_version != PAYMASTER_DATA_VERSION) revert GlobalPaymaster_InvalidVersion(_version);
  }
}
