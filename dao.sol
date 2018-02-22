pragma solidity ^0.4.16;

contract owned {
    address public owner;

    function owned()
    public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership (address newOwner)
    onlyOwner public {
        owner = newOwner;
    }
}

interface Token {
    function transferFrom(address _from, address _to, uint256 _value)
    public
    returns (bool success);
}

contract tokenRecipient {
    event receivedEther(address sender, uint amount);
    event receivedToken(address _from, uint256 _value, address _token, bytes _extraData);

    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData)
    public {
        Token t = Token(_token);
        require(t.transferFrom(_from, this, _value));
        receivedToken(_from, _value, _token, _extraData);
    }

    function () payable public {
        receivedEther(msg.sender, msg.value);
    }
}

contract Congress is owned, tokenRecipient {
    // Contract Variables and Events 
    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    int public majorityMargin;

    Proposal[] public proposals;

    uint public numProposals;
    mapping(address => uint) public memberId;
    Member[] public members;

    event ProposalAdded(uint proposalId, address recipient, uint amount, string description);
    event Voted(uint proposalId, bool position, address voter, string justification);
    event ProposalTallied(uint proposalId, int result, uint quorum, bool active);
    event MembershipChanged(address member, bool isMember);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatePeriodInMinutes, int newMajorityMargin);

    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        int currentResult;
        bytes32 proposalHash;
        Vote[] votes;
        mapping(address => bool) voted;
    }

    struct Member {
        address member;
        string name;
        uint memberSince;
    }

    struct Vote {
        bool inSupport;
        address voter;
        string justification;
    }

    modifier onlyMember {
        require(memberId[msg.sender] != 0);
        _;
    }

    // Constructor Function 
    function Congress (
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority
    ) payable public {
        changeVotingRules(minimumQuorumForProposals, minutesForDebate, marginOfVotesForMajority);

        // It's necessary to add an empty first member
        addMember(0, "");

        // And let's add the founder, to save a step later
        addMember(owner, 'founder');
    }

    // Add Member
    // Make `targetMember` a member named `memberName`
    // @param targetMember : ethereum address to be added 
    // @param memberName : public name for that member
    function addMember(address targetMember, string memberName) onlyOwner public {
        uint id = memberId[targetMember];
        if(id == 0) {
            memberId[targetMember] = members.length;
            id = members.length++;
        }

        members[id] = Member({member : targetMember, memberSince : now, name : memberName});
        MembershipChanged(targetMember, true);
    }

    // Remove member
    // @notice Remove memebership from `targetMember`
    // @param targetMember : ethereum address to be removed
    function removeMember(address targetMember)
    onlyOwner public {
        require(memberId[targetMember] != 0);

        for (uint i = memberId[targetMember]; i < members.length - 1; i++){
            members[i] = members[i+1];
        }
        delete members[members.length-1];
        members.length--;
    }


    // Change voting rules
    // Make so that proposals need to be discussed for at least `minutesForDevate/60` hours,
    // have at least `minimumQuorumForProposals` votes, and have 50% + `marginOfVotesForMajority` votes 
    // to be executed
    // @param minimumQuorumForProposals : how many members must vote on a proposal for it to be executed
    // @param minutesForDebate : the minimum amount of delay between when a proposal is made and when it can be executed
    // @param marginOfVotesForMajority : the proposal needs to have 50% plus this number
    function changeVotingRules(
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority
    ) onlyOwner public {
        minimumQuorum = minimumQuorumForProposals;
        debatingPeriodInMinutes = minutesForDebate;
        majorityMargin = marginOfVotesForMajority;

        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, majorityMargin);
    }

    // Add Proposal
    // proposal to send `weiAmt / 1e18` ether to `beneficiary` for `jobDescription`. 
    // `transactionBytecode ? Contains : Does not contain` code.
    // @param beneficiary : to whome we are sending ether to 
    // @param weiAmount : Amount of ether to send, in wei
    // @param jobDescription : Description of job
    // @param transactionBytecode : bytecode of transaction
    function newProposal(
        address beneficiary,
        uint weiAmount,
        string jobDescription,
        bytes transactionBytecode
    )
    onlyMember public
    returns (uint proposalId) {
        proposalId = proposals.length++;
        Proposal storage p = proposals[proposalId];
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.description = jobDescription;
        p.proposalHash = keccak256(beneficiary, weiAmount, transactionBytecode);
        p.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        ProposalAdded(proposalId, beneficiary, weiAmount, jobDescription);
        numProposals = proposalId + 1;

        return proposalId;
    }


    // Add proposal in Ether
    // Purpose to send `etherAmount` ether to `beneficiary` for `jobDescription`.
    // This is a convenience function to use if the amount to be given is in round number of ether units.
    // @param => Same as above
    function newProposalInEther(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode
    )
    onlyMember public
    returns (uint proposalId) {
        return newProposal(beneficiary, etherAmount * 1 ether, jobDescription, transactionBytecode);
    }

    // Check if proposal code matches
    // @param proposalNumber : ID number of the poposal to query
    function checkProposalCode(
        uint proposalNumber,
        address beneficiary,
        uint weiAmount,
        bytes transactionBytecode
    )
    constant public
    returns (bool codeChecksOut) {
        Proposal storage p = proposals[proposalNumber];
        return p.proposalHash == keccak256(beneficiary, weiAmount, transactionBytecode);
    }

    // Log a vote for proposal 
    // Vote `supportsProposal ? in support of : against` proposal  #`proposalNumber`
    function vote(
        uint proposalNumber,
        bool supportsProposal,
        string justificationText
    )
    onlyMember public
    returns (uint voteId){
        Proposal storage p = proposals[proposalNumber]; // get the proposal numebr
        require(!p.voted[msg.sender]);                  // check if the vote has already been casted by user
        p.voted[msg.sender] = true;
        p.numberOfVotes++;
        if (supportsProposal) {
            p.currentResult++;
        } else {
            p.currentResult--;
        }

        // create a log of this event
        Voted(proposalNumber, supportsProposal, msg.sender, justificationText);
        return p.numberOfVotes;
    }


    // Finish voting
    // Count the votes proposal #`proposalNumber` and executed it if approved
    function executeProposal(uint proposalNumber, bytes transactionBytecode)
    public {
        Proposal storage p = proposals[proposalNumber];

        require(
            now > p.votingDeadline &&
            !p.executed &&
            p.proposalHash == keccak256(p.recipient, p.amount, transactionBytecode) &&
            p.numberOfVotes >= minimumQuorum
        );

        // .. then execute the proposal

        if (p.currentResult > majorityMargin) {
            p.executed = true; // avoid recursive calling
            require(p.recipient.call.value(p.amount)(transactionBytecode));
            p.proposalPassed = true;
        }
        else {
            p.proposalPassed = false;
        }

        // fire events
        ProposalTallied(proposalNumber, p.currentResult, p.numberOfVotes, p.proposalPassed);
    }
}