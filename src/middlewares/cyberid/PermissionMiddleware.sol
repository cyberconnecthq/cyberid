// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ICyberIdMiddleware } from "../../interfaces/ICyberIdMiddleware.sol";

import { DataTypes } from "../../libraries/DataTypes.sol";

import { LowerCaseCyberIdMiddleware } from "./base/LowerCaseCyberIdMiddleware.sol";
import { EIP712 } from "../../base/EIP712.sol";

contract PermissionMiddleware is LowerCaseCyberIdMiddleware, EIP712 {
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

    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string cid,address to,uint256 nonce,uint256 deadline)"
        );

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SignerChanged(address indexed signer);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address cyberId) LowerCaseCyberIdMiddleware(cyberId) {}

    /*//////////////////////////////////////////////////////////////
                    ICyberIdMiddleware OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICyberIdMiddleware
    function setMwData(bytes calldata data) external override onlyNameRegistry {
        address newSigner = abi.decode(data, (address));
        require(newSigner != address(0), "INVALID_SIGNER");
        signer = newSigner;
        emit SignerChanged(signer);
    }

    /// @inheritdoc ICyberIdMiddleware
    function preRegister(
        DataTypes.RegisterCyberIdParams calldata params,
        bytes calldata data
    ) external payable override onlyNameRegistry returns (uint256) {
        require(msg.value == 0, "NO_VALUE_REQUIRED");
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
                        keccak256(bytes(params.cid)),
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
        return 0;
    }

    /// @inheritdoc ICyberIdMiddleware
    function skipCommit() external pure virtual override returns (bool) {
        return true;
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
        return "PermissionMw";
    }
}
