// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/CyberId.sol";
import { MockUsdOracle } from "./utils/MockUsdOracle.sol";

contract CyberIdTest is Test {
    CyberId public cid;

    function setUp() public {
        MockUsdOracle usdOracle = new MockUsdOracle();
        cid = new CyberId("CYBER ID", "CYBERID", address(usdOracle));
    }
}
