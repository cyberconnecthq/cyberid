// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ITokenReceiver } from "../../src/interfaces/ITokenReceiver.sol";

contract MockTokenReceiver is ITokenReceiver {
    uint256 public totalDeposit;

    function depositTo(address) external payable override {
        totalDeposit += msg.value;
    }

    function withdraw(address to, uint256 amount) external override {
        payable(to).transfer(amount);
    }
}
