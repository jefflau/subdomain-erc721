import "../interfaces/ENS.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// todo
// add ERC721
// change ownership to use erc721
// mint token on wrap

contract RestrictedNameWrapper is ERC721 {
    ENS public ens;
    mapping(bytes32 => address) public nameOwners;
    mapping(address => mapping(address => bool)) operators;

    constructor(ENS _ens) public ERC721("ENS Name", "ENS") {
        ens = _ens;
    }

    modifier isOwner(bytes32 node) {
        address owner = ownerOf(uint256(node));
        require(owner == msg.sender || isApprovedForAll(owner, msg.sender));
        _;
    }

    /**
     * @dev Mint Erc721 for the subdomain
     * @param id The token ID (keccak256 of the label).
     * @param subdomainOwner The address that should own the registration.
     * @param tokenURI tokenURI address
     */

    function mintERC721(
        uint256 id,
        address subdomainOwner,
        string memory tokenURI
    ) public returns (uint256) {
        _mint(subdomainOwner, id);
        _setTokenURI(id, tokenURI);
        return id;
    }

    function wrap(bytes32 node) public {
        address owner = ens.owner(node);
        require(owner == msg.sender || ens.isApprovedForAll(owner, msg.sender));
        ens.setOwner(node, address(this));
        mintERC721(uint256(node), owner, ""); //TODO add URI
    }

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external {
        setResolver(node, resolver);
        setTTL(node, ttl);
        setOwner(node, owner);
    }

    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        address resolver,
        uint64 ttl
    ) external isOwner(node) {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        require(ens.owner(subnode) == address(0));
        ens.setSubnodeRecord(node, label, owner, resolver, ttl);
    }

    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) external isOwner(node) returns (bytes32) {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        require(ens.owner(subnode) == address(0));
        ens.setSubnodeOwner(node, label, owner);
    }

    function setResolver(bytes32 node, address resolver) public isOwner(node) {
        ens.setResolver(node, resolver);
    }

    function setOwner(bytes32 node, address owner) public isOwner(node) {
        safeTransferFrom(msg.sender, owner, uint256(node));
    }

    function setTTL(bytes32 node, uint64 ttl) public isOwner(node) {
        ens.setTTL(node, ttl);
    }

    // function setApprovalForAll(address operator, bool approved) external {
    //     operators[msg.sender][operator] = approved;
    // }
}

// contract SubdomainRegistrar {
//     ENS public ens;
//     RestrictiveWrapper public wrapper;

//     constructor(ENS _ens, RestrictiveWrapper _wrapper) {
//         ens = _ens;
//         wrapper = _wrapper;
//         ens.setApprovalForAll(address(wrapper), true);
//     }

//     function configure(bytes32 name) {
//         ens.setOwner(name, address(this));
//         wrapper.wrap(name, msg.sender);
//     }
// }

// 1. ETHRegistrarController.commit()
// 2. ETHRegistrarController.registerWithConfig()
// 3. SubdomainRegistrar.configure()

// a. ENS.setApprovalForAll(SubdomainRegistrar, true)
// b. RestrictiveWrapper.setApprovaForAll(SubdomainRegistrar, true)
