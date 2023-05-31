// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { OwnableUpgradeable } from "openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMiddleware } from "../interfaces/IMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

import { MetadataResolver } from "../base/MetadataResolver.sol";

contract MocaId is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
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
        _transferOwnership(_owner);
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
        super._burn(tokenId);
        --_mintCount;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    function transferFrom(address, address, uint256) public pure override {
        revert("TRANSFER_NOT_ALLOWED");
    }

    /// @inheritdoc ERC721Upgradeable
    function safeTransferFrom(address, address, uint256) public pure override {
        revert("TRANSFER_NOT_ALLOWED");
    }

    /// @inheritdoc ERC721Upgradeable
    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override {
        revert("TRANSFER_NOT_ALLOWED");
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

    /*//////////////////////////////////////////////////////////////
                            OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the base token uri.
     */
    function setBaseTokenUri(string calldata uri) external onlyOwner {
        baseTokenUri = uri;
    }

    /**
     * @notice Sets the middleware and data.
     */
    function setMiddleware(
        address _middleware,
        bytes calldata data
    ) external onlyOwner {
        middleware = _middleware;
        if (middleware != address(0)) {
            IMiddleware(middleware).setMwData(data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal view override onlyOwner {}

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
}
