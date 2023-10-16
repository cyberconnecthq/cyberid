// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "@ens/registry/ENS.sol";
import "@ens/resolvers/profiles/ABIResolver.sol";
import "@ens/resolvers/profiles/AddrResolver.sol";
import "@ens/resolvers/profiles/ContentHashResolver.sol";
import "@ens/resolvers/profiles/DNSResolver.sol";
import "@ens/resolvers/profiles/InterfaceResolver.sol";
import "@ens/resolvers/profiles/NameResolver.sol";
import "@ens/resolvers/profiles/PubkeyResolver.sol";
import "@ens/resolvers/profiles/TextResolver.sol";
import "@ens/resolvers/profiles/ExtendedResolver.sol";
import "@ens/resolvers/Multicallable.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its
 * address.
 */
contract CyberIdPublicResolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ExtendedResolver,
    Ownable
{
    ENS immutable cyberIdRegistry;
    uint256 private constant COIN_TYPE_OPT = 614;

    address public trustedCyberIdRegistrar;
    address public trustedReverseRegistrar;

    /**
     * A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * A mapping of delegates. A delegate that is authorised by an owner
     * for a name may make changes to the name's resolver, but may not update
     * the set of token approvals.
     * (owner, name, delegate) => approved
     */
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        private _tokenApprovals;

    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Logged when a delegate is approved or  an approval is revoked.
    event Approved(
        address owner,
        bytes32 indexed node,
        address indexed delegate,
        bool indexed approved
    );

    constructor(ENS _cyberIdRegistry, address _owner) {
        cyberIdRegistry = _cyberIdRegistry;
        _transferOwnership(_owner);
    }

    function setTrustedCyberIdRegistrar(
        address _trustedCyberIdRegistrar
    ) external onlyOwner {
        trustedCyberIdRegistrar = _trustedCyberIdRegistrar;
    }

    function setTrustedReverseRegistrar(
        address _trustedReverseRegistrar
    ) external onlyOwner {
        trustedReverseRegistrar = _trustedReverseRegistrar;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Approve a delegate to be able to updated records on a node.
     */
    function approve(bytes32 node, address delegate, bool approved) external {
        require(msg.sender != delegate, "Setting delegate status for self");

        _tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /**
     * @dev Check to see if the delegate has been approved by the owner for the node.
     */
    function isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) public view returns (bool) {
        return _tokenApprovals[owner][node][delegate];
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (
            msg.sender == trustedCyberIdRegistrar ||
            msg.sender == trustedReverseRegistrar
        ) {
            return true;
        }
        address owner = cyberIdRegistry.owner(node);
        return
            owner == msg.sender ||
            isApprovedForAll(owner, msg.sender) ||
            isApprovedFor(owner, node, msg.sender);
    }

    function setAddr(
        bytes32 node,
        address a
    ) external override authorised(node) {
        super.setAddr(node, COIN_TYPE_OPT, addressToBytes(a));
    }

    function addr(bytes32 node) public view override returns (address payable) {
        bytes memory a = addr(node, COIN_TYPE_OPT);
        if (a.length == 0) {
            return payable(0);
        }
        return bytesToAddress(a);
    }

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes memory a
    ) public override authorised(node) {
        emit AddressChanged(node, coinType, a);
        if (coinType == COIN_TYPE_OPT) {
            emit AddrChanged(node, bytesToAddress(a));
        }
        versionable_addresses[recordVersions[node]][node][coinType] = a;
    }

    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
