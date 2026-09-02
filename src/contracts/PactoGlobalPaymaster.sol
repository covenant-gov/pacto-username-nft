// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UserOpCalldataLib} from 'contracts/utils/UserOpCalldataLib.sol';
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
/// @notice ERC-4337 paymaster for username NFT holders with modular action policy
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

  /// @inheritdoc IPactoGlobalPaymaster
  address public immutable ALLOWED_7702_IMPLEMENTATION;

  /// @notice Username NFT used for eligibility checks
  IPactoUsernameNFT internal immutable _USERNAME_NFT;

  /// @notice Global sponsor pool billed on successful UserOps
  IGlobalSponsorPool internal immutable _POOL;

  /// @notice Default policy registry when payload policy is zero
  ISponsorPolicy internal immutable _DEFAULT_POLICY;

  /// @notice Initializes the global paymaster
  /// @param entryPoint The ERC-4337 EntryPoint v0.7
  /// @param usernameNft The username NFT contract
  /// @param pool The global sponsor pool
  /// @param defaultPolicy The default sponsor policy registry
  /// @param allowed7702Implementation The allowlisted EIP-7702 account implementation
  constructor(
    IEntryPoint entryPoint,
    IPactoUsernameNFT usernameNft,
    IGlobalSponsorPool pool,
    ISponsorPolicy defaultPolicy,
    address allowed7702Implementation
  ) BasePaymaster(entryPoint) {
    if (usernameNft == IPactoUsernameNFT(address(0)) || pool == IGlobalSponsorPool(address(0))) {
      revert GlobalPaymaster_ZeroAddress();
    }
    if (defaultPolicy == ISponsorPolicy(address(0))) revert GlobalPaymaster_ZeroAddress();

    _USERNAME_NFT = usernameNft;
    _POOL = pool;
    _DEFAULT_POLICY = defaultPolicy;
    ALLOWED_7702_IMPLEMENTATION = allowed7702Implementation;
  }

  /// @notice Accepts ETH refunded from the global pool after spendGas
  receive() external payable {}

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded) return;
    _POOL.spendGas(actualGasCost);
  }

  /// @inheritdoc BasePaymaster
  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal view override returns (bytes memory context, uint256 validationData) {
    PaymasterData memory _data = _parsePaymasterData(userOp.paymasterAndData);

    uint256 _requiredBalance = (maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    if (_POOL.spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (!_isMemberBindingValid(userOp.getSender(), _data.member)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    (bytes32 _npubHash, uint256 _tokenId) = _USERNAME_NFT.eligibleMember(_data.member);
    if (_npubHash == bytes32(0) || _npubHash != _data.npubHash) {
      return ('', SIG_VALIDATION_FAILED);
    }

    (address _target, , bytes calldata _innerCallData, bool _validCall) = UserOpCalldataLib.decodeExecute(userOp.callData);
    if (!_validCall) revert GlobalPaymaster_InvalidCallData();

    ISponsorPolicy _policy = _data.policy == address(0) ? _DEFAULT_POLICY : ISponsorPolicy(_data.policy);

    if (!_policy.isSponsorable(_target, _innerCallData, _data.member, _tokenId)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    context = hex'01';
    validationData = 0;
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
