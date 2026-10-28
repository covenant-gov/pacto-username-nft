// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Vm} from 'forge-std/Vm.sol';

import {Constants} from 'script/Constants.sol';
import {PolicySeeding} from 'script/PolicySeeding.sol';

/// @notice Resolves factory target addresses from env overrides and chain config
library PolicyTargetResolver {
  Vm private constant _VM = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Returns factory targets with env overrides applied
  /// @dev Nave / Squad never fall back to chain config (zero skips registerTarget)
  /// @param config The chain deployment configuration
  /// @return targets The resolved factory addresses
  function resolveFactoryTargets(
    Constants.ChainConfig memory config
  ) internal view returns (PolicySeeding.FactoryTargets memory targets) {
    targets.navePirataFactory = _VM.envOr('NAVE_PIRATA_FACTORY', address(0));
    targets.squadSponsorFactory = _VM.envOr('SQUAD_SPONSOR_FACTORY', address(0));
    targets.safeProxyFactory = _VM.envOr('SAFE_PROXY_FACTORY', config.safeProxyFactory);
    targets.warGameFactory = _VM.envOr('WAR_GAME_FACTORY', config.warGameFactory);
  }

  /// @notice Returns factory targets, reverting if Nave or Squad env is missing or zero
  /// @param config The chain deployment configuration
  /// @return targets The resolved factory addresses
  function resolveRequiredFactoryTargets(
    Constants.ChainConfig memory config
  ) internal view returns (PolicySeeding.FactoryTargets memory targets) {
    targets = resolveFactoryTargets(config);
    if (targets.navePirataFactory == address(0)) revert MissingFactoryEnv('NAVE_PIRATA_FACTORY');
    if (targets.squadSponsorFactory == address(0)) revert MissingFactoryEnv('SQUAD_SPONSOR_FACTORY');
  }

  /// @notice Thrown when a required factory env var is unset or zero
  error MissingFactoryEnv(string name);
}
