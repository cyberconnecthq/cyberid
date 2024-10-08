// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { DataTypes } from "../libraries/DataTypes.sol";

interface ICyberIdMiddleware {
    /**
     * @notice Sets data for middleware.
     *
     * @param data Extra data to set.
     */
    function setMwData(bytes calldata data) external;

    /**
     * @notice Process that runs before the register happens.
     *
     * @param params The params for register cid.
     * @param data Extra data to process.
     */
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata data
    ) external payable returns (uint256);

    /**
     * @notice Validates the name pattern.
     *
     * @param name The name to validate.
     */
    function namePatternValid(
        string calldata name
    ) external view returns (bool);
}
