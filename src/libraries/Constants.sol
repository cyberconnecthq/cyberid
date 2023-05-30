// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

library Constants {
    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string name,address to,uint256 nonce,uint256 deadline)"
        );
}
