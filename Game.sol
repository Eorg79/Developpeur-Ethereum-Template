pragma solidity ^0.8.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";


contract Game is Ownable {
    string target;
    string clue;
    mapping (address => bool) hasVoted;

    function setTarget(string memory _target) public onlyOwner {
        target = _target;
    }

    function setClue(string memory _clue) public onlyOwner {
        clue = _clue;
    }

    function compareTarget(string _input) internal returns(bool) {
        if(bytes(_target).length != bytes(_input).length) {
            return false;
        } else {
            return keccak256(_target) == keccak256(_input);
        }
    }
}

