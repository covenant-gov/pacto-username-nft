// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Public chain constants for username system deployment.
library Constants {
  /// @notice Chain-level deployment configuration
  struct ChainConfig {
    uint256 chainId;
    address entryPoint;
    address allowed7702Implementation;
  }

  /// @notice ERC-4337 EntryPoint v0.7 on supported chains
  address internal constant ENTRY_POINT_V07 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

  /// @notice PactoSimple7702Account on Sepolia (pacto-squad-sponsor deployments)
  address internal constant SEPOLIA_7702_ACCOUNT = 0x33F920B5aF6c527f63BD6B24d58Dccd698b2DC60;

  /// @notice Returns chain configuration for `chainId`
  /// @param chainId The target chain id
  /// @return config The deployment configuration
  function getConfig(uint256 chainId) internal pure returns (ChainConfig memory config) {
    if (chainId == 1) return _mainnet();
    if (chainId == 11_155_111) return _sepolia();
    if (chainId == 42_161) return _arbitrum();
    revert UnsupportedChain(chainId);
  }

  function _mainnet() private pure returns (ChainConfig memory) {
    return ChainConfig({chainId: 1, entryPoint: ENTRY_POINT_V07, allowed7702Implementation: address(0)});
  }

  function _sepolia() private pure returns (ChainConfig memory) {
    return
      ChainConfig({chainId: 11_155_111, entryPoint: ENTRY_POINT_V07, allowed7702Implementation: SEPOLIA_7702_ACCOUNT});
  }

  function _arbitrum() private pure returns (ChainConfig memory) {
    return ChainConfig({chainId: 42_161, entryPoint: ENTRY_POINT_V07, allowed7702Implementation: address(0)});
  }

  /// @notice Thrown when a chain is unsupported
  error UnsupportedChain(uint256 chainId);
}
