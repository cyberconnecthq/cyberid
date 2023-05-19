// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { CyberNFTBase } from "../base/CyberNFTBase.sol";

import { LibString } from "../libraries/LibString.sol";

contract CyberId is CyberNFTBase {
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Flag that determines if registration can occur through trustedRegister or register
     * @dev    Occupies slot 0, initialized to true and can only be changed to false
     */
    bool public trustedOnly;

    /**
     * @notice Maps each commit to the timestamp at which it was created.
     * @dev    Occupies slot 1
     */
    mapping(bytes32 => uint256) public timestampOf;

    /**
     * @notice Maps each uint256 representation of a cid to registration expire time.
     * @dev    Occupies slot 2
     */
    mapping(uint256 => uint) _expiries;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev enforced delay between cmommit() and register() to prevent front-running
    uint256 internal constant REVEAL_DELAY = 60 seconds;

    /// @dev enforced delay in commit() to prevent griefing by replaying the commit
    uint256 internal constant COMMIT_REPLAY_DELAY = 10 minutes;

    uint256 public constant GRACE_PERIOD = 30 days;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name,
        string memory symbol
    ) CyberNFTBase(name, symbol) {
        trustedOnly = true;
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function available(string calldata cid) public view returns (bool) {
        bytes32 label = keccak256(bytes(cid));
        return
            valid(cid) &&
            _expiries[uint256(label)] + GRACE_PERIOD < block.timestamp;
    }

    function valid(string calldata cid) public pure returns (bool) {
        // check unicode rune count, if rune count is >=3, byte length must be >=3.
        if (cid.strlen() < 3) {
            return false;
        }
        bytes memory nb = bytes(cid);
        // zero width for /u200b /u200c /u200d and U+FEFF
        for (uint256 i; i < nb.length - 2; i++) {
            if (bytes1(nb[i]) == 0xe2 && bytes1(nb[i + 1]) == 0x80) {
                if (
                    bytes1(nb[i + 2]) == 0x8b ||
                    bytes1(nb[i + 2]) == 0x8c ||
                    bytes1(nb[i + 2]) == 0x8d
                ) {
                    return false;
                }
            } else if (bytes1(nb[i]) == 0xef) {
                if (bytes1(nb[i + 1]) == 0xbb && bytes1(nb[i + 2]) == 0xbf)
                    return false;
            }
        }
        return true;
    }

    /**
     * @notice Generate a commitment to use in a commit-reveal scheme to register a cid and
     *         prevent front-running.
     *
     * @param cid   The cid to be registered
     * @param to     The address that will own the cid
     * @param secret A secret that will be broadcast on-chain during the reveal
     */
    function generateCommit(
        string calldata cid,
        address to,
        bytes32 secret
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(cid));
        return keccak256(abi.encodePacked(label, to, secret));
    }

    /**
     * @notice Save a commitment on-chain which can be revealed later to register a cid. The
     *         commit reveal scheme protects the register action from being front run.
     *
     * @param commitment The commitment hash to be saved on-chain
     */
    function commit(bytes32 commitment) public {
        require(!trustedOnly, "REGISTRATION_NOT_STARTED");

        /**
         * Revert unless some time has passed since the last commit to prevent griefing by
         * replaying the commit and restarting the REVEAL_DELAY timer.
         *
         *  Safety: cannot overflow because timestampOf[commitment] is a block.timestamp or zero
         */
        unchecked {
            require(
                block.timestamp > timestampOf[commitment] + COMMIT_REPLAY_DELAY,
                "COMMIT_REPLAY"
            );
        }

        timestampOf[commitment] = block.timestamp;
    }

    /**
     * @notice Mint a new cid if the inputs match a previous commit and if it was called at least
     *         60 seconds after the commit's timestamp to prevent frontrunning within the same block.
     *
     * @param cid    The cid to register
     * @param to       The address that will own the fname
     * @param secret   The secret value in the commitment
     * @param durationYear The duration of the registration. Unit: year
     */
    function register(
        string calldata cid,
        address to,
        bytes32 secret,
        uint durationYear
    ) external payable {
        bytes32 commitment = generateCommit(cid, to, secret);
        uint256 commitTs = timestampOf[commitment];
        unchecked {
            require(
                block.timestamp <= commitTs + COMMIT_REPLAY_DELAY,
                "NOT_COMMITTED"
            );
            require(
                block.timestamp > commitTs + REVEAL_DELAY,
                "REGISTER_TOO_QUICK"
            );
        }
        require(available(cid), "INVALID_NAME");
        require(durationYear >= 1, "MIN_DURATION_ONE_YEAR");
        delete timestampOf[commitment];

        // todo: get the price from oracle
        // require(msg.value >= cost)

        /**
         * Mints the token by calling the ERC-721 _mint() function and using the uint256 value of
         * the username as the tokenId. The _mint() function ensures that the to address isnt 0
         * and that the tokenId is not already minted.
         */
        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);
        super._mint(to, tokenId);

        /**
         * Set the expiration timestamp and the recovery address
         */
        unchecked {
            _expiries[tokenId] = block.timestamp + durationYear * 365 days;
        }

        /**
         * Refund overpayment to the caller and revert if the refund fails.
         *
         * Safety: msg.value >= _fee by check above, so this cannot overflow
         * Perf: Call msg.sender instead of _msgSender() to save ~100 gas b/c we don't need meta-tx
         */
        // todo: refund
        // if (msg.value > cost) {
        //     (bool sent, ) = msg.sender.call{value: msg.value - cost}("");
        //     require(sent, "REFUND_FAILED");
        // }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates the metadata json object.
     *
     * @param tokenId The profile NFT token ID.
     * @return string The metadata json object.
     * @dev It requires the tokenId to be already minted.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        // TODO: tokenURI
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _mint(address to) internal override returns (uint256) {
        return super._mint(to);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
}
