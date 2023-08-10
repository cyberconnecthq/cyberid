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
    string public baseTokenURI;

    /**
     * @notice Middleware contract that processes before and after the registration.
     */
    address public middleware;

    /**
     * @notice The allowed parent nodes of the mocaId.
     * e.g. namehash('moca'), namehash('music')
     * https://eips.ethereum.org/EIPS/eip-137
     */
    mapping(bytes32 => bool) public allowedParentNodes;

    /**
     * @notice The number of mocaIds minted.
     */
    uint256 internal _mintCount;

    bytes32 internal constant _OPERATOR_ROLE =
        keccak256(bytes("OPERATOR_ROLE"));

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a mocaId is registered.
     * For example, when "user.moca" is registered, the name is "user" and the parent node is namehash("moca").
     *
     * @param name         The name of the mocaId
     * @param parentNode   The parent node of the mocaId
     * @param tokenId      The tokenId of the mocaId
     * @param to           The address that owns the mocaId
     */
    event Register(
        string name,
        bytes32 parentNode,
        uint256 indexed tokenId,
        address indexed to
    );

    /**
     * @dev Emit an event when a mocaId is burned.
     *
     * @param tokenId The tokenId of the mocaId
     */
    event Burn(uint256 indexed tokenId);

    /**
     * @dev Emit an event when a middleware is set.
     *
     * @param middleware The middleware contract address
     * @param data       The data of the middleware
     */
    event MiddlewareSet(address indexed middleware, bytes data);

    /**
     * @dev Emit an event when a base token URI is set.
     *
     * @param uri The base token URI
     */
    event BaseTokenURISet(string uri);

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
     * @param _name       The name to check
     * @param parentNode The parent node of the mocaId
     */
    function available(
        string calldata _name,
        bytes32 parentNode
    ) public view returns (bool) {
        require(allowedParentNodes[parentNode], "NODE_NOT_ALLOWED");
        uint256 tokenId = getTokenId(_name, parentNode);
        if (!_exists(tokenId)) {
            if (middleware != address(0)) {
                return IMiddleware(middleware).namePatternValid(_name);
            } else {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Mints a new mocaId.
     *
     * @param _name       The name to register
     * @param parentNode The parent node of the mocaId
     * @param to         The address that will own the mocaId
     * @param preData    The register data for preprocess.
     * @return uint256   Minted tokenId
     */
    function register(
        string calldata _name,
        bytes32 parentNode,
        address to,
        bytes calldata preData
    ) external returns (uint256) {
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
        super._burn(tokenId);
        --_mintCount;
        emit Burn(tokenId);
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
        return string(abi.encodePacked(baseTokenURI, tokenId.toString()));
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
    function setbaseTokenURI(
        string calldata uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseTokenURI = uri;
        emit BaseTokenURISet(uri);
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
        emit MiddlewareSet(_middleware, data);
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
     * @notice allows node. E.g. '.moca', '.music'.
     * So that users can register mocaId like 'abc.moca', 'abc.music'.
     * @dev allowNode("moca", bytes32(0)) to allow ".moca"
     */
    function allowNode(
        string calldata label,
        bytes32 parentNode,
        bool allow
    ) external onlyRole(_OPERATOR_ROLE) returns (bytes32 allowedNode) {
        allowedNode = keccak256(
            abi.encodePacked(parentNode, keccak256(bytes(label)))
        );
        allowedParentNodes[allowedNode] = allow;
        emit NodeAllowanceChanged(allowedNode, label, parentNode, allow);
        return allowedNode;
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOT_ADMIN");
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
        return hasRole(_OPERATOR_ROLE, msg.sender);
    }
}
