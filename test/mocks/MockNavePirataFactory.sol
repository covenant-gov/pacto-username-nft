// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SponsorPolicyRegistry} from 'contracts/SponsorPolicyRegistry.sol';

import {MockGovModule} from 'test/mocks/MockGovModule.sol';

/// @notice Simulates pacto-gov factory topHat registration during deployNavePirata
contract MockNavePirataFactory {
  SponsorPolicyRegistry public immutable POLICY;

  /// @notice Emitted when a squad tree is deployed and indexed
  event SquadDeployed(uint256 indexed topHatId, address quartermaster, address mutiny, address treasuryAuthority);

  /// @notice Initializes the mock factory
  /// @param policy The sponsor policy registry
  constructor(SponsorPolicyRegistry policy) {
    POLICY = policy;
  }

  /// @notice Deploys mock modules and registers the topHat squad tree
  /// @param topHatId The topHat identifier
  /// @return quartermaster The quartermaster module address
  /// @return mutiny The mutiny module address
  /// @return treasuryAuthority The treasury authority module address
  function deploySquad(uint256 topHatId)
    external
    returns (address quartermaster, address mutiny, address treasuryAuthority)
  {
    quartermaster = address(new MockGovModule());
    mutiny = address(new MockGovModule());
    treasuryAuthority = address(new MockGovModule());

    POLICY.registerTopHat(topHatId);

    address[] memory _modules = new address[](3);
    _modules[0] = quartermaster;
    _modules[1] = mutiny;
    _modules[2] = treasuryAuthority;
    POLICY.registerModulesForTopHat(topHatId, _modules);

    emit SquadDeployed(topHatId, quartermaster, mutiny, treasuryAuthority);
  }
}
