// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";
import { ITokenReceiver } from "../../interfaces/ITokenReceiver.sol";

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
     * @notice TokenReceiver contract address.
     */
    ITokenReceiver public immutable tokenReceiver;

    /**
     * If true, the middleware will charge the fee to token receiver.
     */
    bool public rebateEnabled;

    /**
     * @notice The address that receives the fee.
     */
    address public recipient;

    /**
     * @notice The price of each letter in USD.
     */
    uint256 public price1Letter;
    uint256 public price2Letter;
    uint256 public price3Letter;
    uint256 public price4Letter;
    uint256 public price5Letter;
    uint256 public price6Letter;
    uint256 public price7To11Letter;
    uint256 public price12AndMoreLetter;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event RebateChanged(bool rebateEnabled);

    event RecipientChanged(address recipient);

    event StableFeeChanged(
        uint256 price1Letter,
        uint256 price2Letter,
        uint256 price3Letter,
        uint256 price4Letter,
        uint256 price5Letter,
        uint256 price6Letter,
        uint256 price7To11Letter,
        uint256 price12AndMoreLetter
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _oracleAddress,
        address _tokenReceiver,
        address cyberId
    ) LowerCaseCyberIdMiddleware(cyberId) {
        usdOracle = AggregatorV3Interface(_oracleAddress);
        tokenReceiver = ITokenReceiver(_tokenReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        (
            bool _rebateEnabled,
            address _recipient,
            uint256[8] memory prices
        ) = abi.decode(data, (bool, address, uint256[8]));
        rebateEnabled = _rebateEnabled;
        recipient = _recipient;
        price1Letter = prices[0];
        price2Letter = prices[1];
        price3Letter = prices[2];
        price4Letter = prices[3];
        price5Letter = prices[4];
        price6Letter = prices[5];
        price7To11Letter = prices[6];
        price12AndMoreLetter = prices[7];

        emit RebateChanged(_rebateEnabled);
        emit RecipientChanged(_recipient);
        emit StableFeeChanged(
            prices[0],
            prices[1],
            prices[2],
            prices[3],
            prices[4],
            prices[5],
            prices[6],
            prices[7]
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
        _chargeAndRefundOverPayment(cost, params.to, params.msgSender);
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

        if (len >= 12) {
            usdPrice = price12AndMoreLetter;
        } else if (len >= 7) {
            usdPrice = price7To11Letter;
        } else if (len == 6) {
            usdPrice = price6Letter;
        } else if (len == 5) {
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
        address depositTo,
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
        if (rebateEnabled) {
            tokenReceiver.depositTo{ value: cost }(depositTo);
        } else {
            (bool chargeSuccess, ) = recipient.call{ value: cost }("");
            require(chargeSuccess, "CHARGE_FAILED");
        }
    }
}
