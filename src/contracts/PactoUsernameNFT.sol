// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {NostrClaimLink} from 'contracts/utils/NostrClaimLink.sol';
import {IPactoUsernameNFT} from 'interfaces/IPactoUsernameNFT.sol';

/// @title PactoUsernameNFT
/// @notice ERC-721 username credentials keyed by npub with two-step EVM address rotation
contract PactoUsernameNFT is IPactoUsernameNFT, ERC721, EIP712, Ownable {
  using ECDSA for bytes32;

  /// @inheritdoc IPactoUsernameNFT
  uint256 public constant MIN_NAME_LENGTH = 3;

  /// @inheritdoc IPactoUsernameNFT
  uint256 public constant MAX_NAME_LENGTH = 32;

  /// @inheritdoc IPactoUsernameNFT
  uint256 public constant MAX_BINDING_AGE = 7 days;

  /// @inheritdoc IPactoUsernameNFT
  uint256 public constant CLOCK_SKEW = 5 minutes;

  /// @notice EIP-712 type hash for username claim bindings
  bytes32 public constant CLAIM_BINDING_TYPEHASH = keccak256(
    'ClaimBinding(bytes32 npubHash,address evmAddress,string name,uint256 nonce,uint256 issuedAt,bytes32 salt)'
  );

  /// @inheritdoc IPactoUsernameNFT
  uint256 public mintFee;

  /// @notice Consumed claim nonce per npub hash
  mapping(bytes32 npubHash => uint256 nonce) public usedNonce;

  /// @notice Primary npub hash to username record mapping
  mapping(bytes32 npubHash => UsernameRecord record) internal _records;

  /// @notice Name to npub hash mapping for uniqueness
  mapping(string name => bytes32 npubHash) internal _nameToNpub;

  /// @notice Active EVM controller to npub hash mapping
  mapping(address evmAddress => bytes32 npubHash) internal _addressToNpub;

  /// @notice Token id to npub hash mapping
  mapping(uint256 tokenId => bytes32 npubHash) internal _tokenToNpub;

  /// @notice Reserved name hashes blocked from claim
  mapping(bytes32 nameHash => bool reserved) internal _reservedNames;

  /// @notice Next sequential ERC-721 token id
  uint256 internal _nextTokenId = 1;

  /// @notice Allows internal ERC-721 transfers during address claim completion
  bool internal _internalTransfer;

  /// @notice Initializes the username NFT collection
  /// @param _owner The protocol owner for admin functions
  constructor(address _owner) ERC721('Pacto Username', 'PACTO-NAME') EIP712('PactoUsername', '2') Ownable(_owner) {}

  /// @inheritdoc IPactoUsernameNFT
  function nameAvailable(string calldata _name) external view returns (bool available) {
    return _isValidName(_name) && _nameToNpub[_name] == bytes32(0);
  }

  /// @inheritdoc IPactoUsernameNFT
  function npubOf(address _evmAddress) external view returns (bytes32 npubHash) {
    return _addressToNpub[_evmAddress];
  }

  /// @inheritdoc IPactoUsernameNFT
  function eligibleMember(address member) external view returns (bytes32 npubHash, uint256 tokenId) {
    npubHash = _addressToNpub[member];
    if (npubHash == bytes32(0)) return (bytes32(0), 0);

    UsernameRecord memory _record = _records[npubHash];
    if (_record.evmAddress != member) return (bytes32(0), 0);

    return (npubHash, _record.tokenId);
  }

  /// @inheritdoc IPactoUsernameNFT
  function isPendingTransfer(bytes32 _npubHash) external view returns (bool pending) {
    return _records[_npubHash].pendingAddress != address(0);
  }

  /// @inheritdoc IPactoUsernameNFT
  function recordOf(bytes32 _npubHash) external view returns (UsernameRecord memory record) {
    record = _records[_npubHash];
    if (record.tokenId == 0) revert PactoUsernameNFT_RecordNotFound();
  }

  /// @inheritdoc IPactoUsernameNFT
  function canBootstrapClaim(address member, bytes32 npubHash) external view returns (bool canClaim) {
    if (member == address(0) || npubHash == bytes32(0)) return false;
    if (_addressToNpub[member] != bytes32(0)) return false;
    if (_records[npubHash].tokenId != 0) return false;
    return true;
  }

  /// @notice Returns whether a name hash is reserved
  /// @param _nameHash The keccak256 hash of the username bytes
  /// @return reserved True when the name is reserved
  function isReservedName(bytes32 _nameHash) external view returns (bool reserved) {
    return _reservedNames[_nameHash];
  }

  /// @inheritdoc IPactoUsernameNFT
  function hashClaimBinding(
    bytes32 _npubHash,
    address _evmAddress,
    string calldata _name,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt
  ) external view returns (bytes32 digest) {
    digest = _hashClaimBinding(_npubHash, _evmAddress, _name, _nonce, _issuedAt, _salt);
  }

  /// @inheritdoc IPactoUsernameNFT
  function claim(
    string calldata _name,
    bytes32 _npubHash,
    bytes32 _pubkey,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt,
    bytes calldata _nostrSignature,
    bytes calldata _evmSignature
  ) external payable {
    if (msg.value < mintFee) revert PactoUsernameNFT_InsufficientMintFee();
    _validateClaimInputs(_name, _npubHash, _pubkey, _nonce, _issuedAt);

    if (!NostrClaimLink.isNostrClaimSignatureValid(
        _pubkey, msg.sender, _name, _nonce, _issuedAt, _salt, _nostrSignature
      )) revert PactoUsernameNFT_InvalidNostrSignature();

    _verifyEvmClaimSignature(_npubHash, _name, _nonce, _issuedAt, _salt, _evmSignature);

    usedNonce[_npubHash] = _nonce;

    uint256 _tokenId = _nextTokenId++;
    _records[_npubHash] =
      UsernameRecord({name: _name, evmAddress: msg.sender, pendingAddress: address(0), tokenId: _tokenId});

    _nameToNpub[_name] = _npubHash;
    _addressToNpub[msg.sender] = _npubHash;
    _tokenToNpub[_tokenId] = _npubHash;

    _safeMint(msg.sender, _tokenId);

    emit UsernameClaimed(_npubHash, _name, msg.sender, _tokenId);
  }

  /// @inheritdoc IPactoUsernameNFT
  function initiateAddressTransfer(bytes32 _npubHash, address _newAddress) external {
    UsernameRecord storage _record = _records[_npubHash];
    if (_record.tokenId == 0) revert PactoUsernameNFT_RecordNotFound();
    if (msg.sender != _record.evmAddress) revert PactoUsernameNFT_NotActiveController();
    if (_record.pendingAddress != address(0)) revert PactoUsernameNFT_PendingTransferExists();
    if (_newAddress == address(0)) revert PactoUsernameNFT_ZeroAddress();
    if (_newAddress == _record.evmAddress) revert PactoUsernameNFT_InvalidTransferTarget();
    if (_addressToNpub[_newAddress] != bytes32(0)) revert PactoUsernameNFT_AddressAlreadyClaimed();

    _record.pendingAddress = _newAddress;

    emit AddressTransferInitiated(_npubHash, _record.evmAddress, _newAddress);
  }

  /// @inheritdoc IPactoUsernameNFT
  function claimAddressTransfer(bytes32 _npubHash) external {
    UsernameRecord storage _record = _records[_npubHash];
    if (_record.tokenId == 0) revert PactoUsernameNFT_RecordNotFound();
    if (_record.pendingAddress == address(0)) revert PactoUsernameNFT_NoPendingTransfer();
    if (msg.sender != _record.pendingAddress) revert PactoUsernameNFT_NotPendingRecipient();

    address _previousAddress = _record.evmAddress;
    _record.evmAddress = msg.sender;
    _record.pendingAddress = address(0);

    delete _addressToNpub[_previousAddress];
    _addressToNpub[msg.sender] = _npubHash;

    _internalTransfer = true;
    _transfer(_previousAddress, msg.sender, _record.tokenId);
    _internalTransfer = false;

    emit AddressTransferClaimed(_npubHash, _previousAddress, msg.sender);
  }

  /// @inheritdoc IPactoUsernameNFT
  function cancelAddressTransfer(bytes32 _npubHash) external {
    UsernameRecord storage _record = _records[_npubHash];
    if (_record.tokenId == 0) revert PactoUsernameNFT_RecordNotFound();
    if (msg.sender != _record.evmAddress) revert PactoUsernameNFT_NotActiveController();
    if (_record.pendingAddress == address(0)) revert PactoUsernameNFT_NoPendingTransfer();

    _record.pendingAddress = address(0);

    emit AddressTransferCancelled(_npubHash, msg.sender);
  }

  /// @inheritdoc IPactoUsernameNFT
  function setMintFee(uint256 _mintFee) external onlyOwner {
    mintFee = _mintFee;
    emit MintFeeUpdated(_mintFee);
  }

  /// @notice Sets whether a name hash is reserved
  /// @param _nameHash The keccak256 hash of the username bytes
  /// @param _reserved True to reserve the name
  function setReservedName(bytes32 _nameHash, bool _reserved) external onlyOwner {
    _reservedNames[_nameHash] = _reserved;
  }

  /// @notice Validates claim availability, binding freshness, and npub binding
  function _validateClaimInputs(
    string calldata _name,
    bytes32 _npubHash,
    bytes32 _pubkey,
    uint256 _nonce,
    uint256 _issuedAt
  ) internal view {
    if (_npubHash == bytes32(0) || _pubkey == bytes32(0)) revert PactoUsernameNFT_InvalidName();
    if (!_isValidName(_name)) revert PactoUsernameNFT_InvalidName();
    if (_nameToNpub[_name] != bytes32(0) || _reservedNames[keccak256(bytes(_name))]) {
      revert PactoUsernameNFT_NameUnavailable();
    }
    if (_records[_npubHash].tokenId != 0) revert PactoUsernameNFT_NpubAlreadyClaimed();
    if (_addressToNpub[msg.sender] != bytes32(0)) revert PactoUsernameNFT_AddressAlreadyClaimed();
    if (_npubHash != NostrClaimLink.npubHashFromPubkey(_pubkey)) revert PactoUsernameNFT_InvalidNpubHash();
    if (_issuedAt > block.timestamp + CLOCK_SKEW || block.timestamp > _issuedAt + MAX_BINDING_AGE) {
      revert PactoUsernameNFT_BindingExpired();
    }
    if (_nonce <= usedNonce[_npubHash]) revert PactoUsernameNFT_NonceAlreadyUsed();
  }

  /// @notice Verifies the EIP-712 claim binding signature from the caller
  function _verifyEvmClaimSignature(
    bytes32 _npubHash,
    string calldata _name,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt,
    bytes calldata _evmSignature
  ) internal view {
    bytes32 _digest = _hashClaimBinding(_npubHash, msg.sender, _name, _nonce, _issuedAt, _salt);
    if (_evmSignature.length != 65) revert PactoUsernameNFT_InvalidClaimSignature();
    address _signer = _digest.recover(_evmSignature);
    if (_signer != msg.sender) revert PactoUsernameNFT_InvalidClaimSignature();
  }

  /// @notice Validates a lowercase alphabetic username
  /// @param _name The candidate username
  /// @return valid True when the name satisfies length and charset rules
  function _isValidName(string memory _name) internal pure returns (bool valid) {
    bytes memory _nameBytes = bytes(_name);
    uint256 _length = _nameBytes.length;
    if (_length < MIN_NAME_LENGTH || _length > MAX_NAME_LENGTH) return false;

    for (uint256 _i = 0; _i < _length; ++_i) {
      bytes1 _char = _nameBytes[_i];
      if (_char < 'a' || _char > 'z') return false;
    }

    return true;
  }

  /// @notice Computes the typed data hash for a claim binding
  /// @param _npubHash The hashed npub identity
  /// @param _evmAddress The claiming EVM address
  /// @param _name The username being claimed
  /// @param _nonce Binding nonce for replay protection
  /// @param _issuedAt Binding issuance timestamp
  /// @param _salt Binding salt for commit-reveal
  /// @return digest The typed data digest to sign
  function _hashClaimBinding(
    bytes32 _npubHash,
    address _evmAddress,
    string memory _name,
    uint256 _nonce,
    uint256 _issuedAt,
    bytes32 _salt
  ) internal view returns (bytes32 digest) {
    bytes32 _structHash = keccak256(
      abi.encode(CLAIM_BINDING_TYPEHASH, _npubHash, _evmAddress, keccak256(bytes(_name)), _nonce, _issuedAt, _salt)
    );
    digest = _hashTypedDataV4(_structHash);
  }

  /// @notice Restricts ERC-721 transfers to minting and controlled address rotation
  /// @param _to The recipient address
  /// @param _tokenId The token id being updated
  /// @param _auth The authorized caller
  /// @return The previous owner address
  function _update(address _to, uint256 _tokenId, address _auth) internal override returns (address) {
    address _from = _ownerOf(_tokenId);
    if (_from != address(0) && _to != address(0) && !_internalTransfer) {
      revert PactoUsernameNFT_TransferDisabled();
    }

    return super._update(_to, _tokenId, _auth);
  }
}
