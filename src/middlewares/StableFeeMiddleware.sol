// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { FixedPointMathLib } from "solmate/src/utils/FixedPointMathLib.sol";

import { ICyberIdMiddleware } from "../interfaces/ICyberIdMiddleware.sol";

import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";

contract StableFeeMiddleware is LowerCaseCyberIdMiddleware {
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

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev 60.18-decimal fixed-point that approximates divide by 28,800 when multiplied
    uint256 internal constant _DIV_28800_UD60X18 = 3.4722222222222e13;

    /// @dev Starting price of every bid during the first period
    uint256 internal constant _BID_START_PRICE = 1000 ether;

    /// @dev 60.18-decimal fixed-point that decreases the price by 10% when multiplied
    uint256 internal constant _BID_PERIOD_DECREASE_UD60X18 = 0.9 ether;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address oracleAddress) {
        usdOracle = AggregatorV3Interface(oracleAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override {
        address _recipient = abi.decode(data, (address));
        recipient = _recipient;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata data
    ) external payable override returns (uint256) {
        uint80 roundId = abi.decode(data, (uint80));
        uint256 cost = getPriceWeiAt(params.cid, roundId, params.durationYear);
        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRenew(
        DataTypes.RenewCyberIdParams calldata params,
        bytes calldata
    ) external payable override returns (uint256) {
        uint256 cost = getPriceWei(params.cid, params.durationYear);
        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preBid(
        DataTypes.BidCyberIdParams calldata params,
        bytes calldata
    ) external payable override returns (uint256) {
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
         * 10^10 for the next 50 years, which can be safely multiplied with _DIV_28800_UD60X18
         *
         * Safety/Audit: cost calcuation cannot intuitively over or underflow, but needs proof
         */

        uint256 cost;
        uint256 baseFee = getPriceWei(params.cid, 1);

        unchecked {
            int256 periodsSD59x18 = int256(
                (block.timestamp - params.auctionStartTimestamp) *
                    _DIV_28800_UD60X18
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
