// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Vm.sol";

import { CyberId } from "../../src/core/CyberId.sol";
import { RealmId } from "../../src/core/RealmId.sol";
import { DeploySetting } from "./DeploySetting.sol";
import { LibString } from "../../src/libraries/LibString.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Create2Deployer } from "../../src/deployer/Create2Deployer.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PermissionMw } from "../../src/middlewares/realmid/PermissionMw.sol";
import { StableFeeMiddleware } from "../../src/middlewares/cyberid/StableFeeMiddleware.sol";
import { TrustOnlyMiddleware } from "../../src/middlewares/cyberid/TrustOnlyMiddleware.sol";
import { PermissionedStableFeeMiddleware } from "../../src/middlewares/cyberid/PermissionedStableFeeMiddleware.sol";
import { CyberIdRegistry } from "../../src/core/CyberIdRegistry.sol";
import { CyberIdPublicResolver } from "../../src/core/CyberIdPublicResolver.sol";
import { CyberIdReverseRegistrar } from "../../src/core/CyberIdReverseRegistrar.sol";

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
        else if (chainId == 10) chainName = "op";
        else if (chainId == 11155420) chainName = "op_sepolia";
        else if (chainId == 111557560) chainName = "cyber_testnet";
        else if (chainId == 7560) chainName = "cyber";
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

    function setCyberIDInitState(
        DeploySetting.DeployParameters memory params,
        address cyberIdProxy,
        address cyberIdRegistry,
        address cyberIdPublicResolver,
        address cyberIdReverseRegistrar
    ) internal {
        CyberId(cyberIdProxy).grantRole(
            keccak256(bytes("OPERATOR_ROLE")),
            params.protocolOwner
        );
        CyberId(cyberIdProxy).grantRole(
            keccak256(bytes("OPERATOR_ROLE")),
            params.signer
        );
        CyberIdReverseRegistrar(cyberIdReverseRegistrar).setDefaultResolver(
            address(cyberIdPublicResolver)
        );
        CyberIdRegistry(cyberIdRegistry).setSubnodeOwner(
            bytes32(0),
            keccak256(bytes("cyber")),
            cyberIdProxy
        );
        bytes32 reverseNode = CyberIdRegistry(cyberIdRegistry).setSubnodeOwner(
            bytes32(0),
            keccak256(bytes("reverse")),
            params.protocolOwner
        );
        bytes32 addrReverseNode = CyberIdRegistry(cyberIdRegistry)
            .setSubnodeOwner(
                reverseNode,
                keccak256(bytes("addr")),
                cyberIdReverseRegistrar
            );
        require(
            addrReverseNode ==
                bytes32(
                    0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2
                ),
            "WRONG_ADDR_REVERSE_NODE"
        );
        CyberIdPublicResolver(cyberIdPublicResolver).setTrustedCyberIdRegistrar(
            cyberIdProxy
        );
        CyberIdPublicResolver(cyberIdPublicResolver).setTrustedReverseRegistrar(
            cyberIdReverseRegistrar
        );
        CyberIdReverseRegistrar(cyberIdReverseRegistrar).setController(
            cyberIdProxy,
            true
        );
    }

    function deployCyberIdPermissionedStableMw(
        Vm vm,
        DeploySetting.DeployParameters memory params,
        address cyberIdProxy
    ) internal returns (address) {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        address permissionedStableFeeMw = address(
            dc.deploy(
                abi.encodePacked(
                    type(PermissionedStableFeeMiddleware).creationCode,
                    abi.encode(params.usdOracle, cyberIdProxy)
                ),
                SALT
            )
        );
        _write(vm, "PermissionedStableFeeMiddleware", permissionedStableFeeMw);
        return permissionedStableFeeMw;
    }

    function deployCyberIdStableMw(
        Vm vm,
        DeploySetting.DeployParameters memory params,
        address cyberIdProxy
    ) internal returns (address) {
        Create2Deployer dc = Create2Deployer(params.deployerContract);
        address stableFeeMw = address(
            dc.deploy(
                abi.encodePacked(
                    type(StableFeeMiddleware).creationCode,
                    abi.encode(
                        params.usdOracle,
                        params.tokenReceiver,
                        cyberIdProxy
                    )
                ),
                SALT
            )
        );
        _write(vm, "StableFeeMiddleware", stableFeeMw);
        return stableFeeMw;
    }

    function deployCyberId(
        Vm vm,
        DeploySetting.DeployParameters memory params
    ) internal {
        Create2Deployer dc = Create2Deployer(params.deployerContract);

        address cyberIdRegistry = dc.deploy(
            abi.encodePacked(
                type(CyberIdRegistry).creationCode,
                abi.encode(params.protocolOwner)
            ),
            SALT
        );
        _write(vm, "CyberIdRegistry", cyberIdRegistry);

        address cyberIdPublicResolver = dc.deploy(
            abi.encodePacked(
                type(CyberIdPublicResolver).creationCode,
                abi.encode(cyberIdRegistry, params.protocolOwner)
            ),
            SALT
        );
        _write(vm, "CyberIdPublicResolver", cyberIdPublicResolver);

        address cyberIdReverseRegistrar = dc.deploy(
            abi.encodePacked(
                type(CyberIdReverseRegistrar).creationCode,
                abi.encode(cyberIdRegistry, params.protocolOwner)
            ),
            SALT
        );
        _write(vm, "CyberIdReverseRegistrar", cyberIdReverseRegistrar);

        address cyberIdImpl = address(new CyberId());
        _write(vm, "CyberId(Impl)", cyberIdImpl);
        address cyberIdProxy = dc.deploy(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    cyberIdImpl,
                    abi.encodeWithSelector(
                        CyberId.initialize.selector,
                        cyberIdRegistry,
                        cyberIdPublicResolver,
                        cyberIdReverseRegistrar,
                        "CyberID",
                        "CYBERID",
                        params.protocolOwner
                    )
                )
            ),
            SALT
        );

        _write(vm, "CyberId(Proxy)", cyberIdProxy);

        setCyberIDInitState(
            params,
            cyberIdProxy,
            cyberIdRegistry,
            cyberIdPublicResolver,
            cyberIdReverseRegistrar
        );

        address stableFeeMw = deployCyberIdPermissionedStableMw(
            vm,
            params,
            cyberIdProxy
        );

        CyberId(cyberIdProxy).setMiddleware(
            stableFeeMw,
            abi.encode(
                params.signer,
                params.recipient,
                [uint256(100 ether), 40 ether, 10 ether, 4 ether]
            )
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
