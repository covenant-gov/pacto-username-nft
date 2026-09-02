// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Bip340} from 'contracts/utils/Bip340.sol';

/// @title NostrClaimLink
/// @notice Compact Nostr claim binding digests and BIP-340 verification for username mints
library NostrClaimLink {
  /// @notice Relay-layer Nostr kind for username claim link events (off-chain only)
  uint32 public constant PACTO_USERNAME_CLAIM_KIND = 31_337;

  /// @notice EIP-712-style type hash for on-chain Nostr claim bindings
  bytes32 public constant NOSTR_CLAIM_TYPEHASH = keccak256(
    'PactoNostrClaim(bytes32 pubkey,address evmAddress,bytes32 nameHash,uint256 nonce,uint256 issuedAt,bytes32 salt)'
  );

  /// @notice Thrown when a Nostr signature length is invalid
  error NostrClaimLink_InvalidSignatureLength();

  /// @notice Thrown when a Nostr signature fails verification
  error NostrClaimLink_InvalidSignature();

  /// @notice Computes the npub hash used by Pacto contracts
  /// @dev Matches bech32 npub decoded bytes: 0x02 || 32-byte x-only pubkey
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @return npubHash The sha256 npub hash
  function npubHashFromPubkey(bytes32 pubkey) public pure returns (bytes32 npubHash) {
    npubHash = sha256(abi.encodePacked(hex'02', pubkey));
  }

  /// @notice Computes the Nostr claim binding digest signed with BIP-340
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @return digest The struct hash to verify with BIP-340
  function hashNostrClaim(
    bytes32 pubkey,
    address evmAddress,
    string memory name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt
  ) public pure returns (bytes32 digest) {
    digest = keccak256(
      abi.encode(NOSTR_CLAIM_TYPEHASH, pubkey, evmAddress, keccak256(bytes(name)), nonce, issuedAt, salt)
    );
  }

  /// @notice Verifies a Nostr BIP-340 signature over a username claim binding
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param evmAddress The bound EVM address
  /// @param name The claimed username
  /// @param nonce The binding nonce
  /// @param issuedAt The binding issuedAt timestamp
  /// @param salt The binding salt
  /// @param signature The 64-byte BIP-340 Schnorr signature
  function verifyNostrClaimSignature(
    bytes32 pubkey,
    address evmAddress,
    string calldata name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes calldata signature
  ) public view {
    if (!isNostrClaimSignatureValid(pubkey, evmAddress, name, nonce, issuedAt, salt, signature)) {
      if (signature.length != 64) revert NostrClaimLink_InvalidSignatureLength();
      revert NostrClaimLink_InvalidSignature();
    }
  }

  /// @notice Returns whether a Nostr BIP-340 signature is valid for a username claim binding
  function isNostrClaimSignatureValid(
    bytes32 pubkey,
    address evmAddress,
    string calldata name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes calldata signature
  ) public view returns (bool valid) {
    if (signature.length != 64) return false;

    bytes32 _digest = hashNostrClaim(pubkey, evmAddress, name, nonce, issuedAt, salt);

    bytes32 _rx;
    bytes32 _s;
    assembly ('memory-safe') {
      _rx := calldataload(signature.offset)
      _s := calldataload(add(signature.offset, 32))
    }

    return Bip340.verify(pubkey, _rx, _s, _digest);
  }
}
