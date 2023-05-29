// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { Ownable2StepUpgradeable } from "openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { MetadataResolver } from "../base/MetadataResolver.sol";
import { EIP712 } from "../base/EIP712.sol";
import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

contract MocaId is
    Initializable,
    ERC721Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    MetadataResolver,
    EIP712
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
     * @notice User nonces that prevents signature replay.
     */
    mapping(address => uint256) public nonces;

    /**
     * @notice Signer that approve meta transactions.
     */
    address internal _signer;

    /**
     * @dev Added to allow future versions to add new variables in case this contract becomes
     *      inherited. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string mocaId,address to,uint256 nonce,uint256 deadline)"
        );

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
                            MODIFIER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Reverts if called by any account other than the signer.
     */
    modifier onlySigner() {
        require(_signer == _msgSender(), "NOT_SIGNER");
        _;
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
        return _valid(mocaId) && !super._exists(tokenId);
    }

    /**
     * @notice Mints a new mocaId.
     *
     * @param mocaId    The mocaId to register
     * @param to        The address that will own the mocaId
     * @param signature The signature signed by signer
     */
    function register(
        string calldata mocaId,
        address to,
        bytes calldata signature
    ) external {
        DataTypes.EIP712Signature memory sig;

        (sig.v, sig.r, sig.s, sig.deadline) = abi.decode(
            signature,
            (uint8, bytes32, bytes32, uint256)
        );

        _requiresExpectedSigner(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _REGISTER_TYPEHASH,
                        mocaId,
                        to,
                        nonces[to]++,
                        sig.deadline
                    )
                )
            ),
            _signer,
            sig.v,
            sig.r,
            sig.s,
            sig.deadline
        );

        _register(mocaId, to);
    }

    /**
     * @notice Mints a new mocaId by trusted caller.
     *
     * @param mocaId   The mocaId to register
     * @param to       The address that will own the mocaId
     */
    function trustedRegister(
        string calldata mocaId,
        address to
    ) external onlySigner {
        _register(mocaId, to);
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
     * @notice Set the signer.
     */
    function setSigner(address signer) external onlyOwner {
        _signer = signer;
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

    function _domainSeparatorName()
        internal
        pure
        override
        returns (string memory)
    {
        return "MocaId";
    }

    function _isMetadataAuthorised(
        uint256 tokenId
    ) internal view override returns (bool) {
        return super._isApprovedOrOwner(msg.sender, tokenId);
    }

    function _valid(string calldata mocaId) internal pure returns (bool) {
        // check unicode rune count, if rune count is >=3, byte length must be >=3.
        if (mocaId.strlen() < 3) {
            return false;
        }
        bytes memory nb = bytes(mocaId);
        // zero width for /u200b /u200c /u200d and U+FEFF
        for (uint256 i; i < nb.length - 2; i++) {
            if (bytes1(nb[i]) == 0xe2 && bytes1(nb[i + 1]) == 0x80) {
                if (
                    bytes1(nb[i + 2]) == 0x8b ||
                    bytes1(nb[i + 2]) == 0x8c ||
                    bytes1(nb[i + 2]) == 0x8d
                ) {
                    return false;
                }
            } else if (bytes1(nb[i]) == 0xef) {
                if (bytes1(nb[i + 1]) == 0xbb && bytes1(nb[i + 2]) == 0xbf)
                    return false;
            }
        }
        return true;
    }
}
