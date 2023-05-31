// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { IMiddleware } from "../../src/interfaces/IMiddleware.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";

contract MockMiddleware is IMiddleware {
    bytes public mwData;

    function setMwData(bytes calldata data) external override {
        mwData = data;
    }

    function preProcess(
        DataTypes.RegisterNameParams calldata params,
        bytes calldata data
    ) external payable override {}

    function namePatternValid(
        string calldata
    ) external pure override returns (bool) {
        return true;
    }
}
