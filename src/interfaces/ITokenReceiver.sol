// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

/**
 * @title TokenReceiver
 * @author CyberConnect
 * @notice A contract that receive native token and record the amount.
 * The deposit only record the cumulative amount and withdraw won't affect
 * the deposit value.
 */
interface ITokenReceiver {
    function depositTo(address to) external payable;

    function withdraw(address to, uint256 amount) external;
}
