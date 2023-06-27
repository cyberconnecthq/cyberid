// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

import { ICyberIdMiddleware } from "../interfaces/ICyberIdMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

import { MetadataResolver } from "../base/MetadataResolver.sol";

contract CyberId is ERC721, Ownable, MetadataResolver {
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

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
    string public baseTokenUri;

    /**
     * @notice Maps each uint256 representation of a cid to registration expire time.
     */
    mapping(uint256 => uint256) public expiries;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant _GRACE_PERIOD = 30 days;

    /// @dev enforced delay between cmommit() and register() to prevent front-running
    uint256 internal constant _REVEAL_DELAY = 60 seconds;

    /// @dev enforced delay in commit() to prevent griefing by replaying the commit
    uint256 internal constant _COMMIT_REPLAY_DELAY = 10 minutes;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a cid is registered.
     *
     * @param cid    The cid
     * @param to     The address that owns the cid
     * @param expiry The timestamp at which the registration expires
     * @param cost   The cost of the registration
     */
    event Register(
        string cid,
        address indexed to,
        uint256 expiry,
        uint256 cost
    );

    /**
     * @dev Emit an event when a cid is renewed.
     *
     * @param cid    The cid
     * @param expiry The timestamp at which the renewal expires
     * @param cost   The cost of the renewal
     */
    event Renew(string cid, uint256 expiry, uint256 cost);

    /**
     * @dev Emit an event when a cid is bid on.
     *
     * @param cid    The cid
     * @param expiry The timestamp at which the registration expires
     * @param cost   The cost of the bid
     */
    event Bid(string cid, uint256 expiry, uint256 cost);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) {
        _transferOwnership(_owner);
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
        bytes32 label = keccak256(bytes(cid));
        if (expiries[uint256(label)] == 0) {
            if (middleware != address(0)) {
                return ICyberIdMiddleware(middleware).namePatternValid(cid);
            } else {
                return true;
            }
        }
        return false;
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
     * @param durationYear   The duration of the registration. Unit: year
     * @param middlewareData Data for middleware to process
     */
    function register(
        string calldata cid,
        address to,
        bytes32 secret,
        uint8 durationYear,
        bytes calldata middlewareData
    ) external payable {
        if (
            middleware == address(0) ||
            !ICyberIdMiddleware(middleware).skipCommit()
        ) {
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
        if (middleware != address(0)) {
            cost = ICyberIdMiddleware(middleware).preRegister{
                value: msg.value
            }(
                DataTypes.RegisterCyberIdParams(
                    msg.sender,
                    cid,
                    to,
                    durationYear
                ),
                middlewareData
            );
        }

        _register(cid, to, durationYear, cost);
    }

    /**
     * @notice Renew a name for a duration while it is in the renewable period.
     *
     * @param cid            The the cid to renew
     * @param durationYear   The duration of the renewal. Unit: year
     * @param middlewareData Data for middleware to process
     */
    function renew(
        string calldata cid,
        uint8 durationYear,
        bytes calldata middlewareData
    ) external payable {
        /* Revert if the cid's tokenId has never been registered */
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        uint256 expiryTs = expiries[tokenId];
        require(expiryTs > 0, "NOT_REGISTERED");

        /**
         * Revert if the cid has passed out of the renewable period into the biddable period.
         */
        unchecked {
            require(
                block.timestamp < expiryTs + _GRACE_PERIOD,
                "NOT_RENEWABLE"
            );
        }

        uint256 cost;
        if (middleware != address(0)) {
            cost = ICyberIdMiddleware(middleware).preRenew{ value: msg.value }(
                DataTypes.RenewCyberIdParams(msg.sender, cid, durationYear),
                middlewareData
            );
        }

        /**
         * Renew the name by setting the new expiration timestamp
         */
        expiries[tokenId] += durationYear * 365 days;
        emit Renew(cid, expiries[tokenId], cost);
    }

    /**
     * @notice Bid to purchase an expired cid in a dutch auction and register it for a year. The
     *         winning bid starts at ~1000.01 ETH decays exponentially until it reaches 0.
     *
     * @param to             The address where the cid should be transferred
     * @param cid            The cid to bid on
     * @param middlewareData Data for middleware to process
     */
    function bid(
        address to,
        string calldata cid,
        bytes calldata middlewareData
    ) external payable {
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        /* Revert if the token was never registered */
        uint256 expiryTs = expiries[tokenId];
        require(expiryTs > 0, "NOT_REGISTERED");

        /**
         * Revert if the cid is not yet in the auction period.
         */
        uint256 auctionStartTimestamp;
        unchecked {
            auctionStartTimestamp = expiryTs + _GRACE_PERIOD;
        }
        require(block.timestamp >= auctionStartTimestamp, "NOT_BIDDABLE");

        uint256 cost;
        if (middleware != address(0)) {
            cost = ICyberIdMiddleware(middleware).preBid{ value: msg.value }(
                DataTypes.BidCyberIdParams(
                    msg.sender,
                    cid,
                    to,
                    auctionStartTimestamp
                ),
                middlewareData
            );
        }

        /**
         * Transfer the cid to the new owner by calling the ERC-721 transfer function, and update
         * the expiration. The current owner is determined with
         * super.ownerOf which will not revert even if expired.
         *
         * Safety: expiryTs cannot overflow given block.timestamp and registration period sizes.
         */
        address originalOwner = super.ownerOf(tokenId);
        _safeTransfer(originalOwner, to, tokenId, "");
        if (originalOwner != to) {
            _clearMetadatas(tokenId);
        }

        unchecked {
            expiries[tokenId] = block.timestamp + 365 days;
        }

        emit Bid(cid, expiries[tokenId], cost);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override the ownerOf implementation to throw if a cid is renewable or biddable.
     *
     * @param tokenId The uint256 tokenId of the cid
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        /* Revert if cid was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }

        /* Safety: If the token is unregistered, super.ownerOf will revert */
        return super.ownerOf(tokenId);
    }

    /**
     * @notice Override transferFrom to throw if the name is renewable or biddable.
     *
     * @param from    The address which currently holds the cid
     * @param to      The address to transfer the cid to
     * @param tokenId The uint256 representation of the cid to transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        /* Revert if cid was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }

        super.safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @notice Override safeTransferFrom to throw if the name is renewable or biddable.
     *
     * @param from     The address which currently holds the cid
     * @param to       The address to transfer the cid to
     * @param tokenId  The uint256 tokenId of the cid to transfer
     * @param data     Additional data with no specified format, sent in call to `to`
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        /* Revert if cid was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }

        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Return a distinct URI for a tokenId
     *
     * @param tokenId The uint256 tokenId of the cid
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return string(abi.encodePacked(baseTokenUri, tokenId.toHexString()));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    function getTokenId(string calldata cid) external pure returns (uint256) {
        return uint256(keccak256(bytes(cid)));
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the base token uri.
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
            ICyberIdMiddleware(middleware).setMwData(data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _register(
        string calldata cid,
        address to,
        uint8 durationYear,
        uint256 cost
    ) internal {
        require(available(cid), "NAME_NOT_AVAILABLE");
        require(durationYear >= 1, "MIN_DURATION_ONE_YEAR");

        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        super._safeMint(to, tokenId);

        unchecked {
            expiries[tokenId] = block.timestamp + durationYear * 365 days;
        }

        emit Register(cid, to, expiries[tokenId], cost);
    }

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        /* Revert if cid was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }
        return super._isApprovedOrOwner(msg.sender, tokenId);
    }

    function _isGatedMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        /* Revert if cid was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }
        return owner() == msg.sender;
    }
}
