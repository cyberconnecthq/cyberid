// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { IMiddleware } from "../interfaces/IMiddleware.sol";
import { DataTypes } from "../libraries/DataTypes.sol";
import { EIP712 } from "../base/EIP712.sol";

contract PermissionMw is IMiddleware, EIP712 {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Signer that approve meta transactions.
     */
    address public signer;

    /**
     * @notice User nonces that prevents signature replay.
     */
    mapping(address => uint256) public nonces;

    address public immutable NAME_REGISTRY; // solhint-disable-line

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string name,address to,uint256 nonce,uint256 deadline)"
        );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address nameRegistry) {
        require(nameRegistry != address(0), "ZERO_ADDRESS");
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
                        IMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        signer = abi.decode(data, (address));
    }

    /// @inheritdoc IMiddleware
    function preProcess(
        DataTypes.RegisterNameParams calldata params,
        bytes calldata data
    ) external payable override onlyNameRegistry {
        DataTypes.EIP712Signature memory sig;

        (sig.v, sig.r, sig.s, sig.deadline) = abi.decode(
            data,
            (uint8, bytes32, bytes32, uint256)
        );

        _requiresExpectedSigner(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _REGISTER_TYPEHASH,
                        params.name,
                        params.to,
                        nonces[params.to]++,
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
    }

    /// @inheritdoc IMiddleware
    function postProcess(
        DataTypes.RegisterNameParams calldata,
        bytes calldata
    ) external override onlyNameRegistry {}

    /// @inheritdoc IMiddleware
    function namePatternValid(
        string calldata name
    ) external pure returns (bool) {
        bytes memory byteName = bytes(name);

        if (byteName.length > 20 || byteName.length == 0) {
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

    function _domainSeparatorName()
        internal
        pure
        override
        returns (string memory)
    {
        return "PermissionMw";
    }
}
