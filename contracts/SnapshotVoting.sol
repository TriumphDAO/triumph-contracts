//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "usingtellor/contracts/UsingTellor.sol";
import "./governance/BondHolderTOCERC20.sol";

/**
 @author Tellor Inc.
 @title SnapshotVoting
 @dev This is the SnapshotVoting contract which defines the functionality for
 * using Tellor to verify snapshot vote results.
 * This sample contract mints 1000 tokens to a target address when the off-chain proposal passes.
*/

contract SnapshotVoting is UsingTellor {
    // Events
    event ProposalCreated(
        address indexed _snapshotVotingAddress,
        string proposalID
    );
    event ProposalExecuted(
        address indexed _snapshotVotingAddress,
        string proposalID
    );

    // Storage
    address private arbitrator;

    mapping(string => Proposal) public proposals;

    VotingToken private token;

    // Enums
    enum Status {
        OPEN,
        CLOSED,
        INVALID
    }

    // Structs
    struct Proposal {
        string description;
        string proposalID;
        //This is a mapping of tokens to a number which is the percentage voted by snapshot
        mapping(token => number) percentTokens;
        address target;
        Status status;
    }

    /*Functions*/
    /**
     * @dev Initializes the contract with the parameters, initializes the token
     * @param _tellorAddress address of Tellor contract
     */
    constructor(address payable _tellorAddress) UsingTellor(_tellorAddress) {
        arbitrator = msg.sender;
        token = new VotingToken(address(this));
    }

    /**
     * @dev Execute a passed proposal
     * @param _proposalID proposalId Id that identifies the proposal uniquely
     */
    function executeProposal(string memory _proposalID) external {
        Proposal memory proposal = proposals[_proposalID];
        require(bytes(proposal.proposalID).length != 0, "Proposal not found");
        require(proposal.status == Status.OPEN, "Proposal is not valid");
        bytes32 _queryID = keccak256(
            abi.encode("Snapshot", abi.encode(_proposalID))
        );

        //Get tokens voted on from Snapshot
        _percentTokens = readProposalResultBefore(_queryID, block.timestamp - 1 hours);
        require(bytes(_percentTokens).length != 0, "Votes not found");

        proposals[_proposalID].percentTokens = _percentTokens;
        proposals[_proposalID].status = Status.CLOSED;

        //TODO: Change token.mint to purchase of other tokens
        token.mint(proposals[_proposalID].target, 1000 ether);
        emit ProposalExecuted(proposal.target, _proposalID);
    }

    /**
     * @dev Returns the proposal votes
     * @param _proposalId proposalId Id that identifies the proposal uniquely
     * @return the tokens and their percentages
     */
    function getOutcome(string memory _proposalId)
        external
        view
        returns (bool)
    {   
        return (proposals[_proposalId].percentTokens);
    }

    /**
     * @dev Returns the token contract address
     * @return address of token contract
     */
    function getTokenAddress() external view returns (address) {
        return address(token);
    }

    /**
     * @dev Returns the proposal Status
     * @param _proposalId proposalId Id that identifies the proposal uniquely
     * @return status of the proposal
     */
    function getStatus(string memory _proposalId)
        external
        view
        returns (Status)
    {
        return proposals[_proposalId].status;
    }

    /**
     * @dev Marks a proposal as invalid
     * @param _proposalID proposalId Id that identifies the proposal uniquely
     * @notice This function is only callable by the arbitrator
     */
    function invalidateProposal(string memory _proposalID) external {
        require(msg.sender == arbitrator, "Only the arbitrator can invalidate");
        Proposal memory proposal = proposals[_proposalID];
        require(bytes(proposal.proposalID).length != 0, "Proposal not found");
        require(proposal.status == Status.OPEN, "Proposal is not valid");
        proposals[_proposalID].status = Status.INVALID;
    }

    /**
     * @dev Create a proposal
     * @param _target address of the proposal
     * @param _proposalId proposalId Id that identifies the proposal uniquely
     */
    function proposeVote(address _target, string memory _proposalId, string memory _description) external {
        require(
            bytes(proposals[_proposalId].proposalID).length == 0,
            "Proposal already submitted"
        );
        proposals[_proposalId].target = _target;
        proposals[_proposalId].proposalID = _proposalId;
        proposals[_proposalId].status = Status.OPEN;
        //Initiates the tokens vote to null
        proposals[_proposalId].percentTokens = Null;
        proposals[_proposalId]
            .description = _description;

        emit ProposalCreated(_target, _proposalId);
    }

    /**
     * @dev Get the proposal result and allow time for value to be disputed
     * @param _queryId id of desired data feed
     * @param _timestamp to retrieve data from
     * @return result of the proposal
     */
    function readProposalResultBefore(bytes32 _queryId, uint256 _timestamp)
        public
        view
        returns (bool)
    {
        // TIP:
        //For best practices, use getDataBefore with a time buffer to allow
        // time for a value to be disputed
        (bool _ifRetrieve, bytes memory _value, ) = getDataBefore(
            _queryId,
            _timestamp
        );
        require(_ifRetrieve, "must get data to execute vote");
        //TODO: Change didPass to map of tokens
        _percentTokens = abi.decode(_value, (bool));
        return (_percentTokens);
    }
}