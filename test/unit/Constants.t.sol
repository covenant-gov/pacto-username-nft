// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';
import {Constants} from 'script/Constants.sol';

contract UnitConstants is Test {
  function test_GetConfig_Sepolia() external pure {
    Constants.ChainConfig memory _config = Constants.getConfig(11_155_111);
    assertEq(_config.chainId, 11_155_111);
    assertEq(_config.entryPoint, Constants.ENTRY_POINT_V07);
    assertEq(_config.allowed7702Implementation, Constants.SEPOLIA_7702_ACCOUNT);
    assertEq(_config.navePirataFactory, Constants.SEPOLIA_NAVE_PIRATA_FACTORY);
    assertEq(_config.squadSponsorFactory, Constants.SEPOLIA_SQUAD_SPONSOR_FACTORY);
    assertEq(_config.safeProxyFactory, Constants.SEPOLIA_SAFE_PROXY_FACTORY);
  }

  function test_GetConfig_UnsupportedChain() external {
    vm.expectRevert(abi.encodeWithSelector(Constants.UnsupportedChain.selector, uint256(999)));
    this.exposedGetConfig(999);
  }

  function exposedGetConfig(uint256 chainId) external pure returns (Constants.ChainConfig memory) {
    return Constants.getConfig(chainId);
  }
}
