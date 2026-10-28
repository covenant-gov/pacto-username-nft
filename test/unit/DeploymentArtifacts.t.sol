// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {Test} from 'forge-std/Test.sol';

contract DeploymentArtifactsHarness is DeploymentArtifacts {
  function parseNostrClaimLink(string memory raw) external view returns (address) {
    return _parseNostrClaimLinkFromBroadcastJson(raw);
  }

  function writeFullSystemWithZeroLink() external {
    FullSystemArtifact memory artifact;
    _writeFullSystemJson(artifact);
  }
}

contract UnitDeploymentArtifacts is Test {
  address internal constant _LINK = 0x6b280EFc5e7dDC6A0072dc1Ce3970F71169d87a4;

  DeploymentArtifactsHarness internal _harness;

  function setUp() external {
    _harness = new DeploymentArtifactsHarness();
  }

  function test_ParseNostrClaimLink_FromLibraries() external view {
    string memory raw = string.concat(
      '{"libraries":["src/contracts/utils/NostrClaimLink.sol:NostrClaimLink:',
      vm.toString(_LINK),
      '"],"transactions":[]}'
    );
    assertEq(_harness.parseNostrClaimLink(raw), _LINK);
  }

  function test_ParseNostrClaimLink_FromTransactionsWhenLibrariesEmpty() external view {
    string memory raw = string.concat(
      '{"libraries":[],"transactions":[{"transactionType":"CREATE2","contractName":"NostrClaimLink","contractAddress":"',
      vm.toString(_LINK),
      '"}]}'
    );
    assertEq(_harness.parseNostrClaimLink(raw), _LINK);
  }

  function test_ParseNostrClaimLink_MissingLibrariesKeyUsesTransactions() external view {
    string memory raw = string.concat(
      '{"transactions":[{"transactionType":"CREATE2","contractName":"NostrClaimLink","contractAddress":"',
      vm.toString(_LINK),
      '"}]}'
    );
    assertEq(_harness.parseNostrClaimLink(raw), _LINK);
  }

  function test_ParseNostrClaimLink_ReturnsZeroWhenUnresolved() external view {
    assertEq(_harness.parseNostrClaimLink('{"libraries":[],"transactions":[]}'), address(0));
  }

  function test_WriteFullSystemJson_NoOpInTestContextWithZeroLink() external {
    // forge test is not a script write context, so zero-link write is a no-op (not a revert).
    _harness.writeFullSystemWithZeroLink();
  }
}
