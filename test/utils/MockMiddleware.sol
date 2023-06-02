// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { IMiddleware } from "../../src/interfaces/IMiddleware.sol";
import { ICyberIdMiddleware } from "../../src/interfaces/ICyberIdMiddleware.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";

contract MockMiddleware is IMiddleware, ICyberIdMiddleware {
    bytes public mwData;

    function setMwData(
        bytes calldata data
    ) external override(IMiddleware, ICyberIdMiddleware) {
        mwData = data;
    }

    function preProcess(
        DataTypes.RegisterNameParams calldata,
        bytes calldata
    ) external payable override {}

    function preRegister(
        DataTypes.RegisterCyberIdParams calldata,
        bytes calldata
    ) external payable override returns (uint256) {
        return 0;
    }

    function preRenew(
        DataTypes.RenewCyberIdParams calldata,
        bytes calldata
    ) external payable override returns (uint256) {
        return 0;
    }

    function preBid(
        DataTypes.BidCyberIdParams calldata,
        bytes calldata
    ) external payable override returns (uint256) {
        return 0;
    }

    function namePatternValid(
        string calldata
    ) external pure override(IMiddleware, ICyberIdMiddleware) returns (bool) {
        return true;
    }
}
