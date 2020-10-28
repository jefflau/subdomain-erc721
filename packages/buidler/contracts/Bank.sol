pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Bank {
    string public purpose;
    mapping(address => uint256) public balanceOf;

    constructor() public {
        purpose = "Decentralised EtherBank";
    }

    function deposit() public payable {
        //write requires
        balanceOf[msg.sender] += msg.value;
        console.log("Depositing ", msg.value, " for ", msg.sender);
    }

    function withdraw(uint256 _amount) public {
        balanceOf[msg.sender] -= _amount;
        msg.sender.transfer(_amount);
        console.log("Withdrawing ", _amount, " for ", msg.sender);
    }
}
