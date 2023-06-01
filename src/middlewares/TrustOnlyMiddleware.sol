// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ICyberIdMiddleware } from "../interfaces/ICyberIdMiddleware.sol";
import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

contract TrustOnlyMiddleware is LowerCaseCyberIdMiddleware {
    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override {}

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata,
        bytes calldata
    ) external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRenew(
        DataTypes.RenewCyberIdParams calldata,
        bytes calldata
    ) external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preBid(
        DataTypes.BidCyberIdParams calldata,
        bytes calldata
    ) external pure override returns (uint256) {
        return 0;
    }
}
