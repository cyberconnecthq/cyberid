// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { MocaIdTestBase } from "../utils/MocaIdTestBase.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract MocaIdTest is MocaIdTestBase {
    /* solhint-disable func-name-mixedcase */
    function test_MiddlewareNotSet_CheckNameAvailable_Available() public {
        assertTrue(mid.available(unicode"alice"));
        assertTrue(mid.available(unicode"bob"));
        assertTrue(mid.available(unicode"bobb"));
        assertTrue(mid.available(unicode"三个字"));
        assertTrue(mid.available(unicode"四个字儿"));
        assertTrue(mid.available(unicode"😋😋😋"));
        assertTrue(mid.available(unicode"😋😋😋😋"));
        assertTrue(mid.available(unicode"    "));
        assertTrue(mid.available(unicode""));
        assertTrue(mid.available(unicode"bo"));
        assertTrue(mid.available(unicode"二字"));
        assertTrue(mid.available(unicode"😋😋"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200b"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200c"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200d"));
        assertTrue(mid.available("zerowidthcharacter\ufefe\ufeff"));
    }

    /* solhint-disable func-name-mixedcase */
}
