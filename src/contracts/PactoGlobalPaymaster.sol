// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

import {BasePaymaster} from '@account-abstraction/core/BasePaymaster.sol';
import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {UserOperationLib} from '@account-abstraction/core/UserOperationLib.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

/// @title PactoGlobalPaymaster
/// @notice ERC-4337 paymaster with bootstrap mint and member sponsorship lanes
contract PactoGlobalPaymaster is IPactoGlobalPaymaster, BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  /// @inheritdoc IPactoGlobalPaymaster
  uint8 public constant PAYMASTER_DATA_VERSION = 1;

  /// @notice Pool balance headroom required vs maxCost (115%)
  uint256 internal constant _BALANCE_HEADROOM_BPS = 11_500;

  /// @notice EIP-7702 designated-code prefix length including implementation
  uint256 internal constant _EIP7702_CODE_LENGTH = 23;

  /// @notice EIP-7702 designated-code magic prefix
  bytes3 internal constant _EIP7702_PREFIX = 0xef0100;

  /// @notice `claim(string,bytes32,bytes32,uint256,uint256,bytes32,bytes,bytes)` selector
  bytes4 internal constant _CLAIM_SELECTOR = 0x9824550d;

  /// @notice PostOp context tag for bootstrap lane billing
  bytes1 internal constant _BOOTSTRAP_CONTEXT = 0x00;

  /// @notice PostOp context tag for member lane billing
  bytes1 internal constant _MEMBER_CONTEXT = 0x01;

  /// @notice Protocol registry used to resolve live NFT, pools, and policies
  IPactoProtocolRegistry internal immutable _REGISTRY;

  /// @notice Initializes the global paymaster
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param registry The protocol registry
  constructor(IEntryPoint entryPoint, IPactoProtocolRegistry registry) BasePaymaster(entryPoint) {
    if (registry == IPactoProtocolRegistry(address(0))) revert GlobalPaymaster_ZeroAddress();
    _REGISTRY = registry;
  }

  /// @inheritdoc IPactoGlobalPaymaster
  function REGISTRY() public view returns (address registry) {
    registry = address(_REGISTRY);
  }

  /// @inheritdoc IPactoGlobalPaymaster
  function ALLOWED_7702_IMPLEMENTATION() public view returns (address implementation) {
    implementation = _REGISTRY.allowed7702Implementation();
  }

  /// @notice Accepts ETH refunded from sponsor pools after spendGas
  receive() external payable {}

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded || context.length == 0) return;

    if (context[0] == _BOOTSTRAP_CONTEXT) {
      IBootstrapMintPool(payable(_REGISTRY.bootstrapPool())).spendGas(actualGasCost);
      return;
    }

    if (context[0] == _MEMBER_CONTEXT) {
      IGlobalSponsorPool(payable(_REGISTRY.pool())).spendGas(actualGasCost);
    }
  }

  /// @inheritdoc BasePaymaster
  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal view override returns (bytes memory context, uint256 validationData) {
    PaymasterData memory _data = _parsePaymasterData(userOp.paymasterAndData);

    if (!_isMemberBindingValid(userOp.getSender(), _data.member)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    (address _target, uint256 _value, bytes calldata _innerCallData, bool _validCall) =
      UserOpCalldataLib.decodeExecute(userOp.callData);
    if (!_validCall) revert GlobalPaymaster_InvalidCallData();

    if (_usernameNft().npubOf(_data.member) == bytes32(0)) {
      return _validateBootstrapPath(_data, _target, _value, _innerCallData, maxCost);
    }

    return _validateMemberPath(_data, _target, _innerCallData, maxCost);
  }

  /// @notice Validates bootstrap mint sponsorship for pre-claim members
  function _validateBootstrapPath(
    PaymasterData memory data,
    address target,
    uint256 value,
    bytes calldata innerCallData,
    uint256 maxCost
  ) internal view returns (bytes memory context, uint256 validationData) {
    uint256 _requiredBalance = (maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    if (IBootstrapMintPool(payable(_REGISTRY.bootstrapPool())).spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (value != 0) return ('', SIG_VALIDATION_FAILED);

    (bytes32 _claimNpubHash, bool _validClaim) = _decodeClaimNpubHash(innerCallData);
    if (!_validClaim || _claimNpubHash != data.npubHash) return ('', SIG_VALIDATION_FAILED);

    if (!_bootstrapPolicy().isSponsorable(target, innerCallData, data.member, 0)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    context = abi.encodePacked(_BOOTSTRAP_CONTEXT);
    validationData = 0;
  }

  /// @notice Validates member sponsorship for existing username NFT holders
  function _validateMemberPath(
    PaymasterData memory data,
    address target,
    bytes calldata innerCallData,
    uint256 maxCost
  ) internal view returns (bytes memory context, uint256 validationData) {
    if (data.policy != address(0)) revert GlobalPaymaster_CustomPolicyNotAllowed();

    uint256 _requiredBalance = (maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    if (IGlobalSponsorPool(payable(_REGISTRY.pool())).spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    (bytes32 _npubHash, uint256 _tokenId) = _usernameNft().eligibleMember(data.member);
    if (_npubHash == bytes32(0) || _npubHash != data.npubHash) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (!_defaultPolicy().isSponsorable(target, innerCallData, data.member, _tokenId)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    context = abi.encodePacked(_MEMBER_CONTEXT);
    validationData = 0;
  }

  /// @notice Decodes the npub hash from a claim() calldata payload
  function _decodeClaimNpubHash(bytes calldata callData) internal pure returns (bytes32 npubHash, bool valid) {
    if (callData.length < 4) return (bytes32(0), false);
    if (bytes4(callData[:4]) != _CLAIM_SELECTOR) return (bytes32(0), false);

    (, npubHash,,,,,,) = abi.decode(callData[4:], (string, bytes32, bytes32, uint256, uint256, bytes32, bytes, bytes));

    valid = true;
  }

  /// @notice Validates member binding for EOAs and EIP-7702 delegated senders
  /// @param sender The UserOp sender address
  /// @param member The member address from paymaster data
  /// @return valid True when the sender is bound to the member
  function _isMemberBindingValid(address sender, address member) internal view returns (bool valid) {
    if (member == address(0)) return false;

    bytes memory _code = sender.code;
    if (_code.length == 0) {
      if (sender != member) revert GlobalPaymaster_InvalidMemberBinding(sender, member);
      return true;
    }

    if (_isEip7702Delegation(_code)) {
      if (sender != member) revert GlobalPaymaster_InvalidMemberBinding(sender, member);
      address _impl = _eip7702Implementation(_code);
      if (_impl != ALLOWED_7702_IMPLEMENTATION()) revert GlobalPaymaster_Invalid7702Implementation(_impl);
      return true;
    }

    return sender == member;
  }

  /// @notice True when code is an EIP-7702 delegation stub
  /// @param code The account bytecode
  /// @return isDelegation Whether the code matches the designated format
  function _isEip7702Delegation(bytes memory code) internal pure returns (bool isDelegation) {
    return code.length == _EIP7702_CODE_LENGTH && bytes3(code) == _EIP7702_PREFIX;
  }

  /// @notice Extracts the implementation address from an EIP-7702 delegation stub
  /// @param code The 23-byte designated code
  /// @return implementation The delegated implementation address
  function _eip7702Implementation(bytes memory code) internal pure returns (address implementation) {
    assembly ('memory-safe') {
      implementation := shr(96, mload(add(code, 35)))
    }
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

  /// @notice Resolves the live username NFT from the protocol registry
  function _usernameNft() internal view returns (IPactoUsernameNFT usernameNft) {
    usernameNft = IPactoUsernameNFT(_REGISTRY.usernameNft());
  }

  /// @notice Resolves the live member policy from the protocol registry
  function _defaultPolicy() internal view returns (ISponsorPolicy defaultPolicy) {
    defaultPolicy = ISponsorPolicy(_REGISTRY.policy());
  }

  /// @notice Resolves the live bootstrap policy from the protocol registry
  function _bootstrapPolicy() internal view returns (ISponsorPolicy bootstrapPolicy) {
    bootstrapPolicy = ISponsorPolicy(_REGISTRY.bootstrapPolicy());
  }
}
