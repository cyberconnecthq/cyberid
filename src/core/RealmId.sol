// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { OwnableUpgradeable } from "openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";

import { IMiddleware } from "../interfaces/IMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

import { MetadataResolver } from "../base/MetadataResolver.sol";

contract RealmId is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
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
    mapping(bytes32 => string) public baseTokenURIs;

    /**
     * @notice Middleware contract that processes before and after the registration.
     */
    mapping(bytes32 => address) public middlewares;

    /**
     * @notice The allowed parent nodes of the realmId.
     * e.g. namehash('moca'), namehash('music')
     * https://eips.ethereum.org/EIPS/eip-137
     */
    mapping(bytes32 => bool) public allowedParentNodes;

    /**
     * @notice The parent node of the tokenId.
     */
    mapping(uint256 => bytes32) public parents;

    /**
     * @notice The number of realmIds minted.
     */
    uint256 internal _mintCount;

    /**
     * @notice The number of burning for a tokenId.
     */
    mapping(uint256 => uint256) public burnCounts;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a realmId is registered.
     * For example, when "user.realm" is registered, the name is "user" and the parent node is namehash("realm").
     *
     * @param name         The name of the realmId
     * @param parentNode   The parent node of the realmId
     * @param tokenId      The tokenId of the realmId
     * @param to           The address that owns the realmId
     */
    event Register(
        string name,
        bytes32 parentNode,
        uint256 indexed tokenId,
        address indexed to
    );

    /**
     * @dev Emit an event when a realmId is burned.
     *
     * @param tokenId The tokenId of the realmId
     * @param burnCount The number of burning for the tokenId
     */
    event Burn(uint256 indexed tokenId, uint256 burnCount);

    /**
     * @dev Emit an event when a middleware is set.
     *
     * @param node       The node to set the middleware for
     * @param middleware The middleware contract address
     * @param data       The data of the middleware
     */
    event MiddlewareSet(bytes32 node, address indexed middleware, bytes data);

    /**
     * @dev Emit an event when a base token URI is set.
     *
     * @param node The node to set the base token URI for
     * @param uri The base token URI
     */
    event BaseTokenURISet(bytes32 node, string uri);

    /**
     * @dev Emit an event when a node allowance changed.
     *
     * @param node       The node
     * @param label      The label of the node
     * @param parentNode The parent node of the node
     * @param allowed    The new state of allowance
     */
    event NodeAllowanceChanged(
        bytes32 indexed node,
        string label,
        bytes32 parentNode,
        bool allowed
    );

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
        __Ownable_init();
        __Pausable_init();
        _pause();
        _transferOwnership(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a realmId is available for registration.
     *
     * @param _name       The name to check
     * @param parentNode The parent node of the realmId
     */
    function available(
        string calldata _name,
        bytes32 parentNode
    ) public view returns (bool) {
        require(allowedParentNodes[parentNode], "NODE_NOT_ALLOWED");
        uint256 tokenId = getTokenId(_name, parentNode);
        if (!_exists(tokenId)) {
            address middleware = middlewares[parentNode];
            if (middleware != address(0)) {
                return IMiddleware(middleware).namePatternValid(_name);
            } else {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Mints a new realmId.
     *
     * @param _name       The name to register
     * @param parentNode The parent node of the realmId
     * @param to         The address that will own the realmId
     * @param preData    The register data for preprocess.
     * @return uint256   Minted tokenId
     */
    function register(
        string calldata _name,
        bytes32 parentNode,
        address to,
        bytes calldata preData
    ) external returns (uint256) {
        address middleware = middlewares[parentNode];
        if (middleware != address(0)) {
            DataTypes.RegisterNameParams memory params = DataTypes
                .RegisterNameParams(msg.sender, _name, parentNode, to);
            IMiddleware(middleware).preProcess(params, preData);
        }
        return _register(_name, parentNode, to);
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
        delete parents[tokenId];
        super._burn(tokenId);
        --_mintCount;
        emit Burn(tokenId, ++burnCounts[tokenId]);
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
     * @param tokenId The uint256 tokenId of the realmId
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
        return
            string(
                abi.encodePacked(
                    baseTokenURIs[parents[tokenId]],
                    tokenId.toString()
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets token id of the gievn name and parent node.
     *
     * @return uint256 The token id.
     */
    function getTokenId(
        string calldata _name,
        bytes32 parentNode
    ) public pure returns (uint256) {
        bytes32 nodehash = keccak256(
            abi.encodePacked(parentNode, keccak256(bytes(_name)))
        );
        return uint256(nodehash);
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
    function setBaseTokenURI(
        bytes32 node,
        string calldata uri
    ) public onlyOwner {
        baseTokenURIs[node] = uri;
        emit BaseTokenURISet(node, uri);
    }

    /**
     * @notice Sets the middleware and data.
     */
    function setMiddleware(
        bytes32 node,
        address _middleware,
        bytes calldata data
    ) public onlyOwner {
        middlewares[node] = _middleware;
        if (_middleware != address(0)) {
            IMiddleware(_middleware).setMwData(data);
        }
        emit MiddlewareSet(node, _middleware, data);
    }

    /**
     * @notice Pauses all token transfers.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice allows node. E.g. '.moca', '.music'.
     * So that users can register realmId like 'abc.moca', 'abc.music'.
     * @dev allowNode("moca", bytes32(0)) to allow ".moca"
     */
    function allowNode(
        string calldata label,
        bytes32 parentNode,
        bool allow,
        string calldata baseTokenURI,
        address middleware,
        bytes calldata middlewareData
    ) external onlyOwner returns (bytes32 allowedNode) {
        allowedNode = keccak256(
            abi.encodePacked(parentNode, keccak256(bytes(label)))
        );
        allowedParentNodes[allowedNode] = allow;
        emit NodeAllowanceChanged(allowedNode, label, parentNode, allow);
        setBaseTokenURI(allowedNode, baseTokenURI);
        setMiddleware(allowedNode, middleware, middlewareData);
        return allowedNode;
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal view override {
        require(owner() == msg.sender, "NOT_OWNER");
    }

    function _register(
        string calldata _name,
        bytes32 parentNode,
        address to
    ) internal returns (uint256) {
        require(available(_name, parentNode), "NAME_NOT_AVAILABLE");
        uint256 tokenId = getTokenId(_name, parentNode);
        super._safeMint(to, tokenId);
        ++_mintCount;
        parents[tokenId] = parentNode;
        emit Register(_name, parentNode, tokenId, to);
        return tokenId;
    }

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        return super._isApprovedOrOwner(msg.sender, tokenId);
    }

    function _isGatedMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        require(_exists(tokenId), "TOKEN_NOT_MINTED");
        return owner() == msg.sender;
    }
}
