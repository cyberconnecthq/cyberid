// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { IERC721Receiver } from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract MockWallet is IERC721Receiver {
    receive() external payable {
        revert("REFUSE");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
