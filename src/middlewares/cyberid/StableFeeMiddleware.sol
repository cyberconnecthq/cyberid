// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";

import { DataTypes } from "../../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";

contract StableFeeMiddleware is LowerCaseCyberIdMiddleware, ReentrancyGuard {
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
        uint256 cost = getPriceWei(params.cid);
        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
    }

    /// @inheritdoc ICyberIdMiddleware
    function skipCommit() external pure virtual override returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    function getPriceWei(string calldata cid) public view returns (uint256) {
        return _attoUSDToWei(_getUSDPrice(cid));
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _getUSDPrice(string calldata cid) internal view returns (uint256) {
        // LowerCaseCyberIdMiddleware ensures that each cid character only occupies 1 byte
        uint256 len = bytes(cid).length;
        uint256 usdPrice;

        if (len >= 5) {
            usdPrice = price5Letter;
        } else if (len == 4) {
            usdPrice = price4Letter;
        } else if (len == 3) {
            usdPrice = price3Letter;
        } else if (len == 2) {
            usdPrice = price2Letter;
        } else {
            usdPrice = price1Letter;
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
