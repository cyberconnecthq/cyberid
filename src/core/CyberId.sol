// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AccessControlEnumerableUpgradeable } from "openzeppelin-upgradeable/contracts/access/AccessControlEnumerableUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import { ENS } from "@ens/registry/ENS.sol";
import { Resolver } from "@ens/resolvers/Resolver.sol";
import { ReverseRegistrar } from "@ens/registry/ReverseRegistrar.sol";

import { ICyberIdMiddleware } from "../interfaces/ICyberIdMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

contract CyberId is
    Initializable,
    ERC721Upgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The address of the CyberId registry.
     */
    address public cyberIdRegistry;

    /**
     * @notice The address of the reverse registrar.
     */
    address public reverseRegistrar;

    /**
     * @notice The address of the default resolver.
     */
    address public defaultResolver;

    /**
     * @notice Middleware contract that processes before register, renew and bid.
     */
    address public middleware;

    /**
     * @notice Maps each commit to the timestamp at which it was created.
     */
    mapping(bytes32 => uint256) public timestampOf;

    /**
     * @notice Token URI prefix.
     */
    string public baseTokenURI;

    /**
     * @notice The number of supplied cyberId.
     */
    uint256 internal _supplyCount;

    /**
     * @notice The mapping of token id to cid.
     */
    mapping(uint256 => string) public labels;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a cid is registered.
     *
     * @param from    The address that registered the cid
     * @param to      The address that owns the cid
     * @param tokenId The tokenId of the cid
     * @param cid     The cid
     * @param cost    The cost of the registration
     */
    event Register(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string cid,
        uint256 cost
    );

    /**
     * @dev Emit an event when a cid is burnt.
     *
     * @param from    The address that burnt the cid
     * @param tokenId The tokenId of the cid
     */
    event Burn(address indexed from, uint256 indexed tokenId);

    /**
     * @dev Emit an event when middleware is set.
     *
     * @param middleware The middleware contract address set to
     * @param data The middleware data to initialize with
     */
    event MiddlewareSet(address indexed middleware, bytes data);

    /**
     * @dev Emit an event when base token uri is set.
     *
     * @param baseTokenURI The base token uri set to
     */
    event BaseTokenURISet(string baseTokenURI);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev enforced delay between cmommit() and register() to prevent front-running
    uint256 internal constant _REVEAL_DELAY = 60 seconds;

    /// @dev enforced delay in commit() to prevent griefing by replaying the commit
    uint256 internal constant _COMMIT_REPLAY_DELAY = 1 days;

    bytes32 internal constant _OPERATOR_ROLE =
        keccak256(bytes("OPERATOR_ROLE"));

    bytes32 private constant _CYBER_NODE =
        0x085ce9dbd6bf88d21613576ea20ed9c2c0f37a9f4d3608bc0d69f735e4d2d146;

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
     */
    function initialize(
        address _cyberIdRegistry,
        address _defaultResolver,
        address _reverseRegistrar,
        string calldata _tokenName,
        string calldata _tokenSymbol,
        address _owner
    ) external initializer {
        cyberIdRegistry = _cyberIdRegistry;
        reverseRegistrar = _reverseRegistrar;
        defaultResolver = _defaultResolver;
        /* Initialize inherited contracts */
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __Pausable_init();
        _pause();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a cid is available for registration.
     *
     * @param cid The cid to register
     */
    function available(string calldata cid) public view returns (bool) {
        require(middleware != address(0), "MIDDLEWARE_NOT_SET");
        return ICyberIdMiddleware(middleware).namePatternValid(cid);
    }

    /**
     * @notice Generates a commitment to use in a commit-reveal scheme to register a cid and
     *         prevent front-running.
     *
     * @param cid            The cid to registere
     * @param to             The address that will own the cid
     * @param secret         A secret that will be broadcast on-chain during the reveal
     * @param middlewareData Data for middleware to process
     */
    function generateCommit(
        string calldata cid,
        address to,
        bytes32 secret,
        bytes calldata middlewareData
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(cid));
        return keccak256(abi.encodePacked(label, to, secret, middlewareData));
    }

    /**
     * @notice Saves a commitment on-chain which can be revealed later to register a cid. The
     *         commit reveal scheme protects the register action from being front run.
     *
     * @param commitment The commitment hash to be saved on-chain
     */
    function commit(bytes32 commitment) external {
        /**
         * Revert unless some time has passed since the last commit to prevent griefing by
         * replaying the commit and restarting the _REVEAL_DELAY timer.
         *
         * Safety: cannot overflow because timestampOf[commitment] is a block.timestamp or zero
         */
        unchecked {
            require(
                block.timestamp >
                    timestampOf[commitment] + _COMMIT_REPLAY_DELAY,
                "COMMIT_REPLAY"
            );
        }

        timestampOf[commitment] = block.timestamp;
    }

    /**
     * @notice Mints a new cid if the inputs match a previous commit and if it was called at least
     *         60 seconds after the commit's timestamp to prevent frontrunning within the same block.
     *
     * @param cid            The cid to register
     * @param to             The address that will own the cid
     * @param secret         The secret value in the commitment
     * @param middlewareData Data for middleware to process
     */
    function register(
        string calldata cid,
        address to,
        bytes32 secret,
        bytes calldata middlewareData
    ) external payable {
        require(middleware != address(0), "MIDDLEWARE_NOT_SET");
        if (!ICyberIdMiddleware(middleware).skipCommit()) {
            bytes32 commitment = generateCommit(
                cid,
                to,
                secret,
                middlewareData
            );
            uint256 commitTs = timestampOf[commitment];
            unchecked {
                require(
                    block.timestamp <= commitTs + _COMMIT_REPLAY_DELAY,
                    "NOT_COMMITTED"
                );
                require(
                    block.timestamp > commitTs + _REVEAL_DELAY,
                    "REGISTER_TOO_QUICK"
                );
            }
            delete timestampOf[commitment];
        }

        uint256 cost;
        cost = ICyberIdMiddleware(middleware).preRegister{ value: msg.value }(
            DataTypes.RegisterCyberIdParams(msg.sender, cid, to),
            middlewareData
        );

        _register(msg.sender, cid, to, defaultResolver, false, cost);
    }

    /**
     * @notice Burns a cyberid.
     *
     * @param cid The name to burn.
     */
    function burn(string calldata cid) external {
        uint256 tokenId = getTokenId(cid);
        require(_isApprovedOrOwner(msg.sender, tokenId), "UNAUTHORIZED");
        super._burn(tokenId);
        --_supplyCount;
        emit Burn(msg.sender, tokenId);
    }

    /**
     * @dev Reclaim ownership of a name in CyberIdRegistry, if you own it in the registrar.
     */
    function reclaim(string calldata cid, address owner) external {
        uint256 tokenId = getTokenId(cid);
        require(_isApprovedOrOwner(msg.sender, tokenId));
        ENS(cyberIdRegistry).setSubnodeOwner(
            _CYBER_NODE,
            keccak256(bytes(cid)),
            owner
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-165 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            AccessControlEnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC721Upgradeable.supportsInterface(interfaceId);
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
     * @param tokenId The uint256 tokenId of the cid
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
        return string(abi.encodePacked(baseTokenURI, tokenId.toHexString()));
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256
    ) internal override {
        if (from != address(0)) {
            address resolver = ENS(cyberIdRegistry).resolver(bytes32(tokenId));
            if (resolver == defaultResolver) {
                ENS(cyberIdRegistry).setSubnodeRecord(
                    _CYBER_NODE,
                    keccak256(bytes(labels[tokenId])),
                    to,
                    defaultResolver,
                    0
                );
                _setRecord(resolver, bytes32(tokenId), to);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets token id of the gievn cid.
     *
     * @return uint256 The token id.
     */
    function getTokenId(string calldata cid) public pure returns (uint256) {
        bytes32 nodehash = keccak256(
            abi.encodePacked(_CYBER_NODE, keccak256(bytes(cid)))
        );
        return uint256(nodehash);
    }

    /**
     * @notice Gets total number of tokens in existence, burned tokens will reduce the count.
     *
     * @return uint256 The total supply.
     */
    function totalSupply() external view virtual returns (uint256) {
        return _supplyCount;
    }

    /*//////////////////////////////////////////////////////////////
                            OPERATOR ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the base token uri.
     */
    function setBaseTokenURI(
        string calldata uri
    ) external onlyRole(_OPERATOR_ROLE) {
        baseTokenURI = uri;
        emit BaseTokenURISet(uri);
    }

    /**
     * @notice Sets the middleware and data.
     */
    function setMiddleware(
        address _middleware,
        bytes calldata data
    ) external onlyRole(_OPERATOR_ROLE) {
        require(_middleware != address(0), "ZERO_MIDDLEWARE");
        middleware = _middleware;
        ICyberIdMiddleware(_middleware).setMwData(data);
        emit MiddlewareSet(_middleware, data);
    }

    function batchRegister(
        DataTypes.BatchRegisterCyberIdParams[] calldata params
    ) external onlyRole(_OPERATOR_ROLE) {
        for (uint256 i = 0; i < params.length; i++) {
            _register(
                msg.sender,
                params[i].cid,
                params[i].to,
                params[i].resolver,
                true,
                0
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            DEFAULT_ADMIN ONLY
    //////////////////////////////////////////////////////////////*/

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

    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOT_OWNER");
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _register(
        address from,
        string calldata cid,
        address to,
        address resolver,
        bool setReverse,
        uint256 cost
    ) internal {
        require(available(cid), "NAME_NOT_AVAILABLE");
        if (resolver == address(0)) {
            resolver = defaultResolver;
        }
        bytes32 label = keccak256(bytes(cid));
        ENS(cyberIdRegistry).setSubnodeRecord(
            _CYBER_NODE,
            label,
            to,
            resolver,
            0
        );
        bytes32 nodeHash = keccak256(abi.encodePacked(_CYBER_NODE, label));
        uint256 tokenId = uint256(nodeHash);
        labels[tokenId] = cid;
        _setRecord(resolver, nodeHash, to);
        if (setReverse) {
            _setReverseRecord(cid, resolver, to);
        }
        super._safeMint(to, tokenId);
        _supplyCount++;
        emit Register(from, to, tokenId, cid, cost);
    }

    function _setRecord(
        address resolverAddress,
        bytes32 nodeHash,
        address to
    ) internal {
        if (resolverAddress == defaultResolver) {
            Resolver(resolverAddress).setAddr(nodeHash, to);
        }
    }

    function _setReverseRecord(
        string memory name,
        address resolver,
        address owner
    ) internal {
        ReverseRegistrar(reverseRegistrar).setNameForAddr(
            owner,
            owner,
            resolver,
            string.concat(name, ".cyber")
        );
    }
}
