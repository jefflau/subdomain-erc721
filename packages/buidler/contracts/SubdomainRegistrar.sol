pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";
import "../interfaces/ENS.sol";
import "../interfaces/Resolver.sol";
import "../interfaces/ISubdomainRegistrar.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

struct Domain {
    string name;
    address payable owner;
    address transferAddress;
    uint256 price;
    uint256 referralFeePPM;
}

// SPDX-License-Identifier: MIT
contract SubdomainRegistrar is ERC721, ISubdomainRegistrar {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    // namehash('eth')
    bytes32
        public constant TLD_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

    bool public stopped = false;
    address public registrarOwner;
    address public migration;
    address public registrar;
    mapping(bytes32 => Domain) domains;

    ENS public ens;

    function owner(bytes32 label) public override view returns (address) {
        if (domains[label].owner != address(0x0)) {
            return domains[label].owner;
        }

        // Deed domainDeed = deed(label);
        // if (domainDeed.owner() != address(this)) {
        //     return address(0x0);
        // }

        // return domainDeed.previousOwner();
    }

    modifier ownerOnly(bytes32 label) {
        require(owner(label) == msg.sender);
        _;
    }

    modifier notStopped() {
        require(!stopped);
        _;
    }

    modifier registrarOwnerOnly() {
        require(msg.sender == registrarOwner);
        _;
    }

    constructor() public ERC721("ENS Name", "ENS") {}

    // TODO move to constructor and take as argument
    function setENS(ENS _ens) public {
        ens = _ens;
    }

    function configureDomainFor(
        string memory name,
        uint256 price,
        uint256 referralFeePPM,
        address payable _owner,
        address _transfer
    ) public ownerOnly(keccak256(bytes(name))) {
        bytes32 label = keccak256(bytes(name));
        Domain storage domain = domains[label];

        // Don't allow changing the transfer address once set. Treat 0 as "don't change" for convenience.
        require(
            domain.transferAddress == address(0x0) ||
                _transfer == address(0x0) ||
                domain.transferAddress == _transfer
        );

        if (domain.owner != _owner) {
            domain.owner = _owner;
        }

        if (keccak256(abi.encodePacked(domain.name)) != label) {
            // New listing
            domain.name = name;
        }

        domain.price = price;
        domain.referralFeePPM = referralFeePPM;

        // if (domain.transferAddress != _transfer && _transfer != address(0x0)) {
        //     domain.transferAddress = _transfer;
        //     emit TransferAddressSet(label, _transfer);
        // }

        emit DomainConfigured(label);
    }

    function doRegistration(
        bytes32 node,
        bytes32 label,
        address subdomainOwner,
        Resolver resolver
    ) internal {
        // Get the subdomain so we can configure it
        ens.setSubnodeOwner(node, label, address(this));

        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        // Set the subdomain's resolver
        ens.setResolver(subnode, address(resolver));

        // Set the address record on the resolver
        resolver.setAddr(subnode, subdomainOwner);

        // Pass ownership of the new subdomain to the registrant
        ens.setOwner(subnode, subdomainOwner);
    }

    function register(
        bytes32 label,
        string calldata subdomain,
        address _subdomainOwner,
        address payable referrer,
        address resolver
    ) external override payable notStopped {
        address subdomainOwner = _subdomainOwner;
        bytes32 domainNode = keccak256(abi.encodePacked(TLD_NODE, label));
        bytes32 subdomainLabel = keccak256(bytes(subdomain));

        // Subdomain must not be registered already.
        require(
            ens.owner(
                keccak256(abi.encodePacked(domainNode, subdomainLabel))
            ) == address(0)
        );

        Domain storage domain = domains[label];

        // Domain must be available for registration
        require(keccak256(abi.encodePacked(domain.name)) == label);

        // User must have paid enough
        require(msg.value >= domain.price);

        // Send any extra back
        if (msg.value > domain.price) {
            msg.sender.transfer(msg.value - domain.price);
        }

        // Send any referral fee
        uint256 total = domain.price;
        if (
            domain.referralFeePPM * domain.price > 0 &&
            referrer != address(0x0) &&
            referrer != domain.owner
        ) {
            uint256 referralFee = (domain.price * domain.referralFeePPM) /
                1000000;
            referrer.transfer(referralFee);
            total -= referralFee;
        }

        // Send the registration fee
        if (total > 0) {
            domain.owner.transfer(total);
        }

        // Register the domain
        if (subdomainOwner == address(0x0)) {
            subdomainOwner = msg.sender;
        }
        doRegistration(
            domainNode,
            subdomainLabel,
            subdomainOwner,
            Resolver(resolver)
        );

        emit NewRegistration(
            label,
            subdomain,
            subdomainOwner,
            referrer,
            domain.price
        );
    }

    function awardItem(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}
