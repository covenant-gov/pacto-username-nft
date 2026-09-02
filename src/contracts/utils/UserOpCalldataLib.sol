// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Helpers for decoding PactoSimple7702Account execute calls
library UserOpCalldataLib {
  /// @notice `execute(address,uint256,bytes)` selector
  bytes4 internal constant EXECUTE_SELECTOR = 0xb61d27f6;

  /// @notice Decodes an execute call from account calldata
  /// @param callData The account call data
  /// @return target The call target address
  /// @return innerCallData The inner call data payload
  /// @return valid True when calldata matches execute(address,uint256,bytes)
  function decodeExecute(bytes calldata callData)
    internal
    pure
    returns (address target, bytes calldata innerCallData, bool valid)
  {
    if (callData.length < 4 + 96) return (address(0), callData, false);
    if (bytes4(callData[:4]) != EXECUTE_SELECTOR) return (address(0), callData, false);

    target = address(uint160(uint256(bytes32(callData[4:36]))));
    uint256 _dataOffset = uint256(bytes32(callData[68:100]));
    if (_dataOffset != 96) return (address(0), callData, false);

    uint256 _dataLength = uint256(bytes32(callData[100:132]));
    if (callData.length < 132 + _dataLength) return (address(0), callData, false);

    innerCallData = callData[132:132 + _dataLength];
    valid = true;
  }
}
