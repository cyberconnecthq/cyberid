// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AccessControlUpgradeable } from "openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";

import { IMiddleware } from "../interfaces/IMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

import { MetadataResolver } from "../base/MetadataResolver.sol";

contract MocaId is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    MetadataResolver
{
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Token URI prefix.
     */
    string public baseTokenUri;

    /**
     * @notice Middleware contract that processes before and after the registration.
     */
    address public middleware;

    /**
     * @notice The number of mocaIds minted.
     */
    uint256 internal _mintCount;

    string internal constant _MOCA_XP_KEY = "MXP";

    bytes32 internal constant _OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a mocaId is registered.
     *
     * @param mocaId  The mocaId
     * @param tokenId The tokenId of the mocaId
     * @param to      The address that owns the mocaId
     */
    event Register(string mocaId, uint256 indexed tokenId, address indexed to);

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTORS AND INITIALIZERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Disable initialization to protect the contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize default storage values and inherited contracts. This should be called
     *         once after the contract is deployed via the ERC1967 proxy.
     *
     * @param _tokenName   The ERC-721 name of the fname token
     * @param _tokenSymbol The ERC-721 symbol of the fname token
     */
    function initialize(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        address _owner
    ) external initializer {
        /* Initialize inherited contracts */
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        _pause();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a mocaId is available for registration.
     *
     * @param mocaId The mocaId to register
     */
    function available(string calldata mocaId) public view returns (bool) {
        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        if (!_exists(tokenId)) {
            if (middleware != address(0)) {
                return IMiddleware(middleware).namePatternValid(mocaId);
            } else {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Mints a new mocaId.
     *
     * @param mocaId    The mocaId to register
     * @param to        The address that will own the mocaId
     * @param preData   The register data for preprocess.
     */
    function register(
        string calldata mocaId,
        address to,
        bytes calldata preData
    ) external {
        if (middleware != address(0)) {
            DataTypes.RegisterNameParams memory params = DataTypes
                .RegisterNameParams(msg.sender, mocaId, to);
            IMiddleware(middleware).preProcess(params, preData);
        }
        _register(mocaId, to);
    }

    /**
     * @notice Burns a token.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "UNAUTHORIZED");
        _clearMetadatas(tokenId);
        _clearGatedMetadatas(tokenId);
        super._burn(tokenId);
        --_mintCount;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(!paused(), "TRANSFER_NOT_ALLOWED");
        super.transferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(!paused(), "TRANSFER_NOT_ALLOWED");
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        require(!paused(), "TRANSFER_NOT_ALLOWED");
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Returns a distinct URI for a tokenId
     *
     * @param tokenId The uint256 tokenId of the mocaId
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
        return string(abi.encodePacked(baseTokenUri, tokenId.toHexString()));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets token id of the gievn moca id string.
     *
     * @return uint256 The token id.
     */
    function getTokenId(
        string calldata mocaId
    ) external pure returns (uint256) {
        return uint256(keccak256(bytes(mocaId)));
    }

    /**
     * @notice Gets total number of tokens in existence, burned tokens will reduce the count.
     *
     * @return uint256 The total supply.
     */
    function totalSupply() external view virtual returns (uint256) {
        return _mintCount;
    }

    /**
     * @notice Gets the moca xp of the given token id.
     * @param tokenId The token id.
     * @return string The moca xp.
     */
    function getMocaXP(uint256 tokenId) external view returns (string memory) {
        return this.getGatedMetadata(tokenId, _MOCA_XP_KEY);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the base token uri.
     */
    function setBaseTokenUri(
        string calldata uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseTokenUri = uri;
    }

    /**
     * @notice Sets the middleware and data.
     */
    function setMiddleware(
        address _middleware,
        bytes calldata data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        middleware = _middleware;
        if (middleware != address(0)) {
            IMiddleware(middleware).setMwData(data);
        }
    }

    /**
     * @notice Pauses all token transfers.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            OPERATOR ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the moca xp.
     */
    function setMocaXP(uint256 tokenId, string calldata xp) external {
        DataTypes.MetadataPair[] memory pairs = new DataTypes.MetadataPair[](1);
        pairs[0] = DataTypes.MetadataPair(_MOCA_XP_KEY, xp);
        this.batchSetGatedMetadatas(tokenId, pairs);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOT_ADMIN");
    }

    function _register(string calldata mocaId, address to) internal {
        require(available(mocaId), "NAME_NOT_AVAILABLE");

        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        super._safeMint(to, tokenId);
        ++_mintCount;
        emit Register(mocaId, tokenId, to);
    }

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        return super._isApprovedOrOwner(msg.sender, tokenId);
    }

    function _isGatedMetadataAuthorised(
        uint256
    ) internal view override returns (bool) {
        return hasRole(_OPERATOR_ROLE, msg.sender);
    }
}
