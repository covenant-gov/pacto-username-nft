// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title BIP340
/// @notice BIP-340 Schnorr signature verification for secp256k1 via ecrecover
/// @dev Adapted from https://github.com/idealgroup/bridge (MIT)
library Bip340 {
  /// @notice secp256k1 field prime
  uint256 internal constant P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

  /// @notice secp256k1 group order
  uint256 internal constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

  /// @notice Verifies a BIP-340 Schnorr signature
  /// @param px x-only public key
  /// @param rx signature R.x component
  /// @param s signature s component
  /// @param messageHash 32-byte signed message hash
  /// @return valid True when the signature is valid
  function verify(bytes32 px, bytes32 rx, bytes32 s, bytes32 messageHash) internal view returns (bool valid) {
    uint256 _px = uint256(px);
    uint256 _rx = uint256(rx);
    uint256 _s = uint256(s);

    if (_rx >= P || _s >= N || _px == 0 || _px >= P) return false;
    (bool _pxOk,) = _liftX(_px);
    if (!_pxOk) return false;

    uint256 _e = uint256(_taggedHash('BIP0340/challenge', abi.encodePacked(rx, px, messageHash))) % N;

    uint256 _msgHash = mulmod(N - _s, _px, N);
    uint256 _sigS = mulmod(N - _e, _px, N);

    address _recovered = ecrecover(bytes32(_msgHash), 27, bytes32(_px), bytes32(_sigS));
    if (_recovered == address(0)) return false;

    (bool _rxOk, uint256 _ry) = _liftX(_rx);
    if (!_rxOk) return false;

    return _recovered == _pubkeyToAddress(_rx, _ry);
  }

  /// @notice Lifts an x-coordinate to the even-y point on secp256k1
  /// @param x The x coordinate
  /// @return ok True when the point exists
  /// @return y The even y coordinate
  function _liftX(uint256 x) private view returns (bool ok, uint256 y) {
    if (x == 0 || x >= P) return (false, 0);

    uint256 _c = addmod(mulmod(mulmod(x, x, P), x, P), 7, P);
    y = _modExp(_c, (P + 1) / 4, P);
    if (mulmod(y, y, P) != _c) return (false, 0);
    if (y & 1 == 1) y = P - y;

    return (true, y);
  }

  /// @notice Computes the Ethereum address for a secp256k1 point
  /// @param x The x coordinate
  /// @param y The y coordinate
  /// @return addr The derived address
  function _pubkeyToAddress(uint256 x, uint256 y) private pure returns (address addr) {
    addr = address(uint160(uint256(keccak256(abi.encodePacked(x, y)))));
  }

  /// @notice Modular exponentiation via precompile 0x05
  /// @param base The base value
  /// @param exponent The exponent value
  /// @param mod_ The modulus value
  /// @return result The modular exponentiation result
  function _modExp(uint256 base, uint256 exponent, uint256 mod_) private view returns (uint256 result) {
    assembly ('memory-safe') {
      let _ptr := mload(0x40)
      mstore(_ptr, 0x20)
      mstore(add(_ptr, 0x20), 0x20)
      mstore(add(_ptr, 0x40), 0x20)
      mstore(add(_ptr, 0x60), base)
      mstore(add(_ptr, 0x80), exponent)
      mstore(add(_ptr, 0xa0), mod_)
      if iszero(staticcall(gas(), 0x05, _ptr, 0xc0, _ptr, 0x20)) { revert(0, 0) }
      result := mload(_ptr)
    }
  }

  /// @notice Tagged hash per BIP-340
  /// @param tag The hash tag
  /// @param data The payload bytes
  /// @return hash The tagged hash digest
  function _taggedHash(string memory tag, bytes memory data) private pure returns (bytes32 hash) {
    bytes32 _tagHash = sha256(bytes(tag));
    hash = sha256(abi.encodePacked(_tagHash, _tagHash, data));
  }
}
