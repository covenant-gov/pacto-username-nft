// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

import {Constants} from 'script/Constants.sol';
import {PolicySeeding} from 'script/PolicySeeding.sol';
import {PolicyTargetResolver} from 'script/PolicyTargetResolver.sol';

contract UnitPolicyTargetResolver is Test {
  address internal constant _RETIRED_NAVE = 0x97d2dbA09FCA62f3E634d850aB7d8fd7AdC7d9E4;
  address internal constant _RETIRED_SQUAD = 0x280755769367DDD108020eEF353A6dF0f8355f36;

  /// @dev Sequential: `vm.setEnv` is process-global and races under parallel tests
  function test_PolicyTargetResolver_FailClosed() external {
    Constants.ChainConfig memory _config = _staleConfig();

    _setNaveAndSquadEnv(address(0), address(0));
    PolicySeeding.FactoryTargets memory _zeroed = PolicyTargetResolver.resolveFactoryTargets(_config);
    assertEq(_zeroed.navePirataFactory, address(0));
    assertEq(_zeroed.squadSponsorFactory, address(0));
    assertTrue(_zeroed.navePirataFactory != _RETIRED_NAVE);
    assertTrue(_zeroed.squadSponsorFactory != _RETIRED_SQUAD);

    vm.expectRevert(abi.encodeWithSelector(PolicyTargetResolver.MissingFactoryEnv.selector, 'NAVE_PIRATA_FACTORY'));
    this.exposedResolveRequiredFactoryTargets(_config);

    _setNaveAndSquadEnv(Constants.SEPOLIA_NAVE_PIRATA_FACTORY, Constants.SEPOLIA_SQUAD_SPONSOR_FACTORY);
    PolicySeeding.FactoryTargets memory _overridden = PolicyTargetResolver.resolveFactoryTargets(_config);
    assertEq(_overridden.navePirataFactory, Constants.SEPOLIA_NAVE_PIRATA_FACTORY);
    assertEq(_overridden.squadSponsorFactory, Constants.SEPOLIA_SQUAD_SPONSOR_FACTORY);

    PolicySeeding.FactoryTargets memory _required = PolicyTargetResolver.resolveRequiredFactoryTargets(_config);
    assertEq(_required.navePirataFactory, Constants.SEPOLIA_NAVE_PIRATA_FACTORY);
    assertEq(_required.squadSponsorFactory, Constants.SEPOLIA_SQUAD_SPONSOR_FACTORY);

    address _safe = makeAddr('safeProxyFactory');
    _config.safeProxyFactory = _safe;
    PolicySeeding.FactoryTargets memory _withSafe = PolicyTargetResolver.resolveFactoryTargets(_config);
    assertEq(_withSafe.safeProxyFactory, _safe);
  }

  function exposedResolveRequiredFactoryTargets(
    Constants.ChainConfig memory config
  ) external view returns (PolicySeeding.FactoryTargets memory) {
    return PolicyTargetResolver.resolveRequiredFactoryTargets(config);
  }

  function _staleConfig() internal pure returns (Constants.ChainConfig memory config) {
    config.navePirataFactory = _RETIRED_NAVE;
    config.squadSponsorFactory = _RETIRED_SQUAD;
    config.safeProxyFactory = Constants.SEPOLIA_SAFE_PROXY_FACTORY;
  }

  function _setNaveAndSquadEnv(address nave, address squad) internal {
    vm.setEnv('NAVE_PIRATA_FACTORY', vm.toString(nave));
    vm.setEnv('SQUAD_SPONSOR_FACTORY', vm.toString(squad));
  }
}
