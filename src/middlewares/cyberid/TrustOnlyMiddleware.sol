// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";

import { DataTypes } from "../../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";

contract TrustOnlyMiddleware is Ownable, LowerCaseCyberIdMiddleware {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address cyberId) LowerCaseCyberIdMiddleware(cyberId) {}

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function skipCommit() external pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        address _owner = abi.decode(data, (address));
        _transferOwnership(_owner);
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata
    ) external payable override returns (uint256) {
        require(params.msgSender == owner(), "NOT_TRUSTED_CALLER");
        return 0;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRenew(
        DataTypes.RenewCyberIdParams calldata params,
        bytes calldata
    ) external payable override returns (uint256) {
        require(params.msgSender == owner(), "NOT_TRUSTED_CALLER");
        return 0;
    }

    /// @inheritdoc ICyberIdMiddleware
    function preBid(
        DataTypes.BidCyberIdParams calldata params,
        bytes calldata
    ) external payable override returns (uint256) {
        require(params.msgSender == owner(), "NOT_TRUSTED_CALLER");
        return 0;
    }

    /// @inheritdoc Ownable
    function renounceOwnership() public view override onlyOwner {
        revert("NOT_ALLOWED");
    }

    /// @inheritdoc Ownable
    function transferOwnership(address) public view override onlyOwner {
        revert("NOT_ALLOWED");
    }
}
