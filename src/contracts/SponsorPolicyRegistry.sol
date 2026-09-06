// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';
import {ISponsorPolicyRegistry} from 'interfaces/ISponsorPolicyRegistry.sol';

/// @title SponsorPolicyRegistry
/// @notice Deny-by-default allowlist with target, selector, and topHat sponsorship tiers
contract SponsorPolicyRegistry is ISponsorPolicyRegistry, Ownable2Step {
  /// @inheritdoc ISponsorPolicyRegistry
  uint256 public policyVersion;

  /// @notice Whether any call to a target is sponsorable
  mapping(address target => bool allowed) internal _contractAllowed;

  /// @notice Whether a specific selector on a target is sponsorable
  mapping(address target => mapping(bytes4 selector => bool allowed)) internal _selectorAllowed;

  /// @notice Whether a topHat squad tree is sponsorable
  mapping(uint256 topHatId => bool sponsored) internal _topHatSponsored;

  /// @inheritdoc ISponsorPolicyRegistry
  mapping(address module => uint256 topHatId) public moduleToTopHat;

  /// @inheritdoc ISponsorPolicyRegistry
  mapping(address registrar => bool authorized) public authorizedRegistrars;

  /// @notice Initializes the policy registry
  /// @param _owner The protocol owner for policy admin functions
  constructor(address _owner) Ownable(_owner) {}

  /// @inheritdoc ISponsorPolicyRegistry
  function isContractAllowed(address target) external view returns (bool allowed) {
    return _contractAllowed[target];
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function isSelectorAllowed(address target, bytes4 selector) external view returns (bool allowed) {
    return _selectorAllowed[target][selector];
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function isTopHatSponsored(uint256 topHatId) external view returns (bool sponsored) {
    return _topHatSponsored[topHatId];
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function topHatOfModule(address module) external view returns (uint256 topHatId) {
    return moduleToTopHat[module];
  }

  /// @inheritdoc ISponsorPolicy
  function isSponsorable(
    address target,
    bytes calldata callData,
    address,
    uint256
  ) external view returns (bool sponsorable) {
    if (_contractAllowed[target]) return true;

    if (callData.length >= 4) {
      bytes4 _selector = bytes4(callData[:4]);
      if (_selectorAllowed[target][_selector]) return true;
    }

    uint256 _topHatId = moduleToTopHat[target];
    if (_topHatId != 0 && _topHatSponsored[_topHatId]) return true;

    return false;
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function registerTarget(address target) external onlyOwner {
    if (target == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    _contractAllowed[target] = true;
    _bumpVersion();
    emit TargetRegistered(target);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function deregisterTarget(address target) external onlyOwner {
    _contractAllowed[target] = false;
    _bumpVersion();
    emit TargetDeregistered(target);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function registerSelector(address target, bytes4 selector) external onlyOwner {
    if (target == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    _selectorAllowed[target][selector] = true;
    _bumpVersion();
    emit SelectorRegistered(target, selector);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function deregisterSelector(address target, bytes4 selector) external onlyOwner {
    _selectorAllowed[target][selector] = false;
    _bumpVersion();
    emit SelectorDeregistered(target, selector);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
    if (registrar == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    authorizedRegistrars[registrar] = authorized;
    emit AuthorizedRegistrarUpdated(registrar, authorized);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function registerTopHat(uint256 topHatId) external {
    _requireAuthorizedRegistrar();
    _topHatSponsored[topHatId] = true;
    _bumpVersion();
    emit TopHatRegistered(topHatId);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function deregisterTopHat(uint256 topHatId) external {
    _requireAuthorizedRegistrar();
    _topHatSponsored[topHatId] = false;
    _bumpVersion();
    emit TopHatDeregistered(topHatId);
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function registerModulesForTopHat(uint256 topHatId, address[] calldata modules) external {
    _requireAuthorizedRegistrar();

    uint256 _length = modules.length;
    for (uint256 _i; _i < _length; ++_i) {
      address _module = modules[_i];
      if (_module == address(0)) revert SponsorPolicyRegistry_ZeroAddress();

      uint256 _existing = moduleToTopHat[_module];
      if (_existing != 0 && _existing != topHatId) {
        revert SponsorPolicyRegistry_ModuleAlreadyIndexed(_module, _existing);
      }

      moduleToTopHat[_module] = topHatId;
      emit ModuleIndexed(topHatId, _module);
    }

    _bumpVersion();
  }

  /// @inheritdoc ISponsorPolicyRegistry
  function deregisterModules(address[] calldata modules) external {
    _requireAuthorizedRegistrar();

    uint256 _length = modules.length;
    for (uint256 _i; _i < _length; ++_i) {
      address _module = modules[_i];
      delete moduleToTopHat[_module];
      emit ModuleDeregistered(_module);
    }

    _bumpVersion();
  }

  /// @notice Reverts when the caller is not an authorized registrar
  function _requireAuthorizedRegistrar() internal view {
    if (!authorizedRegistrars[msg.sender]) {
      revert SponsorPolicyRegistry_UnauthorizedRegistrar(msg.sender);
    }
  }

  /// @notice Bumps the policy version counter
  function _bumpVersion() internal {
    unchecked {
      policyVersion += 1;
    }
    emit PolicyVersionUpdated(policyVersion);
  }
}
