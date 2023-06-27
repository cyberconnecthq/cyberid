// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ICyberIdMiddleware } from "../../../interfaces/ICyberIdMiddleware.sol";

abstract contract LowerCaseCyberIdMiddleware is ICyberIdMiddleware {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable NAME_REGISTRY; // solhint-disable-line

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address nameRegistry) {
        NAME_REGISTRY = nameRegistry;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Reverts if called by any account other than the name registry.
     */
    modifier onlyNameRegistry() {
        require(NAME_REGISTRY == msg.sender, "NOT_NAME_REGISTRY");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function skipCommit() external pure virtual override returns (bool) {
        return false;
    }

    /// @inheritdoc ICyberIdMiddleware
    function namePatternValid(
        string calldata name
    ) external pure virtual override returns (bool) {
        bytes memory byteName = bytes(name);

        if (byteName.length > 20 || byteName.length < 3) {
            return false;
        }

        uint256 byteNameLength = byteName.length;
        for (uint256 i = 0; i < byteNameLength; ) {
            bytes1 b = byteName[i];
            if ((b >= "0" && b <= "9") || (b >= "a" && b <= "z") || b == "_") {
                unchecked {
                    ++i;
                }
            } else {
                return false;
            }
        }
        return true;
    }
}
