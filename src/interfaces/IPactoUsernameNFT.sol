// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice On-chain username credential keyed by Nostr npub hash
interface IPactoUsernameNFT {
  /// @notice Username record for a single npub identity
  /// @param name Claimed username (immutable after claim; any string, unique on this contract)
  /// @param evmAddress Active EVM controller eligible for sponsorship
  /// @param pendingAddress Pending recipient during two-step address transfer (zero if none)
  /// @param tokenId Linked ERC-721 token id
  struct UsernameRecord {
    string name;
    address evmAddress;
    address pendingAddress;
    uint256 tokenId;
  }

  /// @notice Emitted when a username is claimed for an npub
  event UsernameClaimed(bytes32 indexed npubHash, string name, address indexed evmAddress, uint256 indexed tokenId);

  /// @notice Emitted when the active EVM address initiates a transfer
  event AddressTransferInitiated(bytes32 indexed npubHash, address indexed from, address indexed pendingAddress);

  /// @notice Emitted when the pending address completes a transfer
  event AddressTransferClaimed(bytes32 indexed npubHash, address indexed from, address indexed to);

  /// @notice Emitted when a pending address transfer is cancelled
  event AddressTransferCancelled(bytes32 indexed npubHash, address indexed evmAddress);

  /// @notice Emitted when the mint fee is updated
  event MintFeeUpdated(uint256 mintFee);

  /// @notice Thrown when npubHash or pubkey is zero
  error PactoUsernameNFT_InvalidName();

  /// @notice Thrown when a name is reserved or already claimed
  error PactoUsernameNFT_NameUnavailable();

  /// @notice Thrown when an npub already has a record
  error PactoUsernameNFT_NpubAlreadyClaimed();

  /// @notice Thrown when an EVM address already controls a record
  error PactoUsernameNFT_AddressAlreadyClaimed();

  /// @notice Thrown when the mint fee is not paid
  error PactoUsernameNFT_InsufficientMintFee();

  /// @notice Thrown when an EIP-712 claim signature is invalid
  error PactoUsernameNFT_InvalidClaimSignature();

  /// @notice Thrown when npubHash does not match the supplied pubkey
  error PactoUsernameNFT_InvalidNpubHash();

  /// @notice Thrown when a Nostr claim signature is invalid
  error PactoUsernameNFT_InvalidNostrSignature();

  /// @notice Thrown when a claim binding is outside the allowed issuedAt window
  error PactoUsernameNFT_BindingExpired();

  /// @notice Thrown when a claim binding nonce was already consumed
  error PactoUsernameNFT_NonceAlreadyUsed();

  /// @notice Thrown when a caller is not the active EVM controller
  error PactoUsernameNFT_NotActiveController();

  /// @notice Thrown when no pending transfer exists
  error PactoUsernameNFT_NoPendingTransfer();

  /// @notice Thrown when a pending transfer already exists
  error PactoUsernameNFT_PendingTransferExists();

  /// @notice Thrown when a caller is not the pending recipient
  error PactoUsernameNFT_NotPendingRecipient();

  /// @notice Thrown when standard ERC-721 transfers are attempted
  error PactoUsernameNFT_TransferDisabled();

  /// @notice Thrown when a record does not exist for the npub
  error PactoUsernameNFT_RecordNotFound();

  /// @notice Thrown when a target address is zero
  error PactoUsernameNFT_ZeroAddress();

  /// @notice Thrown when a transfer target equals the active controller
  error PactoUsernameNFT_InvalidTransferTarget();

  /// @notice Returns the fee required to claim a username
  function mintFee() external view returns (uint256 fee);

  /// @notice Returns whether a name can be claimed
  /// @param _name The candidate username
  /// @return available True when the name is unclaimed and not reserved
  function nameAvailable(string calldata _name) external view returns (bool available);

  /// @notice Returns whether a name hash is reserved
  /// @param nameHash The keccak256 hash of the username bytes
  /// @return reserved True when the name is reserved
  function isReservedName(bytes32 nameHash) external view returns (bool reserved);

  /// @notice Returns the npub hash for an active EVM controller
  /// @param _evmAddress The EVM address to lookup
  /// @return npubHash The npub hash or zero when unmapped
  function npubOf(address _evmAddress) external view returns (bytes32 npubHash);

  /// @notice Returns eligibility data for sponsorship when member is the active controller
  /// @param member The candidate member address
  /// @return npubHash The npub hash or zero when not eligible
  /// @return tokenId The linked token id or zero when not eligible
  function eligibleMember(address member) external view returns (bytes32 npubHash, uint256 tokenId);

  /// @notice Returns whether an npub has a pending address transfer
  /// @param _npubHash The npub hash to lookup
  /// @return pending True when a transfer is in flight
  function isPendingTransfer(bytes32 _npubHash) external view returns (bool pending);

  /// @notice Returns the username record for an npub
  /// @param _npubHash The npub hash to lookup
  /// @return record The stored username record
  function recordOf(bytes32 _npubHash) external view returns (UsernameRecord memory record);

  /// @notice Returns the maximum binding age in seconds
  function MAX_BINDING_AGE() external view returns (uint256 maxBindingAge);

  /// @notice Returns the allowed future clock skew in seconds
  function CLOCK_SKEW() external view returns (uint256 clockSkew);

  /// @notice Returns the consumed nonce for an npub hash
  /// @param npubHash The npub hash to lookup
  /// @return nonce The consumed nonce or zero when none was used
  function usedNonce(bytes32 npubHash) external view returns (uint256 nonce);

  /// @notice Returns whether an address can bootstrap-claim for an npub hash
  /// @param member The candidate member address
  /// @param npubHash The npub hash to claim
  /// @return canClaim True when bootstrap claim prechecks pass
  function canBootstrapClaim(address member, bytes32 npubHash) external view returns (bool canClaim);

  /// @notice Computes the EIP-712 digest for a claim binding
  /// @param npubHash The hashed npub identity
  /// @param evmAddress The claiming EVM address
  /// @param name The username being claimed
  /// @param nonce Binding nonce for replay protection
  /// @param issuedAt Binding issuance timestamp
  /// @param salt Binding salt for commit-reveal
  /// @return digest The typed data digest to sign
  function hashClaimBinding(
    bytes32 npubHash,
    address evmAddress,
    string calldata name,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt
  ) external view returns (bytes32 digest);

  /// @notice Claims a username for an npub with dual Nostr and EVM attestation
  /// @param name The username to claim
  /// @param npubHash The hashed npub identity
  /// @param pubkey The 32-byte x-only Nostr public key
  /// @param nonce Binding nonce for replay protection
  /// @param issuedAt Binding issuance timestamp
  /// @param salt Binding salt for commit-reveal
  /// @param nostrSignature BIP-340 Schnorr signature over the Nostr claim digest
  /// @param evmSignature EIP-712 signature from the claiming EVM address
  function claim(
    string calldata name,
    bytes32 npubHash,
    bytes32 pubkey,
    uint256 nonce,
    uint256 issuedAt,
    bytes32 salt,
    bytes calldata nostrSignature,
    bytes calldata evmSignature
  ) external payable;

  /// @notice Initiates a two-step transfer of the active EVM controller
  /// @param _npubHash The npub hash for the record
  /// @param _newAddress The pending recipient address
  function initiateAddressTransfer(bytes32 _npubHash, address _newAddress) external;

  /// @notice Completes a pending EVM controller transfer
  /// @param _npubHash The npub hash for the record
  function claimAddressTransfer(bytes32 _npubHash) external;

  /// @notice Cancels a pending EVM controller transfer
  /// @param _npubHash The npub hash for the record
  function cancelAddressTransfer(bytes32 _npubHash) external;

  /// @notice Updates the mint fee
  /// @param _mintFee The new mint fee in wei
  function setMintFee(uint256 _mintFee) external;
}
