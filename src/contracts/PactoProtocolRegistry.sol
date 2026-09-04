// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/// @title PactoProtocolRegistry
/// @notice Owner-gated protocol address book with a one-time installer initialize
contract PactoProtocolRegistry is IPactoProtocolRegistry, Ownable2Step {
  /// @inheritdoc IPactoProtocolRegistry
  address public immutable INSTALLER;

  /// @inheritdoc IPactoProtocolRegistry
  bool public initialized;

  /// @inheritdoc IPactoProtocolRegistry
  address public usernameNft;

  /// @inheritdoc IPactoProtocolRegistry
  address public paymaster;

  /// @inheritdoc IPactoProtocolRegistry
  address public pool;

  /// @inheritdoc IPactoProtocolRegistry
  address public bootstrapPool;

  /// @inheritdoc IPactoProtocolRegistry
  address public policy;

  /// @inheritdoc IPactoProtocolRegistry
  address public bootstrapPolicy;

  /// @inheritdoc IPactoProtocolRegistry
  address public entryPoint;

  /// @inheritdoc IPactoProtocolRegistry
  address public allowed7702Implementation;

  /// @notice Sets the protocol owner and one-time installer
  /// @param owner The protocol owner for later address updates
  /// @param installer_ The factory allowed to call initialize once
  constructor(address owner, address installer_) Ownable(owner) {
    if (installer_ == address(0)) revert ProtocolRegistry_ZeroAddress();
    INSTALLER = installer_;
  }

  /// @inheritdoc IPactoProtocolRegistry
  function initialize(ProtocolAddresses calldata addresses) external {
    if (msg.sender != INSTALLER) revert ProtocolRegistry_NotInstaller();
    if (initialized) revert ProtocolRegistry_AlreadyInitialized();
    _requireCoreAddresses(addresses);

    initialized = true;
    usernameNft = addresses.usernameNft;
    paymaster = addresses.paymaster;
    pool = addresses.pool;
    bootstrapPool = addresses.bootstrapPool;
    policy = addresses.policy;
    bootstrapPolicy = addresses.bootstrapPolicy;
    entryPoint = addresses.entryPoint;
    allowed7702Implementation = addresses.allowed7702Implementation;

    emit ProtocolInitialized(addresses);
  }

  /// @inheritdoc IPactoProtocolRegistry
  function set(ProtocolComponent component, address addr) external onlyOwner {
    if (component != ProtocolComponent.Allowed7702Implementation && addr == address(0)) {
      revert ProtocolRegistry_ZeroAddress();
    }

    if (component == ProtocolComponent.UsernameNft) usernameNft = addr;
    else if (component == ProtocolComponent.Paymaster) paymaster = addr;
    else if (component == ProtocolComponent.Pool) pool = addr;
    else if (component == ProtocolComponent.BootstrapPool) bootstrapPool = addr;
    else if (component == ProtocolComponent.Policy) policy = addr;
    else if (component == ProtocolComponent.BootstrapPolicy) bootstrapPolicy = addr;
    else if (component == ProtocolComponent.EntryPoint) entryPoint = addr;
    else if (component == ProtocolComponent.Allowed7702Implementation) allowed7702Implementation = addr;
    else revert ProtocolRegistry_InvalidComponent();

    emit ProtocolAddressUpdated(component, addr);
  }

  /// @notice Reverts when a required protocol address is zero
  /// @param addresses The candidate protocol addresses
  function _requireCoreAddresses(ProtocolAddresses calldata addresses) internal pure {
    if (
      addresses.usernameNft == address(0) || addresses.paymaster == address(0) || addresses.pool == address(0)
        || addresses.bootstrapPool == address(0) || addresses.policy == address(0)
        || addresses.bootstrapPolicy == address(0) || addresses.entryPoint == address(0)
    ) revert ProtocolRegistry_ZeroAddress();
  }
}
