// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { MetadataResolver } from "../base/MetadataResolver.sol";
import { EIP712 } from "../base/EIP712.sol";
import { LibString } from "../libraries/LibString.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

contract MocaId is ERC721, Ownable2Step, MetadataResolver, EIP712 {
    using LibString for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Token URI prefix.
     */
    string public baseTokenUri;

    /**
     * @notice Maps each uint256 representation of a mocaId to registration expire time.
     */
    mapping(uint256 => uint256) public expiries;

    /**
     * @notice User nonces that prevents signature replay.
     */
    mapping(address => uint256) public nonces;

    /**
     * @notice Signer that approve meta transactions.
     */
    address internal _signer;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant GRACE_PERIOD = 30 days;

    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256(
            "register(string mocaId,address to,uint256 duration,uint256 nonce,uint256 deadline)"
        );

    bytes32 internal constant _RENEW_TYPEHASH =
        keccak256(
            "renew(string mocaId,uint256 duration,uint256 nonce,uint256 deadline)"
        );

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a mocaId is registered.
     *
     * @param mocaId The mocaId
     * @param to     The address that owns the mocaId
     * @param expiry The timestamp at which the registration expires
     */
    event Register(string mocaId, address indexed to, uint256 expiry);

    /**
     * @dev Emit an event when a mocaId is renewed.
     *
     * @param mocaId    The mocaId
     * @param expiry The timestamp at which the renewal expires
     */
    event Renew(string mocaId, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _signer = msg.sender;
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
        return
            _valid(mocaId) &&
            expiries[uint256(label)] + GRACE_PERIOD < block.timestamp;
    }

    /**
     * @notice Mints a new mocaId.
     *
     * @param mocaId    The mocaId to register
     * @param to        The address that will own the mocaId
     * @param duration  The duration of the registration
     * @param signature The signature signed by signer
     */
    function register(
        string calldata mocaId,
        address to,
        uint256 duration,
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
                        duration,
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

        _register(mocaId, to, duration);
    }

    /**
     * @notice Mints a new mocaId by trusted caller.
     *
     * @param mocaId   The mocaId to register
     * @param to       The address that will own the mocaId
     * @param duration The duration of the registration
     */
    function trustedRegister(
        string calldata mocaId,
        address to,
        uint256 duration
    ) external onlySigner {
        _register(mocaId, to, duration);
    }

    /**
     * @notice Renews a mocaId for a duration while it is in the renewable period.
     *
     * @param mocaId    The the mocaId to renew
     * @param duration  The duration of the renewal
     * @param signature The signature signed by signer
     */
    function renew(
        string calldata mocaId,
        uint256 duration,
        bytes calldata signature
    ) external {
        DataTypes.EIP712Signature memory sig;

        (sig.v, sig.r, sig.s, sig.deadline) = abi.decode(
            signature,
            (uint8, bytes32, bytes32, uint256)
        );

        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        address tokenOwner = super.ownerOf(tokenId);

        _requiresExpectedSigner(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _RENEW_TYPEHASH,
                        mocaId,
                        duration,
                        nonces[tokenOwner]++,
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

        _renew(mocaId, tokenId, duration);
    }

    /**
     * @notice Renews a mocaId for a duration while it is in the renewable period by trusted caller..
     *
     * @param mocaId   The the mocaId to renew
     * @param duration The duration of the renewal
     */
    function trustedRenew(
        string calldata mocaId,
        uint256 duration
    ) external onlySigner {
        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        _renew(mocaId, tokenId, duration);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-721 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override the ownerOf implementation to throw if a mocaId is renewable or biddable.
     *
     * @param tokenId The uint256 tokenId of the mocaId
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        /* Revert if mocaId was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs >= block.timestamp) {
            return address(0);
        }

        /* Safety: If the token is unregistered, super.ownerOf will revert */
        return super.ownerOf(tokenId);
    }

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

    function _register(
        string calldata mocaId,
        address to,
        uint256 duration
    ) internal {
        require(available(mocaId), "INVALID_NAME");

        /**
         * Mints the token by calling the ERC-721 _safeMint() function.
         * The _safeMint() function ensures that the to address isnt 0
         * and that the tokenId is not already minted.
         */
        bytes32 label = keccak256(bytes(mocaId));
        uint256 tokenId = uint256(label);
        if (_exists(tokenId)) {
            _clearMetadatas(tokenId);
            _burn(tokenId);
        }
        super._safeMint(to, tokenId);

        /**
         * Set the expiration timestamp
         */
        unchecked {
            expiries[tokenId] = block.timestamp + duration;
        }

        emit Register(mocaId, to, expiries[tokenId]);
    }

    function _renew(
        string memory mocaId,
        uint256 tokenId,
        uint256 duration
    ) internal {
        /* Revert if the mocaId's tokenId has never been registered */
        uint256 expiryTs = expiries[tokenId];
        require(expiryTs > 0, "NOT_REGISTERED");

        /**
         * Revert if the mocaId has passed out of the renewable period.
         */
        unchecked {
            require(block.timestamp < expiryTs + GRACE_PERIOD, "NOT_RENEWABLE");
        }

        /**
         * Renew the name by setting the new expiration timestamp
         */
        expiries[tokenId] += duration;

        emit Renew(mocaId, expiries[tokenId]);
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
        /* Revert if mocaId was registered once and the expiration time has passed */
        uint256 expiryTs = expiries[tokenId];
        if (expiryTs != 0) {
            require(block.timestamp < expiryTs, "EXPIRED");
        }
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
