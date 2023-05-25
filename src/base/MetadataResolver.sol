// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

abstract contract MetadataResolver {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint64 => mapping(uint256 => mapping(string => string))) _metadatas;
    mapping(uint256 => uint64) public metadataVersions;

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
        metadataVersions[tokenId]++;
        emit MetadataVersionChanged(tokenId, metadataVersions[tokenId]);
    }

    /**
     * @notice Sets the metadata associated with an token and key.
     * May only be called by the owner of that node.
     * @param tokenId The token to update.
     * @param key The key to set.
     * @param value The metadata value to set.
     */
    function setMetadata(
        uint256 tokenId,
        string calldata key,
        string calldata value
    ) external authorised(tokenId) {
        _metadatas[metadataVersions[tokenId]][tokenId][key] = value;
        emit MetadataChanged(tokenId, key, value);
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
}
