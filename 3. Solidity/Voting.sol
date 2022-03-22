pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Voting is Ownable {
    //voter declaration
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    //list of voters declaration 
    mapping(address => Voter) public voters;
    
    //list of tied votes count 
    mapping(uint => bool) private tie;

    //proposal declaration
    struct Proposal { 
        string description; //titre de la résolution
        uint voteCount; //nombre de voix en faveur
    }
    //list of proposals (dynamic array)
    Proposal[] public proposals; 

    //winning proposal id declaration
    uint private winningProposalId;

    //customized type declaration, to store current step of the voting process
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //status of the voting process declaration
    WorkflowStatus public status;

    //events declaration
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //modifier to allow functions call only to registered voted
    modifier onlyRegistered() {
        require(voters[msg.sender].isRegistered == true, "action reservee aux votants inscrits");
        _;
    }
    //modifier to allow functions call only when on a particular status of the voting process
    modifier inStatus(WorkflowStatus _status) {
        require(status == _status, "action non autorisee a ce stade de la session");
        _;
    }

    //initialization of some variables when contract is deployed
    constructor()  {
          voters[msg.sender].isRegistered = true;//inscription de l'admin en tant que votant 
          status = WorkflowStatus.RegisteringVoters;//ouverture phase enregistrement votants. Voir si nécessaire et pas déjà par défaut
    }

    //to add a voter to whitelist
   function addVoter(address _address) external inStatus(WorkflowStatus.RegisteringVoters) onlyOwner {
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    //to start registration of proposals 
    function startProposalsRegistration() external inStatus(WorkflowStatus.RegisteringVoters) onlyOwner {
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

     //to add proposal
    function addProposal(string memory _description) external inStatus(WorkflowStatus.ProposalsRegistrationStarted) onlyRegistered {
        proposals.push(Proposal(_description, 0));
        uint proposalId = proposals.length -1;
        emit ProposalRegistered(proposalId);
    }

    //to end registration of proposals 
    function endProposalsRegistration() external inStatus(WorkflowStatus.ProposalsRegistrationStarted) onlyOwner {
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    
    }

    //to open voting session
    function startVotingSession() external inStatus(WorkflowStatus.ProposalsRegistrationEnded) onlyOwner {
        require(proposals.length > 0, "aucune proposition a mettre aux voix");
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    //to vote
    function doVote(uint proposalId) external inStatus(WorkflowStatus.VotingSessionStarted) onlyRegistered {
        require(!voters[msg.sender].hasVoted, "deja vote!");
        require((proposalId <= proposals.length), "aucune proposition correspondante");
        voters[msg.sender].votedProposalId = proposalId;
        voters[msg.sender].hasVoted = true;
        proposals[proposalId].voteCount += 1;
        emit Voted(msg.sender, proposalId);
    }

    //to get descriptions and current votes count for each proposal
    function getCurrentDetailsOfProposals() external inStatus(WorkflowStatus.VotingSessionStarted) onlyRegistered view returns(Proposal[] memory) {
        return proposals; //return a tupple of proposals description/votes count, should be handled by frontend for a better presentation
    }

    //to end voting session
    function endVotingSession() external inStatus(WorkflowStatus.VotingSessionStarted) onlyOwner {
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

     //to get final votes count for each proposal
    function getFinalDetailsOfProposals() external inStatus(WorkflowStatus.VotingSessionEnded) onlyRegistered view returns(Proposal[] memory) {
        return proposals; //return a tupple of proposals description/votes count, should be handled by frontend for a better presentation
    }

    //to determine wining proposal id 
    function _highestVotedProposal() private {
        uint winningVoteCount = 0;
        for(uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount >= winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
                if (proposals[i].voteCount == winningVoteCount) {
                tie[i] = true;
                }
            }
        }
        if(winningVoteCount == 0) {
             revert("quorum non atteint");
        }    
    
        if((winningVoteCount != 0) && (tie[winningProposalId] == true)) {
             revert("egalite de voix");
        }      
    }

    //to determine wining proposal id 
    function _highestVotedProposal() private {
        uint winningVoteCount = 0;
        for(uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;   
            }
            else if ((proposals[i].voteCount == winningVoteCount) && (winningVoteCount > 0)) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
                tie[winningProposalId] = true;
            }

        }

        if(winningVoteCount == 0){
             revert("quorum non atteint");
        }    
    
        if(tie[winningProposalId] == true){
             revert("egalite de voix");
        }      
    }

    //to tally votes
    function tallyVotes() external onlyOwner {
        _highestVotedProposal();
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        }

    //to get winning proposal description and votes count
    function getWinner() external view inStatus(WorkflowStatus.VotesTallied) returns(string memory _description, uint _votesCount) {
        return (proposals[winningProposalId].description, proposals[winningProposalId].voteCount);
    }

}