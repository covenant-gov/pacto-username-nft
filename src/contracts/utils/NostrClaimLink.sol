// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Bip340} from 'contracts/utils/Bip340.sol';
import {NostrEventHash} from 'contracts/utils/NostrEventHash.sol';

/// @title NostrClaimLink
/// @notice Verifies Pacto username claim Nostr link events and parses bindings
library NostrClaimLink {
  /// @notice App-specific Nostr kind for username claim commits
  uint32 public constant PACTO_USERNAME_CLAIM_KIND = 31_337;

  /// @notice Parsed claim binding extracted from a verified Nostr link event
  struct ClaimBinding {
    bytes32 npubHash;
    bytes32 pubkey;
    address evmAddress;
    string name;
    uint256 nonce;
    uint256 issuedAt;
    bytes32 salt;
    uint256 createdAt;
  }

  /// @notice Thrown when a Nostr signature length is invalid
  error NostrClaimLink_InvalidSignatureLength();

  /// @notice Thrown when a Nostr signature fails verification
  error NostrClaimLink_InvalidSignature();

  /// @notice Thrown when calldata cannot be decoded as a claim link event
  error NostrClaimLink_InvalidEventEncoding();

  /// @notice Computes the npub hash used by Pacto contracts
  /// @dev Matches bech32 npub decoded bytes: 0x02 || 32-byte x-only pubkey
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @return npubHash The sha256 npub hash
  function npubHashFromPubkey(bytes32 pubkey) public pure returns (bytes32 npubHash) {
    npubHash = sha256(abi.encodePacked(hex'02', pubkey));
  }

  /// @notice Verifies a Pacto claim link event and returns the parsed binding
  /// @param nostrEvent ABI-encoded `(pubkey, createdAt, evmAddress, name, nonce, issuedAt, salt, signature)`
  /// @return binding The verified claim binding
  function verify(bytes calldata nostrEvent) public view returns (ClaimBinding memory binding) {
    (
      bytes32 _pubkey,
      uint256 _createdAt,
      address _evmAddress,
      string memory _name,
      uint256 _nonce,
      uint256 _issuedAt,
      bytes32 _salt,
      bytes memory _signature
    ) = abi.decode(nostrEvent, (bytes32, uint256, address, string, uint256, uint256, bytes32, bytes));

    _verifyBinding(_pubkey, _createdAt, _evmAddress, _name, _nonce, _issuedAt, _salt, _signature);

    binding = ClaimBinding({
      npubHash: npubHashFromPubkey(_pubkey),
      pubkey: _pubkey,
      evmAddress: _evmAddress,
      name: _name,
      nonce: _nonce,
      issuedAt: _issuedAt,
      salt: _salt,
      createdAt: _createdAt
    });
  }

  /// @notice Verifies a Pacto claim link event from explicit fields
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param createdAt The Nostr event created_at timestamp
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @param signature The 64-byte BIP-340 Schnorr signature
  function verifyBinding(
    bytes32 pubkey,
    uint256 createdAt,
    address evmAddress,
    string calldata name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes calldata signature
  ) public view {
    _verifyBinding(pubkey, createdAt, evmAddress, name, nonce, issuedAt, salt, signature);
  }

  /// @notice Encodes claim link event bytes for `verify(bytes)`
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param createdAt The Nostr event created_at timestamp
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @param signature The 64-byte BIP-340 Schnorr signature
  /// @return encoded The ABI-encoded nostr event bytes
  function encodeEvent(
    bytes32 pubkey,
    uint256 createdAt,
    address evmAddress,
    string memory name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes memory signature
  ) public pure returns (bytes memory encoded) {
    encoded = abi.encode(pubkey, createdAt, evmAddress, name, nonce, issuedAt, salt, signature);
  }

  /// @notice Verifies a claim link binding and Schnorr signature
  function _verifyBinding(
    bytes32 pubkey,
    uint256 createdAt,
    address evmAddress,
    string memory name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes memory signature
  ) private view {
    if (signature.length != 64) revert NostrClaimLink_InvalidSignatureLength();

    bytes32 _eventId =
      NostrEventHash.claimLinkEventId(pubkey, createdAt, evmAddress, name, nonce, issuedAt, salt);

    bytes32 _rx;
    bytes32 _s;
    assembly ('memory-safe') {
      _rx := mload(add(signature, 32))
      _s := mload(add(signature, 64))
    }

    if (!Bip340.verify(pubkey, _rx, _s, _eventId)) revert NostrClaimLink_InvalidSignature();
  }
}
