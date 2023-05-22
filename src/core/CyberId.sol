// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { LibString } from "../libraries/LibString.sol";

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { FixedPointMathLib } from "solmate/src/utils/FixedPointMathLib.sol";
import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract CyberId is ERC721 {
    using LibString for *;
    using FixedPointMathLib for uint256;

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

    /**
     * @notice Oracle address.
     * @dev    Occupies slot 3
     */
    AggregatorV3Interface public immutable usdOracle;

    /**
     * @notice The address allowed to call trustedRegister
     * @dev    Occupies slot 4
     */
    address public trustedCaller;

    /**
     * @notice The address allowed to call trustedRegister
     * @dev    Occupies slot 5
     */
    string public baseTokenUri;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev enforced delay between cmommit() and register() to prevent front-running
    uint256 internal constant REVEAL_DELAY = 60 seconds;

    /// @dev enforced delay in commit() to prevent griefing by replaying the commit
    uint256 internal constant COMMIT_REPLAY_DELAY = 10 minutes;

    uint256 public constant GRACE_PERIOD = 30 days;

    /// @dev 60.18-decimal fixed-point that approximates divide by 28,800 when multiplied
    uint256 internal constant DIV_28800_UD60X18 = 3.4722222222222e13;

    /// @dev Starting price of every bid during the first period
    uint256 internal constant BID_START_PRICE = 1000 ether;

    /// @dev 60.18-decimal fixed-point that decreases the price by 10% when multiplied
    uint256 internal constant BID_PERIOD_DECREASE_UD60X18 = 0.9 ether;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a cid is renewed.
     *
     * @param cid The cid
     * @param expiry  The timestamp at which the renewal expires
     */
    event Renew(string cid, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        address _usdOracle
    ) ERC721(_name, _symbol) {
        trustedOnly = true;
        usdOracle = AggregatorV3Interface(_usdOracle);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a cid is available for registration.
     *
     * @param cid The cid to register
     */
    function available(string calldata cid) public view returns (bool) {
        bytes32 label = keccak256(bytes(cid));
        return
            valid(cid) &&
            _expiries[uint256(label)] + GRACE_PERIOD < block.timestamp;
    }

    /**
     * @notice Generate a commitment to use in a commit-reveal scheme to register a cid and
     *         prevent front-running.
     *
     * @param cid   The cid to be registered
     * @param to     The address that will own the cid
     * @param roundId     The usd oracle roundId
     * @param secret A secret that will be broadcast on-chain during the reveal
     */
    function generateCommit(
        string calldata cid,
        address to,
        uint80 roundId,
        bytes32 secret
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(cid));
        return keccak256(abi.encodePacked(label, to, roundId, secret));
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
     * @param roundId     The usd oracle roundId
     * @param secret   The secret value in the commitment
     * @param durationYear The duration of the registration. Unit: year
     */
    function register(
        string calldata cid,
        address to,
        uint80 roundId,
        bytes32 secret,
        uint durationYear
    ) external payable {
        bytes32 commitment = generateCommit(cid, to, roundId, secret);
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

        uint256 cost = getPriceWeiAt(cid, roundId, durationYear);
        require(msg.value >= cost, "INSUFFICIENT_FUNDS");

        /**
         * Mints the token by calling the ERC-721 _mint() function and using the uint256 value of
         * the username as the tokenId. The _mint() function ensures that the to address isnt 0
         * and that the tokenId is not already minted.
         */
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        super._mint(to, tokenId);

        /**
         * Set the expiration timestamp
         */
        unchecked {
            _expiries[tokenId] = block.timestamp + durationYear * 365 days;
        }

        if (msg.value > cost) {
            (bool sent, ) = msg.sender.call{ value: msg.value - cost }("");
            require(sent, "REFUND_FAILED");
        }
    }

    function trustedRegister(
        string calldata cid,
        address to,
        uint durationYear
    ) external {
        require(trustedOnly, "REGISTRATION_STARTED");
        require(msg.sender == trustedCaller, "UNAUTHORIZED");
        require(available(cid), "INVALID_NAME");
        require(durationYear >= 1, "MIN_DURATION_ONE_YEAR");
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        super._mint(to, tokenId);
        unchecked {
            _expiries[tokenId] = block.timestamp + durationYear * 365 days;
        }
    }

    /**
     * @notice Renew a name for a duration while it is in the renewable period.
     *
     * @param cid The the cid to renew
     */
    function renew(string calldata cid, uint8 durationYear) external payable {
        uint256 cost = getPriceWei(cid, durationYear);
        require(msg.value >= cost, "INSUFFICIENT_FUNDS");

        /* Revert if the cid's tokenId has never been registered */
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        uint256 expiryTs = uint256(_expiries[tokenId]);
        require(expiryTs > 0, "NOT_REGISTERED");

        /**
         * Revert if the cid has passed out of the renewable period into the biddable period.
         *
         * Safety: expiryTs is set one year ahead of block.timestamp and cannot overflow.
         */
        unchecked {
            require(block.timestamp < expiryTs + GRACE_PERIOD, "NOT_RENEWABLE");
        }

        /**
         * Renew the name by setting the new expiration timestamp
         *
         * Safety: tokenId is not owned by address(0) because of INVARIANT 1B + 2
         */
        _expiries[tokenId] += durationYear * 365 days;

        emit Renew(cid, uint256(_expiries[tokenId]));

        uint256 overpayment;
        unchecked {
            overpayment = msg.value - cost;
        }

        if (overpayment > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = msg.sender.call{ value: overpayment }("");
            require(success, "REFUND_FAILED");
        }
    }

    /**
     * @notice Bid to purchase an expired cid in a dutch auction and register it for a year. The
     *         winning bid starts at ~1000.01 ETH decays exponentially until it reaches 0.
     *
     * @param to   The address where the fname should be transferred
     * @param cid  The cid to bid on
     */
    function bid(address to, string calldata cid) external payable {
        bytes32 label = keccak256(bytes(cid));
        uint256 tokenId = uint256(label);
        /* Revert if the token was never registered */
        uint256 expiryTs = uint256(_expiries[tokenId]);
        require(expiryTs > 0, "NOT_REGISTERED");

        /**
         * Revert if the cid is not yet in the auction period.
         *
         */
        uint256 auctionStartTimestamp;
        unchecked {
            auctionStartTimestamp = expiryTs + GRACE_PERIOD;
        }
        require(block.timestamp >= auctionStartTimestamp, "NOT_BIDDABLE");

        /**
         * Calculate the bid price for the dutch auction which the dutchPremium + renewalFee.
         *
         * dutchPremium starts at 1,000 ETH and decreases by 10% every 8 hours or 28,800 seconds:
         * dutchPremium = 1000 ether * (0.9)^(numPeriods)
         * numPeriods = (block.timestamp - auctionStartTimestamp) / 28_800
         *
         * numPeriods is calculated with fixed-point multiplication which causes a slight error
         * that increases the price (DivErr), while dutchPremium is calculated by the identity
         * (x^y = exp(ln(x) * y)) which loses 3 digits of precision and lowers the price (ExpErr).
         * The two errors interact in different ways keeping the price slightly higher or lower
         * than expected as shown below:
         *
         * +=========+======================+========================+========================+
         * | Periods |        NoErr         |         DivErr         |    PowErr + DivErr     |
         * +=========+======================+========================+========================+
         * |       1 |                900.0 | 900.000000000000606876 | 900.000000000000606000 |
         * +---------+----------------------+------------------------+------------------------+
         * |      10 |          348.6784401 | 348.678440100002351164 | 348.678440100002351000 |
         * +---------+----------------------+------------------------+------------------------+
         * |     100 | 0.026561398887587476 |   0.026561398887589867 |   0.026561398887589000 |
         * +---------+----------------------+------------------------+------------------------+
         * |     393 | 0.000000000000001040 |   0.000000000000001040 |   0.000000000000001000 |
         * +---------+----------------------+------------------------+------------------------+
         * |     394 |                  0.0 |                    0.0 |                    0.0 |
         * +---------+----------------------+------------------------+------------------------+
         *
         * The values are not precomputed since space is the major constraint in this contract.
         *
         * Safety: auctionStartTimestamp <= block.timestamp and their difference will be under
         * 10^10 for the next 50 years, which can be safely multiplied with DIV_28800_UD60X18
         *
         * Safety/Audit: price calcuation cannot intuitively over or underflow, but needs proof
         */

        uint256 price;
        uint256 baseFee = getPriceWei(cid, 1);

        unchecked {
            int256 periodsSD59x18 = int256(
                (block.timestamp - auctionStartTimestamp) * DIV_28800_UD60X18
            );

            price =
                BID_START_PRICE.mulWadDown(
                    uint256(
                        FixedPointMathLib.powWad(
                            int256(BID_PERIOD_DECREASE_UD60X18),
                            periodsSD59x18
                        )
                    )
                ) +
                baseFee;
        }

        /* Revert if the transaction cannot pay the full price of the bid */
        require(msg.value >= price, "INSUFFICIENT_FUNDS");

        /**
         * Transfer the cid to the new owner by calling the ERC-721 transfer function, and update
         * the expiration date and recovery addres. The current owner is determined with
         * super.ownerOf which will not revert even if expired.
         *
         * Safety: expiryTs cannot overflow given block.timestamp and registration period sizes.
         */
        _transfer(super.ownerOf(tokenId), to, tokenId);

        unchecked {
            _expiries[tokenId] = block.timestamp + 365 days;
        }

        /**
         * Refund overpayment to the caller and revert if the refund fails.
         *
         * Safety: msg.value >= _fee by check above, so this cannot overflow
         * Perf: Call msg.sender instead of _msgSender() to save ~100 gas b/c we don't need meta-tx
         */
        uint256 overpayment;

        unchecked {
            overpayment = msg.value - price;
        }

        if (overpayment > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = msg.sender.call{ value: overpayment }("");
            require(success, "REFUND_FAILED");
        }
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
        uint256 expiryTs = _expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }

        /* Safety: If the token is unregistered, super.ownerOf will revert */
        return super.ownerOf(tokenId);
    }

    /* Audit: ERC721 balanceOf will over report owner balance if the name is expired */

    /**
     * @notice Override transferFrom to throw if the name is renewable or biddable.
     *
     * @param from    The address which currently holds the fname
     * @param to      The address to transfer the fname to
     * @param tokenId The uint256 representation of the fname to transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        /* Revert if fname was registered once and the expiration time has passed */
        uint256 expiryTs = _expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }

        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Override safeTransferFrom to throw if the name is renewable or biddable.
     *
     * @param from     The address which currently holds the fname
     * @param to       The address to transfer the fname to
     * @param tokenId  The uint256 tokenId of the fname to transfer
     * @param data     Additional data with no specified format, sent in call to `to`
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        /* Revert if fname was registered once and the expiration time has passed */
        uint256 expiryTs = _expiries[tokenId];
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
        return
            string(
                abi.encodePacked(
                    baseTokenUri,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    function getPriceWeiAt(
        string calldata cid,
        uint80 roundId,
        uint durationYear
    ) public view returns (uint256) {
        // todo: price calculation
        return _attoUSDToWeiAt(cid.strlen() * durationYear, roundId);
    }

    function getPriceWei(
        string calldata cid,
        uint durationYear
    ) public view returns (uint256) {
        // todo: price calculation
        return _attoUSDToWei(cid.strlen() * durationYear);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

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

    function _getPriceAt(uint80 roundId) internal view returns (int256) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = usdOracle.getRoundData(roundId);
        return price;
    }

    function _getPrice() internal view returns (int256) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = usdOracle.latestRoundData();
        return price;
    }

    function _attoUSDToWeiAt(
        uint256 amount,
        uint80 roundId
    ) internal view returns (uint256) {
        uint256 ethPrice = uint256(_getPriceAt(roundId));
        return (amount * 1e8 * 1e18) / ethPrice;
    }

    function _attoUSDToWei(uint256 amount) internal view returns (uint256) {
        uint256 ethPrice = uint256(_getPrice());
        return (amount * 1e8 * 1e18) / ethPrice;
    }
}
