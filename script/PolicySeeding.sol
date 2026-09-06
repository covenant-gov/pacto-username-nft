// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

/// @notice Shared policy v4 seeding for deploy and migration scripts
library PolicySeeding {
  /// @notice Factory addresses for target-tier sponsorship and registrar authorization
  /// @param navePirataFactory The Nave Pirata factory (zero skips)
  /// @param squadSponsorFactory The squad sponsor factory (zero skips)
  /// @param safeProxyFactory The Safe proxy factory (zero skips)
  /// @param warGameFactory The war-game factory authorized as registrar (zero skips)
  struct FactoryTargets {
    address navePirataFactory;
    address squadSponsorFactory;
    address safeProxyFactory;
    address warGameFactory;
  }

  /// @notice Registers member-path factory targets and authorized registrars
  /// @param policy The sponsor policy registry
  /// @param usernameNft The username NFT address
  /// @param targets The factory target addresses
  function seedMemberPolicyV4(
    SponsorPolicyRegistry policy,
    address usernameNft,
    FactoryTargets memory targets
  ) internal {
    policy.registerTarget(usernameNft);

    if (targets.navePirataFactory != address(0)) {
      policy.registerTarget(targets.navePirataFactory);
      policy.setAuthorizedRegistrar(targets.navePirataFactory, true);
    }
    if (targets.squadSponsorFactory != address(0)) policy.registerTarget(targets.squadSponsorFactory);
    if (targets.safeProxyFactory != address(0)) policy.registerTarget(targets.safeProxyFactory);
    if (targets.warGameFactory != address(0)) policy.setAuthorizedRegistrar(targets.warGameFactory, true);
  }
}
