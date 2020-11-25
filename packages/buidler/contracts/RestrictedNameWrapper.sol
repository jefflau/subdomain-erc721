import "../interfaces/ENS.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract RestrictedNameWrapper is ERC721 {
    ENS public ens;
    mapping(bytes32 => address) public nameOwners;
    mapping(address => mapping(address => bool)) operators;

    constructor(ENS _ens) public ERC721("ENS Name", "ENS") {
        ens = _ens;
    }

    modifier isOwner(bytes32 node) {
        address owner = nameOwners[node];
        require(owner == msg.sender || operators[owner][msg.sender]);
        _;
    }

    function wrap(bytes32 node) public {
        address owner = ens.owner(node);
        require(owner == msg.sender || ens.isApprovedForAll(owner, msg.sender));
        ens.setOwner(node, address(this));
        nameOwners[node] = owner;
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
        nameOwners[node] = owner;
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
