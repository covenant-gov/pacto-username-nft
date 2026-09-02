// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice On-chain username credential keyed by Nostr npub hash
interface IPactoUsernameNFT {
  /// @notice Username record for a single npub identity
  struct UsernameRecord {
    /// @notice Claimed lowercase username (immutable after claim)
    string name;
    /// @notice Active EVM controller eligible for sponsorship
    address evmAddress;
    /// @notice Pending recipient during two-step address transfer (zero if none)
    address pendingAddress;
    /// @notice Linked ERC-721 token id
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

  /// @notice Thrown when a name fails validation rules
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

  /// @notice Returns the minimum allowed username length
  function MIN_NAME_LENGTH() external view returns (uint256 minNameLength);

  /// @notice Returns the maximum allowed username length
  function MAX_NAME_LENGTH() external view returns (uint256 maxNameLength);

  /// @notice Returns the fee required to claim a username
  function mintFee() external view returns (uint256 fee);

  /// @notice Returns whether a name can be claimed
  /// @param _name The candidate username
  /// @return available True when the name is valid and unclaimed
  function nameAvailable(string calldata _name) external view returns (bool available);

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

  /// @notice Claims a username for an npub with dual EVM attestation
  /// @param _name The lowercase username to claim
  /// @param _npubHash The hashed npub identity
  /// @param _nonce Binding nonce for replay protection
  /// @param _issuedAt Binding issuance timestamp
  /// @param _signature EIP-712 signature from the claiming EVM address
  function claim(
    string calldata _name,
    bytes32 _npubHash,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes calldata _signature
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
