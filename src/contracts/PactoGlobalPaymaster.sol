// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
import {IBootstrapMintPool} from 'interfaces/IBootstrapMintPool.sol';
import {IGlobalSponsorPool} from 'interfaces/IGlobalSponsorPool.sol';
import {IPactoGlobalPaymaster} from 'interfaces/IPactoGlobalPaymaster.sol';
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

  /// @inheritdoc IPactoGlobalPaymaster
  address public immutable ALLOWED_7702_IMPLEMENTATION;

  /// @notice Username NFT used for eligibility checks
  IPactoUsernameNFT internal immutable _USERNAME_NFT;

  /// @notice Global sponsor pool billed on successful member UserOps
  IGlobalSponsorPool internal immutable _POOL;

  /// @notice Bootstrap mint pool billed on successful bootstrap claim UserOps
  IBootstrapMintPool internal immutable _BOOTSTRAP_POOL;

  /// @notice Default policy registry for member actions
  ISponsorPolicy internal immutable _DEFAULT_POLICY;

  /// @notice Fixed policy for bootstrap claim sponsorship
  ISponsorPolicy internal immutable _BOOTSTRAP_POLICY;

  /// @notice Initializes the global paymaster
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param usernameNft The username NFT contract
  /// @param pool The global sponsor pool
  /// @param bootstrapPool The bootstrap mint pool
  /// @param defaultPolicy The default sponsor policy registry
  /// @param bootstrapPolicy The fixed bootstrap claim policy
  /// @param allowed7702Implementation The allowlisted EIP-7702 account implementation
  constructor(
    IEntryPoint entryPoint,
    IPactoUsernameNFT usernameNft,
    IGlobalSponsorPool pool,
    IBootstrapMintPool bootstrapPool,
    ISponsorPolicy defaultPolicy,
    ISponsorPolicy bootstrapPolicy,
    address allowed7702Implementation
  ) BasePaymaster(entryPoint) {
    if (
      usernameNft == IPactoUsernameNFT(address(0)) || pool == IGlobalSponsorPool(address(0))
        || bootstrapPool == IBootstrapMintPool(address(0))
    ) revert GlobalPaymaster_ZeroAddress();
    if (defaultPolicy == ISponsorPolicy(address(0)) || bootstrapPolicy == ISponsorPolicy(address(0))) {
      revert GlobalPaymaster_ZeroAddress();
    }

    _USERNAME_NFT = usernameNft;
    _POOL = pool;
    _BOOTSTRAP_POOL = bootstrapPool;
    _DEFAULT_POLICY = defaultPolicy;
    _BOOTSTRAP_POLICY = bootstrapPolicy;
    ALLOWED_7702_IMPLEMENTATION = allowed7702Implementation;
  }

  /// @notice Accepts ETH refunded from sponsor pools after spendGas
  receive() external payable {}

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded || context.length == 0) return;

    if (context[0] == _BOOTSTRAP_CONTEXT) {
      _BOOTSTRAP_POOL.spendGas(actualGasCost);
      return;
    }

    if (context[0] == _MEMBER_CONTEXT) {
      _POOL.spendGas(actualGasCost);
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

    if (_USERNAME_NFT.npubOf(_data.member) == bytes32(0)) {
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
    if (_BOOTSTRAP_POOL.spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (value != 0) return ('', SIG_VALIDATION_FAILED);

    (bytes32 _claimNpubHash, bool _validClaim) = _decodeClaimNpubHash(innerCallData);
    if (!_validClaim || _claimNpubHash != data.npubHash) return ('', SIG_VALIDATION_FAILED);

    if (!_BOOTSTRAP_POLICY.isSponsorable(target, innerCallData, data.member, 0)) {
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
    if (_POOL.spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    (bytes32 _npubHash, uint256 _tokenId) = _USERNAME_NFT.eligibleMember(data.member);
    if (_npubHash == bytes32(0) || _npubHash != data.npubHash) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (!_DEFAULT_POLICY.isSponsorable(target, innerCallData, data.member, _tokenId)) {
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
      if (_impl != ALLOWED_7702_IMPLEMENTATION) revert GlobalPaymaster_Invalid7702Implementation(_impl);
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
}
