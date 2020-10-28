pragma solidity >=0.6.0 <0.7.0;

import "@nomiclabs/buidler/console.sol";

// SPDX-License-Identifier: MIT
contract MultiSig {
    address[] public owners;
    mapping(address => bool) isOwner;
    uint256 public confirmations;
    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "You are not an owner");
        _;
    }

    modifier isNotAlreadyConfirmed(uint256 _txId) {
        console.log(!transactions[_txId].isConfirmed[msg.sender]);
        require(
            !transactions[_txId].isConfirmed[msg.sender],
            "Already confirmed by this owner"
        );
        _;
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 confirmations;
        bool executed;
        mapping(address => bool) isConfirmed;
    }

    constructor(address[] memory _owners, uint256 _confirmations) public {
        owners = _owners;
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Cannot be blank address");
            isOwner[_owners[i]] = true;
        }
        confirmations = _confirmations;
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public {
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                confirmations: 0,
                executed: false
            })
        );
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        isNotAlreadyConfirmed(_txIndex)
    {
        //only let non-confirmed owners confirm
        Transaction storage transaction = transactions[_txIndex];

        //Set confirmation for this sender
        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmations += 1;
    }

    function executeTransaction(uint256 _txIndex) public {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.confirmations >= confirmations,
            "Not enough confirmations"
        );
        console.log("Execute transaction");
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "tx failed");
    }
}
