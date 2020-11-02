pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";

//import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";

// SPDX-License-Identifier: MIT
contract SubdomainRegistrar is ERC721 {
    // a way to store ERC721

    modifier onlyOwner() {
        require(isOwner[msg.sender], "You are not an owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _confirmations) public {}
}
