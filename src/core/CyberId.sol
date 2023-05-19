// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { CyberNFTBase } from "../base/CyberNFTBase.sol";

contract CyberId is CyberNFTBase {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name,
        string memory symbol
    ) CyberNFTBase(name, symbol) {}

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates the metadata json object.
     *
     * @param tokenId The profile NFT token ID.
     * @return string The metadata json object.
     * @dev It requires the tokenId to be already minted.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        // TODO: tokenURI
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _mint(address to) internal override returns (uint256) {
        return super._mint(to);
    }
}
