// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @title SponsorPolicyRegistry
/// @notice Deny-by-default allowlist of sponsorable targets and selectors
contract SponsorPolicyRegistry is ISponsorPolicy, Ownable2Step {
  /// @notice Emitted when a target is registered for contract-wide sponsorship
  event TargetRegistered(address indexed target);

  /// @notice Emitted when a target registration is removed
  event TargetDeregistered(address indexed target);

  /// @notice Emitted when a selector is registered for a target
  event SelectorRegistered(address indexed target, bytes4 indexed selector);

  /// @notice Emitted when a selector registration is removed
  event SelectorDeregistered(address indexed target, bytes4 indexed selector);

  /// @notice Emitted when the policy version is bumped
  event PolicyVersionUpdated(uint256 policyVersion);

  /// @notice Monotonic policy version for client sync
  uint256 public policyVersion;

  /// @notice Whether any call to a target is sponsorable
  mapping(address target => bool allowed) internal _contractAllowed;

  /// @notice Whether a specific selector on a target is sponsorable
  mapping(address target => mapping(bytes4 selector => bool allowed)) internal _selectorAllowed;

  /// @notice Thrown when a target address is zero
  error SponsorPolicyRegistry_ZeroAddress();

  /// @notice Initializes the policy registry
  /// @param _owner The protocol owner for policy admin functions
  constructor(address _owner) Ownable(_owner) {}

  /// @notice Returns whether a target allows any call
  /// @param target The target contract address
  /// @return allowed True when contract-wide sponsorship is enabled
  function isContractAllowed(address target) external view returns (bool allowed) {
    return _contractAllowed[target];
  }

  /// @notice Returns whether a selector is allowed on a target
  /// @param target The target contract address
  /// @param selector The function selector
  /// @return allowed True when the selector is allowed
  function isSelectorAllowed(address target, bytes4 selector) external view returns (bool allowed) {
    return _selectorAllowed[target][selector];
  }

  /// @inheritdoc ISponsorPolicy
  function isSponsorable(
    address target,
    bytes calldata callData,
    address,
    uint256
  ) external view returns (bool sponsorable) {
    if (_contractAllowed[target]) return true;
    if (callData.length < 4) return false;
    bytes4 _selector = bytes4(callData[:4]);
    return _selectorAllowed[target][_selector];
  }

  /// @notice Registers contract-wide sponsorship for a target
  /// @param target The target contract address
  function registerTarget(address target) external onlyOwner {
    if (target == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    _contractAllowed[target] = true;
    _bumpVersion();
    emit TargetRegistered(target);
  }

  /// @notice Removes contract-wide sponsorship for a target
  /// @param target The target contract address
  function deregisterTarget(address target) external onlyOwner {
    _contractAllowed[target] = false;
    _bumpVersion();
    emit TargetDeregistered(target);
  }

  /// @notice Registers a selector for sponsorship on a target
  /// @param target The target contract address
  /// @param selector The function selector
  function registerSelector(address target, bytes4 selector) external onlyOwner {
    if (target == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    _selectorAllowed[target][selector] = true;
    _bumpVersion();
    emit SelectorRegistered(target, selector);
  }

  /// @notice Removes a selector registration for a target
  /// @param target The target contract address
  /// @param selector The function selector
  function deregisterSelector(address target, bytes4 selector) external onlyOwner {
    _selectorAllowed[target][selector] = false;
    _bumpVersion();
    emit SelectorDeregistered(target, selector);
  }

  /// @notice Bumps the policy version counter
  function _bumpVersion() internal {
    unchecked {
      policyVersion += 1;
    }
    emit PolicyVersionUpdated(policyVersion);
  }
}
