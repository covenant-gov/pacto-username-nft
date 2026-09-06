// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Simulates squad sponsor factory deploy with zero value
contract MockSquadSponsorFactory {
  address public lastDeployed;

  /// @notice Deploys a mock sponsor clone
  /// @return sponsor The deployed sponsor address
  function createSquadSponsor() external payable returns (address sponsor) {
    sponsor = address(new MockSquadSponsorClone());
    lastDeployed = sponsor;
  }
}

/// @notice Stand-in for a deployed squad sponsor clone
contract MockSquadSponsorClone {}
