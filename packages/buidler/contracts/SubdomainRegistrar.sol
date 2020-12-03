pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";
import "../interfaces/ENS.sol";
import "../interfaces/Resolver.sol";
import "../interfaces/ISubdomainRegistrar.sol";
import "../interfaces/IRestrictedNameWrapper.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

struct Domain {
    uint256 price;
    uint256 referralFeePPM;
}

// SPDX-License-Identifier: MIT
contract SubdomainRegistrar is ISubdomainRegistrar {
    // namehash('eth')
    bytes32
        public constant TLD_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

    bool public stopped = false;
    address public registrarOwner;
    address public migration;
    address public registrar;
    mapping(bytes32 => Domain) domains;

    ENS public ens;
    IRestrictedNameWrapper public wrapper;

    modifier ownerOnly(bytes32 node) {
        address owner = wrapper.ownerOf(uint256(node));
        require(
            owner == msg.sender || wrapper.isApprovedForAll(owner, msg.sender),
            "Not owner"
        ); //TODO fix only owner
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

    constructor(ENS _ens, IRestrictedNameWrapper _wrapper) public {
        ens = _ens;
        wrapper = _wrapper;
        ens.setApprovalForAll(address(wrapper), true);
    }

    function configureDomain(
        bytes32 node,
        uint256 price,
        uint256 referralFeePPM
    ) public {
        Domain storage domain = domains[node];

        //check if I'm the owner
        if (ens.owner(node) != address(wrapper)) {
            console.log("wrapper is not owner");
            ens.setOwner(node, address(this));
            console.log("ens.setOwner");
            wrapper.wrap(node, 255, msg.sender);
            console.log("node");
            console.logBytes32(node);
            console.log(
                "wrapper.ownerOf(uint256(node))",
                wrapper.ownerOf(uint256(node))
            );
            //wrapper.setApprovalForAll(address(this), true);
        }
        //if i'm in the owner, do nothing
        //otherwise makes myself the owner

        // if (domain.owner != _owner) {
        //     domain.owner = _owner;
        // }

        domain.price = price;
        domain.referralFeePPM = referralFeePPM;

        emit DomainConfigured(node);
    }

    function doRegistration(
        bytes32 node,
        bytes32 label,
        address subdomainOwner,
        Resolver resolver,
        address addr
    ) internal {
        // Get the subdomain so we can configure it
        console.log("doRegistration", address(this));
        wrapper.setSubnodeRecordAndWrap(
            node,
            label,
            address(this),
            address(resolver),
            0,
            255
        );
        //set the owner to this contract so it can setAddr()

        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        address owner = ens.owner(subnode);
        console.log("owner in registry", owner);
        // Set the subdomain's resolver
        //wrapper.setResolver(subnode, address(resolver));
        //don't need this becausae setSubnodeRecord wikll do it

        // Set the address record on the resolver
        resolver.setAddr(subnode, subdomainOwner);
        // check if the address is != 0 and then set addr
        // reason to check some resolvers don't have setAddr

        // Pass ownership of the new subdomain to the registrant
        wrapper.setOwner(subnode, subdomainOwner);

        // Mint the ERC721 token
    }

    function register(
        bytes32 node,
        string calldata subdomain,
        address _subdomainOwner,
        address payable referrer,
        address resolver
    ) external override payable notStopped {
        address subdomainOwner = _subdomainOwner;
        bytes32 subdomainLabel = keccak256(bytes(subdomain));

        // Subdomain must not be registered already.
        require(
            ens.owner(keccak256(abi.encodePacked(node, subdomainLabel))) ==
                address(0),
            "Subdomain already registered"
        );

        Domain storage domain = domains[node];

        // Domain must be available for registration
        //require(keccak256(abi.encodePacked(domain.name)) == label);

        // User must have paid enough
        require(msg.value >= domain.price, "Not enough ether provided");

        // // Send any extra back
        if (msg.value > domain.price) {
            msg.sender.transfer(msg.value - domain.price);
        }

        // // Send any referral fee
        uint256 total = domain.price;
        if (
            domain.referralFeePPM * domain.price > 0 &&
            referrer != address(0x0) &&
            referrer != wrapper.ownerOf(uint256(node))
        ) {
            uint256 referralFee = (domain.price * domain.referralFeePPM) /
                1000000;
            referrer.transfer(referralFee);
            total -= referralFee;
        }

        // // Send the registration fee
        // if (total > 0) {
        //     domain.owner.transfer(total);
        // }

        // Register the domain
        if (subdomainOwner == address(0x0)) {
            subdomainOwner = msg.sender;
        }
        doRegistration(
            node,
            subdomainLabel,
            subdomainOwner,
            Resolver(resolver),
            subdomainOwner
        );

        emit NewRegistration(
            node,
            subdomain,
            subdomainOwner,
            referrer,
            domain.price
        );
    }

    /**
     * @dev Mint Erc721 for the subdomain
     * @param id The token ID (keccak256 of the label).
     * @param subdomainOwner The address that should own the registration.
     * @param tokenURI tokenURI address
     */
}

// interface IRestrictedNameWrapper {
//     function wrap(bytes32 node) external;
// }
