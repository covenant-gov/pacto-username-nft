// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoUsernameNFT} from 'contracts/PactoUsernameNFT.sol';
import {Script} from 'forge-std/Script.sol';

contract Deploy is Script {
  function run() public {
    vm.startBroadcast();
    new PactoUsernameNFT(msg.sender);
    vm.stopBroadcast();
  }
}
