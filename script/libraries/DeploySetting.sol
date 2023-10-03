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
                0xF191131dAB798dD6c500816338d4B6EBC34825C7
            );
            deployParams.usdOracle = address(
                0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8
            );
            deployParams.signer = address(
                0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F
            );
            deployParams.protocolOwner = address(
                0x7B23B874cD857C5968434F95674165a36CfD5E4e
            );
            deployParams.recipient = address(
                0x7B23B874cD857C5968434F95674165a36CfD5E4e
            );
            deployParams.tokenReceiver = address(
                0x52B90f8e69aC72fE0F46726eADDA13835Cbb01FA
            );
        } else {
            revert("PARAMS_NOT_SET");
        }
    }
}
