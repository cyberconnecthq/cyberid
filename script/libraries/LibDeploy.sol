// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Vm.sol";

import { CyberId } from "../../src/core/CyberId.sol";
import { RealmId } from "../../src/core/RealmId.sol";
import { DeploySetting } from "./DeploySetting.sol";
import { LibString } from "../../src/libraries/LibString.sol";
import { Create2Deployer } from "../../src/deployer/Create2Deployer.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PermissionMw } from "../../src/middlewares/realmid/PermissionMw.sol";
import { StableFeeMiddleware } from "../../src/middlewares/cyberid/StableFeeMiddleware.sol";
import { TrustOnlyMiddleware } from "../../src/middlewares/cyberid/TrustOnlyMiddleware.sol";
import { PermissionMiddleware } from "../../src/middlewares/cyberid/PermissionMiddleware.sol";
import { PermissionedStableFeeMiddleware } from "../../src/middlewares/cyberid/PermissionedStableFeeMiddleware.sol";

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
        else if (chainId == 420) chainName = "op_goerli";
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
    ) internal {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        address cyberIdImpl = address(new CyberId());
        _write(vm, "CyberId(Impl)", cyberIdImpl);
        address cyberIdProxy = address(
            dc.deploy(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        cyberIdImpl,
                        abi.encodeWithSelector(
                            CyberId.initialize.selector,
                            "CYBER ID",
                            "CYBERID",
                            params.protocolOwner
                        )
                    )
                ),
                SALT
            )
        );

        _write(vm, "CyberId(Proxy)", cyberIdProxy);

        address stableFeeMw = address(
            dc.deploy(
                abi.encodePacked(
                    type(StableFeeMiddleware).creationCode,
                    abi.encode(params.usdOracle, cyberIdProxy)
                ),
                SALT
            )
        );
        _write(vm, "StableFeeMiddleware", stableFeeMw);

        address permissionedStableFeeMw = address(
            dc.deploy(
                abi.encodePacked(
                    type(PermissionedStableFeeMiddleware).creationCode,
                    abi.encode(
                        params.usdOracle,
                        params.tokenReceiver,
                        cyberIdProxy
                    )
                ),
                SALT
            )
        );
        _write(vm, "PermissionedStableFeeMiddleware", permissionedStableFeeMw);

        CyberId(cyberIdProxy).grantRole(
            keccak256(bytes("OPERATOR_ROLE")),
            params.protocolOwner
        );
        CyberId(cyberIdProxy).setMiddleware(
            permissionedStableFeeMw,
            abi.encode(
                true,
                params.signer,
                params.recipient,
                [
                    uint256(10000 ether),
                    2000 ether,
                    1000 ether,
                    500 ether,
                    100 ether,
                    50 ether,
                    10 ether,
                    5 ether
                ]
            )
        );
        CyberId(cyberIdProxy).grantRole(
            keccak256(bytes("OPERATOR_ROLE")),
            params.signer
        );
    }

    function deployRealmId(
        Vm vm,
        DeploySetting.DeployParameters memory params
    ) internal {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        address realmIdImpl = address(new RealmId());

        _write(vm, "RealmId(Impl)", realmIdImpl);

        address realmIdProxy = dc.deploy(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    realmIdImpl,
                    abi.encodeWithSelector(
                        RealmId.initialize.selector,
                        "Realm ID",
                        "RID",
                        msg.sender
                    )
                )
            ),
            SALT
        );

        _write(vm, "RealmId(Proxy)", realmIdProxy);

        address permissionMw = address(new PermissionMw(realmIdProxy));

        RealmId(realmIdProxy).allowNode(
            "moca",
            bytes32(0),
            true,
            "",
            permissionMw,
            abi.encode(msg.sender)
        );

        _write(vm, "PermissionMw", permissionMw);
    }
}
