// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Vm} from 'forge-std/Vm.sol';

import {Constants} from 'script/Constants.sol';
import {PolicySeeding} from 'script/PolicySeeding.sol';

/// @notice Resolves factory target addresses from env overrides and chain config
library PolicyTargetResolver {
  Vm private constant _VM = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Returns factory targets with env overrides applied
  /// @param config The chain deployment configuration
  /// @return targets The resolved factory addresses
  function resolveFactoryTargets(Constants.ChainConfig memory config)
    internal
    view
    returns (PolicySeeding.FactoryTargets memory targets)
  {
    targets.navePirataFactory = _VM.envOr('NAVE_PIRATA_FACTORY', config.navePirataFactory);
    targets.squadSponsorFactory = _VM.envOr('SQUAD_SPONSOR_FACTORY', config.squadSponsorFactory);
    targets.safeProxyFactory = _VM.envOr('SAFE_PROXY_FACTORY', config.safeProxyFactory);
    targets.warGameFactory = _VM.envOr('WAR_GAME_FACTORY', config.warGameFactory);
  }
}
