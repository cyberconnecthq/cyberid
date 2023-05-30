// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/core/MocaId.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract MocaIdTest is Test {
    MocaId public mid;
    address public aliceAddress =
        address(0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D);
    address public bobAddress =
        address(0x5617FEC489c0295C565626e45ed77F2265c283C6);
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 2000 ether;

    event Register(string mocaId, address indexed to, uint256 expiry);
    event Renew(string mocaId, uint256 expiry);

    function setUp() public {
        vm.startPrank(aliceAddress);
        MocaId midImpl = new MocaId();
        ERC1967Proxy proxy = new ERC1967Proxy(address(midImpl), "");
        mid = MocaId(address(proxy));
        mid.initialize("MOCA ID", "MOCAID", aliceAddress);
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
    }

    /* solhint-disable func-name-mixedcase */

    /* solhint-disable func-name-mixedcase */
}
