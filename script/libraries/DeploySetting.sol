// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address usdOracle;
        address signer;
        address protocolOwner;
        address recipient;
        address tokenReceiver;
    }

    DeployParameters internal deployParams;

    uint256 internal constant BASE_GOERLI = 84531;
    uint256 internal constant MUMBAI = 80001;
    uint256 internal constant OP_GOERLI = 420;
    uint256 internal constant OP = 10;
    uint256 internal constant OP_SEPOLIA = 11155420;
    uint256 internal constant CYBER_TESTNET = 111557560;
    uint256 internal constant CYBER = 7560;

    function _setDeployParams() internal {
        if (block.chainid == BASE_GOERLI) {
            deployParams.deployerContract = address(
                0xF191131dAB798dD6c500816338d4B6EBC34825C7
            );
            deployParams.usdOracle = address(
                0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2
            );
        } else if (block.chainid == MUMBAI) {
            deployParams.deployerContract = address(
                0xF191131dAB798dD6c500816338d4B6EBC34825C7
            );
        } else if (block.chainid == OP_GOERLI) {
            deployParams.deployerContract = address(
                0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
            );
            deployParams.usdOracle = address(
                0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8
            );
            deployParams.signer = address(
                0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F
            );
            deployParams.protocolOwner = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.recipient = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.tokenReceiver = address(
                0xcd97405Fb58e94954E825E46dB192b916A45d412
            );
        } else if (block.chainid == OP_SEPOLIA) {
            deployParams.deployerContract = address(
                0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
            );
            deployParams.usdOracle = address(
                0x61Ec26aA57019C486B10502285c5A3D4A4750AD7
            );
            deployParams.signer = address(
                0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F
            );
            deployParams.protocolOwner = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.recipient = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.tokenReceiver = address(
                0xcd97405Fb58e94954E825E46dB192b916A45d412
            );
        } else if (block.chainid == OP) {
            deployParams.deployerContract = address(
                0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
            );
            deployParams.usdOracle = address(
                0x13e3Ee699D1909E989722E753853AE30b17e08c5
            );
            deployParams.signer = address(
                0x2A2EA826102c067ECE82Bc6E2B7cf38D7EbB1B82
            );
            deployParams.protocolOwner = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.recipient = address(
                0x2f199646760aE75d423F4E98bb5249207ED1DC15
            );
            deployParams.tokenReceiver = address(
                0xcd97405Fb58e94954E825E46dB192b916A45d412
            );
        } else if (block.chainid == CYBER_TESTNET) {
            deployParams.deployerContract = address(
                0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
            );
            deployParams.usdOracle = address(
                0x13e3Ee699D1909E989722E753853AE30b17e08c5
            );
            deployParams.signer = address(
                0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F
            );
            deployParams.protocolOwner = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.recipient = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
        } else if (block.chainid == CYBER) {
            deployParams.deployerContract = address(
                0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
            );
            deployParams.usdOracle = address(
                0x13e3Ee699D1909E989722E753853AE30b17e08c5
            );
            deployParams.signer = address(
                0x2A2EA826102c067ECE82Bc6E2B7cf38D7EbB1B82
            );
            deployParams.protocolOwner = address(
                0x7884f7F04F994da14302a16Cf15E597e31eebECf
            );
            deployParams.recipient = address(
                0x2f199646760aE75d423F4E98bb5249207ED1DC15
            );
        } else {
            revert("PARAMS_NOT_SET");
        }
    }
}
