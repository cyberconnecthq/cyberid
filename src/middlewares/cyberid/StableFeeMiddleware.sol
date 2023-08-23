// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { FixedPointMathLib } from "solmate/src/utils/FixedPointMathLib.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";

import { LibString } from "../../libraries/LibString.sol";
import { DataTypes } from "../../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";

contract StableFeeMiddleware is LowerCaseCyberIdMiddleware, ReentrancyGuard {
    using LibString for *;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ETH/USD Oracle address.
     */
    AggregatorV3Interface public immutable usdOracle;

    /**
     * @notice The address that receives the fee.
     */
    address public recipient;

    // Rent in base price units by length
    uint256 public price1Letter;
    uint256 public price2Letter;
    uint256 public price3Letter;
    uint256 public price4Letter;
    uint256 public price5Letter;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev 60.18-decimal fixed-point that approximates divide by 4,605 when multiplied
    uint256 internal constant _DIV_4605_UD60X18 = 2.17166666666666e14;

    /// @dev Starting price of every bid during the first period
    uint256 internal constant _BID_START_PRICE = 1000 ether;

    /// @dev 60.18-decimal fixed-point that decreases the price by 10% when multiplied
    uint256 internal constant _BID_PERIOD_DECREASE_UD60X18 = 0.9 ether;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MwDataChanged(
        address indexed recipient,
        uint256 price1Letter,
        uint256 price2Letter,
        uint256 price3Letter,
        uint256 price4Letter,
        uint256 price5Letter
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _oracleAddress,
        address cyberId
    ) LowerCaseCyberIdMiddleware(cyberId) {
        usdOracle = AggregatorV3Interface(_oracleAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        (address _recipient, uint256[5] memory rentPrices) = abi.decode(
            data,
            (address, uint256[5])
        );
        recipient = _recipient;
        price1Letter = rentPrices[0];
        price2Letter = rentPrices[1];
        price3Letter = rentPrices[2];
        price4Letter = rentPrices[3];
        price5Letter = rentPrices[4];
        emit MwDataChanged(
            _recipient,
            rentPrices[0],
            rentPrices[1],
            rentPrices[2],
            rentPrices[3],
            rentPrices[4]
        );
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata
    )
        external
        payable
        override
        onlyNameRegistry
        nonReentrant
        returns (uint256)
    {
        uint256 cost = getPriceWei(params.cid, params.durationYear);
        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRenew(
        DataTypes.RenewCyberIdParams calldata params,
        bytes calldata
    )
        external
        payable
        override
        onlyNameRegistry
        nonReentrant
        returns (uint256)
    {
        uint256 cost = getPriceWei(params.cid, params.durationYear);
        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preBid(
        DataTypes.BidCyberIdParams calldata params,
        bytes calldata
    )
        external
        payable
        override
        onlyNameRegistry
        nonReentrant
        returns (uint256)
    {
        /**
         * Calculate the bid price for the dutch auction which the dutchPremium + renewalFee.
         *
         * dutchPremium starts at 1,000 ETH and decreases by 10% every 4,605 seconds:
         * dutchPremium = 1000 ether * (0.9)^(numPeriods)
         * numPeriods = (block.timestamp - auctionStartTimestamp) / 4_605
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
         * 10^10 for the next 50 years, which can be safely multiplied with _DIV_4605_UD60X18
         *
         * Safety/Audit: cost calcuation cannot intuitively over or underflow, but needs proof
         */

        uint256 cost;
        uint256 baseFee = getPriceWei(params.cid, 1);

        unchecked {
            int256 periodsSD59x18 = int256(
                (block.timestamp - params.auctionStartTimestamp) *
                    _DIV_4605_UD60X18
            );

            cost =
                _BID_START_PRICE.mulWadDown(
                    uint256(
                        FixedPointMathLib.powWad(
                            int256(_BID_PERIOD_DECREASE_UD60X18),
                            periodsSD59x18
                        )
                    )
                ) +
                baseFee;
        }

        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    function getPriceWei(
        string calldata cid,
        uint durationYear
    ) public view returns (uint256) {
        return _attoUSDToWei(_getUSDPrice(cid, durationYear));
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _getUSDPrice(
        string calldata cid,
        uint durationYear
    ) internal view returns (uint256) {
        uint256 len = cid.strlen();
        uint256 usdPrice;

        if (len >= 5) {
            usdPrice = price5Letter * durationYear * 365 days;
        } else if (len == 4) {
            usdPrice = price4Letter * durationYear * 365 days;
        } else if (len == 3) {
            usdPrice = price3Letter * durationYear * 365 days;
        } else if (len == 2) {
            usdPrice = price2Letter * durationYear * 365 days;
        } else {
            usdPrice = price1Letter * durationYear * 365 days;
        }
        return usdPrice;
    }

    function _getPrice() internal view returns (int256) {
        // prettier-ignore
        (
            uint80 roundID,
            int price,
            /* uint startedAt */,
            uint updatedAt,
            /*uint80 answeredInRound*/
        ) = usdOracle.latestRoundData();
        require(roundID != 0, "INVALID_ORACLE_ROUND_ID");
        require(price > 0, "INVALID_ORACLE_PRICE");
        require(updatedAt > block.timestamp - 3 hours, "STALE_ORACLE_PRICE");
        return price;
    }

    function _attoUSDToWei(uint256 amount) internal view returns (uint256) {
        uint256 ethPrice = uint256(_getPrice());
        return (amount * 1e8) / ethPrice;
    }

    function _chargeAndRefundOverPayment(
        uint256 cost,
        address refundTo
    ) internal {
        require(msg.value >= cost, "INSUFFICIENT_FUNDS");
        /**
         * Already checked msg.value >= cost
         */
        uint256 overpayment;
        unchecked {
            overpayment = msg.value - cost;
        }

        if (overpayment > 0) {
            (bool refundSuccess, ) = refundTo.call{ value: overpayment }("");
            require(refundSuccess, "REFUND_FAILED");
        }
        (bool chargeSuccess, ) = recipient.call{ value: cost }("");
        require(chargeSuccess, "CHARGE_FAILED");
    }
}
