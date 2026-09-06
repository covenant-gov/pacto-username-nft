// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISponsorPolicy} from 'interfaces/ISponsorPolicy.sol';

/// @notice Deny-by-default allowlist with target, selector, and topHat sponsorship tiers
interface ISponsorPolicyRegistry is ISponsorPolicy {
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

  /// @notice Thrown when a target address is zero
  error SponsorPolicyRegistry_ZeroAddress();

  /// @notice Thrown when a caller is not an authorized registrar
  error SponsorPolicyRegistry_UnauthorizedRegistrar(address caller);

  /// @notice Thrown when a module is already indexed to a different topHat
  error SponsorPolicyRegistry_ModuleAlreadyIndexed(address module, uint256 existingTopHatId);

  /// @notice Returns the monotonic policy version for client sync
  function policyVersion() external view returns (uint256 version);

  /// @notice Returns the topHat id indexed for a gov module
  /// @param module The gov module address
  /// @return topHatId The topHat id (0 when unindexed)
  function moduleToTopHat(address module) external view returns (uint256 topHatId);

  /// @notice Returns whether a protocol factory may register topHats and module indexes
  /// @param registrar The factory address
  /// @return authorized True when the registrar is authorized
  function authorizedRegistrars(address registrar) external view returns (bool authorized);

  /// @notice Returns whether a target allows any call
  /// @param target The target contract address
  /// @return allowed True when contract-wide sponsorship is enabled
  function isContractAllowed(address target) external view returns (bool allowed);

  /// @notice Returns whether a selector is allowed on a target
  /// @param target The target contract address
  /// @param selector The function selector
  /// @return allowed True when the selector is allowed
  function isSelectorAllowed(address target, bytes4 selector) external view returns (bool allowed);

  /// @notice Returns whether a topHat squad tree is sponsorable
  /// @param topHatId The topHat identifier
  /// @return sponsored True when the topHat is registered
  function isTopHatSponsored(uint256 topHatId) external view returns (bool sponsored);

  /// @notice Returns the topHat id for an indexed gov module
  /// @param module The gov module address
  /// @return topHatId The topHat id (0 when unindexed)
  function topHatOfModule(address module) external view returns (uint256 topHatId);

  /// @notice Registers contract-wide sponsorship for a target
  /// @param target The target contract address
  function registerTarget(address target) external;

  /// @notice Removes contract-wide sponsorship for a target
  /// @param target The target contract address
  function deregisterTarget(address target) external;

  /// @notice Registers a selector for sponsorship on a target
  /// @param target The target contract address
  /// @param selector The function selector
  function registerSelector(address target, bytes4 selector) external;

  /// @notice Removes a selector registration for a target
  /// @param target The target contract address
  /// @param selector The function selector
  function deregisterSelector(address target, bytes4 selector) external;

  /// @notice Sets whether a protocol factory may register topHats and module indexes
  /// @param registrar The factory address
  /// @param authorized True to authorize the registrar
  function setAuthorizedRegistrar(address registrar, bool authorized) external;

  /// @notice Registers a topHat squad tree for global sponsorship
  /// @param topHatId The topHat identifier
  function registerTopHat(uint256 topHatId) external;

  /// @notice Removes topHat squad tree sponsorship
  /// @param topHatId The topHat identifier
  function deregisterTopHat(uint256 topHatId) external;

  /// @notice Indexes gov module addresses to a topHat squad tree
  /// @param topHatId The topHat identifier
  /// @param modules The gov module addresses to index
  function registerModulesForTopHat(uint256 topHatId, address[] calldata modules) external;

  /// @notice Removes gov module indexes
  /// @param modules The gov module addresses to deregister
  function deregisterModules(address[] calldata modules) external;
}
