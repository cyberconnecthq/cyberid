// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { AggregatorV3Interface } from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";

import { DataTypes } from "../../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";
import { EIP712 } from "../../base/EIP712.sol";

contract PermissionedStableFeeMiddleware is
    LowerCaseCyberIdMiddleware,
    EIP712,
    ReentrancyGuard
{
    enum FeeType {
        NORMAL,
        DISCOUNT,
        FREE
    }

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

    /**
     * @notice The price of each letter in USD.
     */
    uint256 public price3Letter;
    uint256 public price4Letter;
    uint256 public price5To9Letter;
    uint256 public price10AndMoreLetter;

    /**
     * @notice Signer that approve meta transactions.
     */
    address public signer;

    /**
     * @notice User nonces that prevents signature replay.
     */
    mapping(address => mapping(FeeType => uint256)) public nonces;

    bytes32 public constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string[] cids,address to,uint8 feeType,uint256 discount,uint256 nonce,uint256 deadline)"
        );

    uint256 internal constant BASE = 1000;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SignerChanged(address indexed signer);

    event StableFeeChanged(
        address indexed recipient,
        uint256 price3Letter,
        uint256 price4Letter,
        uint256 price5To9Letter,
        uint256 price10AndMoreLetter
    );

    event SigUsed(
        address indexed account,
        FeeType feeType,
        uint256 nonce,
        string[] cids
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _oracleAddress,
        address _cyberId,
        address _owner
    ) LowerCaseCyberIdMiddleware(_cyberId, _owner) {
        usdOracle = AggregatorV3Interface(_oracleAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        (address newSigner, address _recipient, uint256[4] memory prices) = abi
            .decode(data, (address, address, uint256[4]));
        require(newSigner != address(0), "INVALID_SIGNER");
        signer = newSigner;
        emit SignerChanged(signer);
        recipient = _recipient;

        price3Letter = prices[0];
        price4Letter = prices[1];
        price5To9Letter = prices[2];
        price10AndMoreLetter = prices[3];

        emit StableFeeChanged(
            _recipient,
            prices[0],
            prices[1],
            prices[2],
            prices[3]
        );
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata data
    ) external payable override onlyNameRegistry returns (uint256) {
        DataTypes.EIP712Signature memory sig;
        uint256 discount;
        FeeType feeType;
        (feeType, discount, sig.v, sig.r, sig.s, sig.deadline) = abi.decode(
            data,
            (FeeType, uint256, uint8, bytes32, bytes32, uint256)
        );

        uint256 currentNonce = nonces[params.to][feeType]++;
        _requiresExpectedSigner(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _REGISTER_TYPEHASH,
                        _encodeCids(params.cids),
                        params.to,
                        feeType,
                        discount,
                        currentNonce,
                        sig.deadline
                    )
                )
            ),
            signer,
            sig.v,
            sig.r,
            sig.s,
            sig.deadline
        );
        emit SigUsed(params.to, feeType, currentNonce, params.cids);
        uint256 cost = 0;
        if (discount > 0) {
            for (uint256 i = 0; i < params.cids.length; i++) {
                cost += getPriceWei(params.cids[i]);
            }
            cost = (cost * discount) / BASE;
        }

        _chargeAndRefundOverPayment(cost, params.msgSender);
        return cost;
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

        if (len >= 10) {
            usdPrice = price10AndMoreLetter;
        } else if (len >= 5) {
            usdPrice = price5To9Letter;
        } else if (len == 4) {
            usdPrice = price4Letter;
        } else if (len == 3) {
            usdPrice = price3Letter;
        } else {
            revert("INVALID_LENGTH");
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
        if (cost > 0) {
            (bool chargeSuccess, ) = recipient.call{ value: cost }("");
            require(chargeSuccess, "CHARGE_FAILED");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    EIP712 OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function _domainSeparatorName()
        internal
        pure
        override
        returns (string memory)
    {
        return "PermissionedStableFeeMw";
    }

    /*//////////////////////////////////////////////////////////////
                    PRIVATE
    //////////////////////////////////////////////////////////////*/
    function _encodeCids(string[] memory cids) internal pure returns (bytes32) {
        bytes32[] memory cidHashes = new bytes32[](cids.length);

        for (uint256 i = 0; i < cids.length; i++) {
            cidHashes[i] = keccak256(bytes(cids[i]));
        }

        return keccak256(abi.encodePacked(cidHashes));
    }
}
