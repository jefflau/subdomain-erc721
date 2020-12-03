pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./profiles/AddrResolver.sol";
import "./profiles/ContentHashResolver.sol";
import "../interfaces/ENS.sol";

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its
 * address.
 */

contract OwnedResolver is Ownable, AddrResolver, ContentHashResolver {
    function isAuthorised(bytes32 node) internal override view returns (bool) {
        return msg.sender == owner();
    }

    function supportsInterface(bytes4 interfaceID)
        public
        override(AddrResolver, ContentHashResolver)
        pure
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
