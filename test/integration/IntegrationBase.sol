// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {Test} from 'forge-std/Test.sol';

contract IntegrationBase is Test {
  address internal _owner = makeAddr('owner');
  PactoUsernameNFT internal _nft;

  function setUp() public virtual {
    vm.prank(_owner);
    _nft = new PactoUsernameNFT(_owner);
  }
}
