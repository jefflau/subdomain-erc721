pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";

// SPDX-License-Identifier: MIT
contract Test {
    uint256 public i;

    function callMe(uint256 j) public {
        i += j;
    }

    function getData() public view returns (bytes memory) {
        return abi.encodeWithSignature("callMe(uint256)", 123);
    }
}
