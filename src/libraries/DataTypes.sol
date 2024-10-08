// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

library DataTypes {
    struct EIP712Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    struct MetadataPair {
        string key;
        string value;
    }

    struct RegisterNameParams {
        address msgSender;
        string name;
        bytes32 parentNode;
        address to;
    }

    struct RegisterCyberIdParams {
        address msgSender;
        string[] cids;
        address to;
    }

    struct BatchRegisterCyberIdParams {
        string cid;
        address to;
        bool setReverse;
    }
}
