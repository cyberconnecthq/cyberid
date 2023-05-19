// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Vm.sol";

import { CyberId } from "../../src/core/CyberId.sol";
import { DeploySetting } from "./DeploySetting.sol";
import { LibString } from "../../src/libraries/LibString.sol";
import { Create2Deployer } from "../../src/deployer/Create2Deployer.sol";

library LibDeploy {
    // create2 deploy all contract with this protocol salt
    bytes32 constant SALT = keccak256(bytes("CyberId2"));

    string internal constant OUTPUT_FILE = "docs/deploy/";

    function _fileName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        string memory chainName;
        if (chainId == 1) chainName = "mainnet";
        else if (chainId == 84531) chainName = "base_goerli";
        else chainName = "unknown";
        return
            string(
                abi.encodePacked(
                    OUTPUT_FILE,
                    string(
                        abi.encodePacked(
                            chainName,
                            "-",
                            LibString.toString(chainId)
                        )
                    ),
                    "/contract"
                )
            );
    }

    function _fileNameMd() internal view returns (string memory) {
        return string(abi.encodePacked(_fileName(), ".md"));
    }

    function _writeText(
        Vm vm,
        string memory fileName,
        string memory text
    ) internal {
        vm.writeLine(fileName, text);
    }

    function _writeHelper(Vm vm, string memory name, address addr) internal {
        _writeText(
            vm,
            _fileNameMd(),
            string(
                abi.encodePacked(
                    "|",
                    name,
                    "|",
                    LibString.toHexString(addr),
                    "|"
                )
            )
        );
    }

    function _write(Vm vm, string memory name, address addr) internal {
        _writeHelper(vm, name, addr);
    }

    function deployCyberId(
        Vm vm,
        DeploySetting.DeployParameters memory params
    ) internal returns (address cyberId) {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        cyberId = dc.deploy(
            abi.encodePacked(
                type(CyberId).creationCode,
                abi.encode("CYBER ID", "CYBERID")
            ),
            SALT
        );

        _write(vm, "CyberId", cyberId);
    }
}
