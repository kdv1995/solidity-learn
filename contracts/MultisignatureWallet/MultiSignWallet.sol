// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MultiSignatureWallet {
    //Properties
    address[] public owners;
    Transaction[] public transactions;
    uint public numOfConfirmations;

    //Mappings
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    //Structs
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numOfConfirmations;
    }

    //Events
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);

    //Modifiers
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }
    modifier txExecuted(uint _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "Transaction already executed"
        );
        _;
    }
    modifier notConfirmed(uint _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }
    modifier onlyOwner() {
        // Check if the sender is the owner by checking the isOwner mapping
        require(isOwner[msg.sender], "You are not the owner");
        _;
    }

    constructor(address[] memory _owners, uint _numOfConfirmations) {
        //Conditions to check if the owners array is not empty and the number of confirmations is valid
        require(_owners.length > 0, "Owners required");

        //Conditions to check if the number of confirmations is valid and the number of confirmations is less than or equal to the number of owners

        require(
            _numOfConfirmations > 0 && _numOfConfirmations <= _owners.length,
            "Invalid number of confirmations"
        );

        //Loop through the owners array and check if the owner is not the zero address and the owner is unique
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        //Set the number of confirmations
        numOfConfirmations = _numOfConfirmations;
    }

    //Functions
    function getNumOfConfirmationsRequired() public view returns (uint) {
        return numOfConfirmations;
    }

    // In this case submit function is used to submit/add a transaction to the transactions array which in
    // context of blockchain means that the transaction is added to the blockchain
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        // Due to the length of the transactions array being used to determine the index of the transaction
        uint txIndex = transactions.length;

        // Add the transaction to the transactions array
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numOfConfirmations: 0
            })
        );
        // Emit the SubmitTransaction event
        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numOfConfirmations++;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) txExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numOfConfirmations >= numOfConfirmations,
            "Not enough confirmations"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) txExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        transaction.numOfConfirmations--;

        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numOfConfirmations
        );
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
