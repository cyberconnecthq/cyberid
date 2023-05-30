// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { DataTypes } from "../libraries/DataTypes.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

abstract contract MetadataResolver is Initializable {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint64 => mapping(uint256 => mapping(string => string))) _metadatas;
    mapping(uint256 => uint64) public metadataVersions;

    /**
     * @dev Added to allow future versions to add new variables in case this contract becomes
     *      inherited. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event MetadataVersionChanged(uint256 indexed tokenId, uint64 newVersion);

    event MetadataChanged(uint256 indexed tokenId, string key, string value);

    /*//////////////////////////////////////////////////////////////
                            MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier authorised(uint256 tokenId) {
        require(_isMetadataAuthorised(tokenId), "METADATA_UNAUTHORISED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Clears all metadata on a token.
     * @param   tokenId  token to clear metadata.
     */
    function clearMetadatas(
        uint256 tokenId
    ) public virtual authorised(tokenId) {
        _clearMetadatas(tokenId);
    }

    /**
     * @notice Sets the metadatas associated with an token and keys.
     * Only can be called by the owner or approved operators of that node.
     * @param tokenId The token to update.
     * @param pairs The kv pairs to set.
     */
    function batchSetMetadatas(
        uint256 tokenId,
        DataTypes.MetadataPair[] calldata pairs
    ) external authorised(tokenId) {
        for (uint256 i = 0; i < pairs.length; i++) {
            DataTypes.MetadataPair memory pair = pairs[i];
            _metadatas[metadataVersions[tokenId]][tokenId][pair.key] = pair
                .value;
            emit MetadataChanged(tokenId, pair.key, pair.value);
        }
    }

    /**
     * @notice Returns the metadata associated with an token and key.
     * @param tokenId The token to query.
     * @param key The metadata key to query.
     * @return The associated metadata.
     */
    function getMetadata(
        uint256 tokenId,
        string calldata key
    ) external view returns (string memory) {
        return _metadatas[metadataVersions[tokenId]][tokenId][key];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view virtual returns (bool);

    /**
     * @notice  Clears all metadata on a token.
     * @param   tokenId  token to clear metadata.
     */
    function _clearMetadatas(uint256 tokenId) internal virtual {
        metadataVersions[tokenId]++;
        emit MetadataVersionChanged(tokenId, metadataVersions[tokenId]);
    }
}
