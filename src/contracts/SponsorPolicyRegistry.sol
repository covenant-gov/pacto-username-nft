// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @title SponsorPolicyRegistry
/// @notice Deny-by-default allowlist with target, selector, and topHat sponsorship tiers
contract SponsorPolicyRegistry is ISponsorPolicy, Ownable2Step {
  /// @notice Emitted when a target is registered for contract-wide sponsorship
  event TargetRegistered(address indexed target);

  /// @notice Emitted when a target registration is removed
  event TargetDeregistered(address indexed target);

  /// @notice Emitted when a selector is registered for a target
  event SelectorRegistered(address indexed target, bytes4 indexed selector);

  /// @notice Emitted when a selector registration is removed
  event SelectorDeregistered(address indexed target, bytes4 indexed selector);

  /// @notice Emitted when a topHat is registered for squad-tree sponsorship
  event TopHatRegistered(uint256 indexed topHatId);

  /// @notice Emitted when a topHat registration is removed
  event TopHatDeregistered(uint256 indexed topHatId);

  /// @notice Emitted when a gov module is indexed to a topHat
  event ModuleIndexed(uint256 indexed topHatId, address indexed module);

  /// @notice Emitted when a gov module index is removed
  event ModuleDeregistered(address indexed module);

  /// @notice Emitted when an authorized registrar is updated
  event AuthorizedRegistrarUpdated(address indexed registrar, bool authorized);

  /// @notice Emitted when the policy version is bumped
  event PolicyVersionUpdated(uint256 policyVersion);

  /// @notice Monotonic policy version for client sync
  uint256 public policyVersion;

  /// @notice Whether any call to a target is sponsorable
  mapping(address target => bool allowed) internal _contractAllowed;

  /// @notice Whether a specific selector on a target is sponsorable
  mapping(address target => mapping(bytes4 selector => bool allowed)) internal _selectorAllowed;

  /// @notice Whether a topHat squad tree is sponsorable
  mapping(uint256 topHatId => bool sponsored) internal _topHatSponsored;

  /// @notice Gov module address to topHat squad tree id (0 = unindexed)
  mapping(address module => uint256 topHatId) public moduleToTopHat;

  /// @notice Protocol factories authorized to register topHats and module indexes
  mapping(address registrar => bool authorized) public authorizedRegistrars;

  /// @notice Thrown when a target address is zero
  error SponsorPolicyRegistry_ZeroAddress();

  /// @notice Thrown when a caller is not an authorized registrar
  error SponsorPolicyRegistry_UnauthorizedRegistrar(address caller);

  /// @notice Thrown when a module is already indexed to a different topHat
  error SponsorPolicyRegistry_ModuleAlreadyIndexed(address module, uint256 existingTopHatId);

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

  /// @notice Returns whether a topHat squad tree is sponsorable
  /// @param topHatId The topHat identifier
  /// @return sponsored True when the topHat is registered
  function isTopHatSponsored(uint256 topHatId) external view returns (bool sponsored) {
    return _topHatSponsored[topHatId];
  }

  /// @notice Returns the topHat id for an indexed gov module
  /// @param module The gov module address
  /// @return topHatId The topHat id (0 when unindexed)
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

  /// @notice Sets whether a protocol factory may register topHats and module indexes
  /// @param registrar The factory address
  /// @param authorized True to authorize the registrar
  function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
    if (registrar == address(0)) revert SponsorPolicyRegistry_ZeroAddress();
    authorizedRegistrars[registrar] = authorized;
    emit AuthorizedRegistrarUpdated(registrar, authorized);
  }

  /// @notice Registers a topHat squad tree for global sponsorship
  /// @param topHatId The topHat identifier
  function registerTopHat(uint256 topHatId) external {
    _requireAuthorizedRegistrar();
    _topHatSponsored[topHatId] = true;
    _bumpVersion();
    emit TopHatRegistered(topHatId);
  }

  /// @notice Removes topHat squad tree sponsorship
  /// @param topHatId The topHat identifier
  function deregisterTopHat(uint256 topHatId) external {
    _requireAuthorizedRegistrar();
    _topHatSponsored[topHatId] = false;
    _bumpVersion();
    emit TopHatDeregistered(topHatId);
  }

  /// @notice Indexes gov module addresses to a topHat squad tree
  /// @param topHatId The topHat identifier
  /// @param modules The gov module addresses to index
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

  /// @notice Removes gov module indexes
  /// @param modules The gov module addresses to deregister
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
