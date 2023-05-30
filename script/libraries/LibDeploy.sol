// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Vm.sol";

import { CyberId } from "../../src/core/CyberId.sol";
import { MocaId } from "../../src/core/MocaId.sol";
import { DeploySetting } from "./DeploySetting.sol";
import { LibString } from "../../src/libraries/LibString.sol";
import { Create2Deployer } from "../../src/deployer/Create2Deployer.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PermissionMw } from "../../src/middlewares/PermissionMw.sol";

library LibDeploy {
    // create2 deploy all contract with this protocol salt
    bytes32 constant SALT = keccak256(bytes("CyberId"));

    string internal constant OUTPUT_FILE = "docs/deploy/";

    function _fileName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        string memory chainName;
        if (chainId == 1) chainName = "mainnet";
        else if (chainId == 84531) chainName = "base_goerli";
        else if (chainId == 80001) chainName = "mumbai";
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
                abi.encode("CYBER ID", "CYBERID", params.usdOracle)
            ),
            SALT
        );

        _write(vm, "CyberId", cyberId);
    }

    function deployMocaId(
        Vm vm,
        DeploySetting.DeployParameters memory params
    ) internal {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        address mocaIdImpl = address(new MocaId());

        _write(vm, "MocaId(Impl)", mocaIdImpl);

        address mocaIdProxy = dc.deploy(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(mocaIdImpl, "")
            ),
            SALT
        );

        MocaId(mocaIdProxy).initialize("MOCA ID", "MOCAID", msg.sender);

        _write(vm, "MocaId(Proxy)", mocaIdProxy);

        address permissionMw = address(new PermissionMw(mocaIdProxy));

        MocaId(mocaIdProxy).setMiddleware(permissionMw, abi.encode(msg.sender));

        _write(vm, "PermissionMw", permissionMw);
    }
}
