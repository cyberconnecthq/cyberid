// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { Ownable2StepUpgradeable } from "openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IMiddleware } from "../interfaces/IMiddleware.sol";
import { MetadataResolver } from "../base/MetadataResolver.sol";
import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

contract MocaId is
    Initializable,
    ERC721Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    MetadataResolver
{
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Token URI prefix.
     */
    string public baseTokenUri;

    /**
     * @notice Middleware contract that processes before and after the registration.
     */
    address internal _middleware;

    /**
     * @dev Added to allow future versions to add new variables in case this contract becomes
     *      inherited. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a mocaId is registered.
     *
     * @param mocaId  The mocaId
     * @param tokenId The tokenId of the mocaId
     * @param to      The address that owns the mocaId
     */
    event Register(string mocaId, uint256 tokenId, address indexed to);

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTORS AND INITIALIZERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Disable initialization to protect the contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize default storage values and inherited contracts. This should be called
     *         once after the contract is deployed via the ERC1967 proxy.
     *
     * @param _tokenName   The ERC-721 name of the fname token
     * @param _tokenSymbol The ERC-721 symbol of the fname token
     */
    function initialize(
        string calldata _tokenName,
        string calldata _tokenSymbol
    ) external initializer {
        /* Initialize inherited contracts */
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a mocaId is available for registration.
     *
     * @param mocaId The mocaId to register
     */
    function available(string calldata mocaId) public view returns (bool) {
        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        bool patternValid = true;
        if (_middleware != address(0)) {
            patternValid = IMiddleware(_middleware).namePatternValid(mocaId);
        }
        return patternValid && !super._exists(tokenId);
    }

    /**
     * @notice Mints a new mocaId.
     *
     * @param mocaId    The mocaId to register
     * @param to        The address that will own the mocaId
     * @param preData   The register data for preprocess.
     * @param postData  The register data for postprocess.
     */
    function register(
        string calldata mocaId,
        address to,
        bytes calldata preData,
        bytes calldata postData
    ) external {
        if (_middleware != address(0)) {
            IMiddleware(_middleware).preProcess(
                DataTypes.RegisterNameParams(mocaId, to),
                preData
            );
        }

        _register(mocaId, to);

        if (_middleware != address(0)) {
            IMiddleware(_middleware).postProcess(
                DataTypes.RegisterNameParams(mocaId, to),
                postData
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _transfer(address, address, uint256) internal pure override {
        revert("TRANSFER_NOT_ALLOWED");
    }

    /**
     * @notice Return a distinct URI for a tokenId
     *
     * @param tokenId The uint256 tokenId of the mocaId
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(baseTokenUri, tokenId.toHexString(), ".json")
            );
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC VIEW
    //////////////////////////////////////////////////////////////*/

    function getTokenId(
        string calldata mocaId
    ) external pure returns (uint256) {
        return uint256(keccak256(bytes(mocaId)));
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER ONLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the base token uri.
     */
    function setBaseTokenUri(string calldata uri) external onlyOwner {
        baseTokenUri = uri;
    }

    /**
     * @notice Set the middleware and data.
     */
    function setMiddleware(
        address middleware,
        bytes calldata data
    ) external onlyOwner {
        _middleware = middleware;
        if (_middleware != address(0)) {
            IMiddleware(_middleware).setMwData(data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal view override onlyOwner {}

    function _register(string calldata mocaId, address to) internal {
        require(available(mocaId), "INVALID_NAME");

        /**
         * Mints the token by calling the ERC-721 _safeMint() function.
         * The _safeMint() function ensures that the to address isnt 0
         * and that the tokenId is not already minted.
         */
        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        super._safeMint(to, tokenId);

        emit Register(mocaId, tokenId, to);
    }

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        return super._isApprovedOrOwner(msg.sender, tokenId);
    }
}
