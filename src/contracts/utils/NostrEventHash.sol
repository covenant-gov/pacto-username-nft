// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title NostrEventHash
/// @notice NIP-01 event id hashing for Pacto username claim link events
library NostrEventHash {
  /// @notice App-specific Nostr kind for username claim commits
  uint32 internal constant PACTO_USERNAME_CLAIM_KIND = 31_337;

  /// @notice Tag marker for Pacto username claim link events
  string internal constant CLAIM_TAG_D = 'pacto-username-claim-v1';

  /// @notice Computes the NIP-01 event id for a Pacto username claim link event
  /// @dev Tags are emitted in a fixed order; content is always empty
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param createdAt The Nostr event created_at timestamp
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @return eventId The sha256 event id signed by Nostr
  function claimLinkEventId(
    bytes32 pubkey,
    uint256 createdAt,
    address evmAddress,
    string memory name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt
  ) public pure returns (bytes32 eventId) {
    bytes memory _serialized = abi.encodePacked(
      '[0,"',
      _pubkeyHex(pubkey),
      '",',
      _decimalString(createdAt),
      ',',
      _decimalString(PACTO_USERNAME_CLAIM_KIND),
      ',',
      _claimTagsJson(evmAddress, name, nonce, issuedAt, salt),
      ',""]'
    );

    eventId = sha256(_serialized);
  }

  /// @notice Builds the fixed claim-link tags JSON array
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @return tagsJson The tags JSON fragment
  function _claimTagsJson(
    address evmAddress,
    string memory name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt
  ) private pure returns (string memory tagsJson) {
    tagsJson = string(
      abi.encodePacked(
        '[["d","',
        CLAIM_TAG_D,
        '"],["evm","',
        _addressHex(evmAddress),
        '"],["name","',
        name,
        '"],["nonce","',
        _decimalString(nonce),
        '"],["issued_at","',
        _decimalString(issuedAt),
        '"],["salt","',
        _bytes32Hex(salt),
        '"]]'
      )
    );
  }

  /// @notice Encodes a pubkey as lowercase hex without 0x prefix
  /// @param pubkey The 32-byte public key
  /// @return hexString The 64-character hex string
  function _pubkeyHex(bytes32 pubkey) private pure returns (string memory hexString) {
    hexString = _toHexNoPrefix(pubkey);
  }

  /// @notice Encodes an address as lowercase 0x-prefixed hex
  /// @param addr The address value
  /// @return hexString The address hex string
  function _addressHex(address addr) private pure returns (string memory hexString) {
    bytes memory _buffer = new bytes(42);
    _buffer[0] = '0';
    _buffer[1] = 'x';

    bytes20 _addrBytes = bytes20(addr);
    for (uint256 _i = 0; _i < 20; ++_i) {
      uint8 _byte = uint8(_addrBytes[_i]);
      _buffer[2 + (_i * 2)] = _nibbleHex(_byte >> 4);
      _buffer[2 + (_i * 2) + 1] = _nibbleHex(_byte & 0x0f);
    }

    hexString = string(_buffer);
  }

  /// @notice Encodes a bytes32 value as lowercase 0x-prefixed hex
  /// @param value The bytes32 value
  /// @return hexString The hex string
  function _bytes32Hex(bytes32 value) private pure returns (string memory hexString) {
    hexString = string(abi.encodePacked('0x', _toHexNoPrefix(value)));
  }

  /// @notice Encodes bytes32 as lowercase hex without 0x prefix
  /// @param value The bytes32 value
  /// @return hexString The hex string
  function _toHexNoPrefix(bytes32 value) private pure returns (string memory hexString) {
    hexString = new string(64);
    bytes memory _buffer = bytes(hexString);

    for (uint256 _i = 0; _i < 32; ++_i) {
      uint8 _byte = uint8(value[_i]);
      _buffer[_i * 2] = _nibbleHex(_byte >> 4);
      _buffer[_i * 2 + 1] = _nibbleHex(_byte & 0x0f);
    }
  }

  /// @notice Encodes a uint256 as a decimal string
  /// @param value The integer value
  /// @return decimalString The decimal string
  function _decimalString(uint256 value) private pure returns (string memory decimalString) {
    if (value == 0) return '0';

    uint256 _length;
    uint256 _temp = value;
    while (_temp != 0) {
      unchecked {
        _length++;
        _temp /= 10;
      }
    }

    bytes memory _buffer = new bytes(_length);
    _temp = value;
    while (_temp != 0) {
      unchecked {
        _length--;
        _buffer[_length] = bytes1(uint8(48 + (_temp % 10)));
        _temp /= 10;
      }
    }

    decimalString = string(_buffer);
  }

  /// @notice Encodes a nibble as a lowercase hex character
  /// @param nibble The 4-bit nibble
  /// @return hexChar The hex character
  function _nibbleHex(uint8 nibble) private pure returns (bytes1 hexChar) {
    nibble &= 0x0f;
    hexChar = nibble < 10 ? bytes1(uint8(nibble + 48)) : bytes1(uint8(nibble + 87));
  }
}
