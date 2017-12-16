// AID tokensale smart contract.
// Developed by Phenom.Team <info@phenom.team>

// pragma solidity ^ 0.4.15;

/**
    @title SafeMath
    @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal constant returns(uint256) {
        assert(b > 0);
        uint256 c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns(uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns(uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title ERC20
 * @dev Standart ERC20 token interface
 */
contract ERC20 {
    uint256 public totalSupply = 0;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    function balanceOf(address _owner) public constant returns(uint256);
    function transfer(address _to, uint256 _value) public returns(bool);
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function approve(address _spender, uint256 _value) public returns(bool);
    function allowance(address _owner, address _spender) public constant returns(uint256);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

/**
* @title AidaICO contract  - takes funds from users and issues tokens
* @dev AidaICO - it's the first ever contract for ICO which allows users to
       return their investments.
*/
contract AidaICO {
    //AID - Aida token contract
    AidaToken public AID = new AidaToken(this);
    using SafeMath for uint256;

    // Token price parameters
    // These parametes can be changed only by manager of contract
    uint256 public Rate_Eth = 700; // Rate USD per ETH
    uint256 public Tokens_Per_Dollar = 4; //Aida token per dollar
    uint256 public Token_Price = Tokens_Per_Dollar * Rate_Eth; // Aida token per ETH

    // Crowdfunding parameters
    uint256 constant ICO_RETURN_DURATION = 12; 
    // Investors can return their investments during ICO_RETURN_DURATION
    // Company can withdraw  ether from ico contract after ICO_RETURN_DURATION
    uint256 constant bountyPart = 20; // 2% of TotalSupply for BountyFund
    uint256 constant partnersPart = 30; //3% f TotalSupply for PartnersFund
    uint256 constant teamPart = 200; //20% of TotalSupply for TeamFund
    uint256 constant icoAndPOfPart = 750; // 75% of TotalSupply for PublicICO and PrivateOffer
    uint256 startTime = 0; // Start time timestamp

    // Output ethereum addresses
    address public Company;
    address public BountyFund;
    address public PartnersFund;
    address public TeamFund;
    address public Manager; // Manager controls contract
    address public Controller_Address1; // First address that is used to buy tokens for other cryptos
    address public Controller_Address2; // Second address that is used to buy tokens for other cryptos
    address public Controller_Address3; // Third address that is used to buy tokens for other cryptos

    // Possible ICO statuses
    enum StatusICO {
        Created,
        PreIcoStarted,
        PreIcoPaused,
        PreIcoFinished,
        IcoStarted,
        IcoPaused,
        IcoFinished
    }

    StatusICO statusICO = StatusICO.Created;

    // Mappings
    mapping(address => uint256) public ethPreIco; //Mapping for remembering eth of investors who paid at PreICO
    mapping(address => uint256) public ethIco; //Mapping for remembering eth of investors who paid at ICO
    mapping(address => uint256) public tokensPreIco; //Mapping for remembering tokens of investors who paid at ICO
    mapping(address => uint256) public tokensIco; //Mapping for remembering tokens of investors who paid at ICO
    mapping(address => bool) public used; // Users can return their funds one time


    // Events Log
    event LogStartICO();
    event LogPauseICO();
    event LogFinishICO(address bountyFund, address partnersFund, address teamFund);
    event LogBuyForInvestor(address investor, uint256 aidValue, string txHash);
    event LogReturnEth(address investor, uint256 eth);

    // Modifiers
    // Allows execution by the owner only
    modifier managerOnly {
        require(msg.sender == Manager);
        _;
    }
    // Allows execution by the one of controllers only
    modifier controllersOnly {
      require((msg.sender == Controller_Address1) || (msg.sender == Controller_Address2) || (msg.sender == Controller_Address3));
      _;
    }


    /**
        @dev Contract constructor function
    */
    function AidaICO(
        address _Company,
        address _BountyFund,
        address _PartnersFund,
        address _TeamFund,
        address _Manager,
        address _Controller_Address1,
        address _Controller_Address2,
        address _Controller_Address3
    ) public {
        Company = _Company;
        BountyFund = _BountyFund;
        PartnersFund = _PartnersFund;
        TeamFund = _TeamFund;
        Manager = _Manager;
        Controller_Address1 = _Controller_Address1;
        Controller_Address2 = _Controller_Address2;
        Controller_Address3 = _Controller_Address3;
    }

    /**
        @dev Setting rate of ETH and updating token price
        @param _RateEth     current ETH rate
    */
    function setRate(uint256 _RateEth) external managerOnly {
        Rate_Eth = _RateEth;
        Token_Price = Tokens_Per_Dollar.mul(Rate_Eth);
    }


        /**
        @dev Start PreIco
        Set ICO status to PreIcoStarted
    */
    function startPreIco() external managerOnly {
        require(statusICO == StatusICO.Created || statusICO == StatusICO.PreIcoPaused);
        statusICO = StatusICO.PreIcoStarted;
        LogStartICO();
    }

    /**
        @dev Pause PreIco
        Set Ico status to PreIcoPaused
    */
    function pausePreIco() external managerOnly {
        require(statusICO == StatusICO.PreIcoStarted);
        statusICO = StatusICO.PreIcoPaused;
        LogPauseICO();
    }
        /**
        @dev Finish PreIco
        Set Ico status to PreIcoFinished

    */
    function finishPreIco() external managerOnly {
        require(statusICO == StatusICO.PreIcoStarted || statusICO == StatusICO.PreIcoPaused);
        statusICO = StatusICO.PreIcoFinished;
        LogPauseICO();
    }

    /**
        @dev Start ICO
        Set start ICO time
        Set ICO status to IcoStarted
    */
    function startIco() external managerOnly {
        require(statusICO == StatusICO.PreIcoFinished || statusICO == StatusICO.IcoPaused);
        if (statusICO == StatusICO.PreIcoFinished) {
            startTime = now;
        }
        statusICO = StatusICO.IcoStarted;
        LogStartICO();
    }

    /**
        @dev Pause Ico
        Set Ico status to IcoPaused
    */
    function pauseIco() external managerOnly {
        require(statusICO == StatusICO.IcoStarted);
        statusICO = StatusICO.IcoPaused;
        LogPauseICO();
    }

    /**
        @dev Finish ICO, unfreeze(enable token transfers)tokens and emit tokens for bounty company,
        partners and team
    */
    function finishIco() external managerOnly {
        require(statusICO == StatusICO.IcoStarted || statusICO == StatusICO.IcoPaused);
        uint256 alreadyMinted = AID.totalSupply(); // = PublicICO
        uint256 totalAmount = alreadyMinted.mul(1000).div(icoAndPOfPart); 
        AID.mintTokens(BountyFund, bountyPart.mul(totalAmount).div(1000));
        AID.mintTokens(PartnersFund, partnersPart.mul(totalAmount).div(1000));
        AID.mintTokens(TeamFund, teamPart.mul(totalAmount).div(1000));
        statusICO = StatusICO.IcoFinished;
        LogFinishICO(BountyFund, PartnersFund, TeamFund);
    }

    function enableTokensTransfer() external managerOnly {
        require(statusICO == StatusICO.IcoFinished);
        AID.defrostTokens();
    }

    /**
        @dev Fallback function calls createTokens() function to create tokens
        when investor sends ETH to address of ICO contract
    */
    function() external payable {
        require(statusICO == StatusICO.PreIcoStarted || statusICO == StatusICO.IcoStarted);
        createTokens(msg.sender, msg.value.mul(Token_Price));
        rememberEther(msg.value, msg.sender);
    }

    /**
        @dev Store how many eth were invested by investor
        @param _value        amount of invested ether in Wei
        @param _investor     address of investor
    */
    function rememberEther(uint256 _value, address _investor) internal {
        if (statusICO == StatusICO.PreIcoStarted) {
            ethPreIco[_investor] = ethPreIco[_investor].add(_value);
        }
        if (statusICO == StatusICO.IcoStarted) {
            ethIco[_investor] = ethIco[_investor].add(_value);
        }
    }

    /**
        @dev Writes how many tokens investor received
        @param _value        amount of tokens
        @param _investor     address of investor
    */
    function rememberTokens(uint256 _value, address _investor) internal {
        if (statusICO == StatusICO.PreIcoStarted) {
            tokensPreIco[_investor] = tokensPreIco[_investor].add(_value);
        }
        if (statusICO == StatusICO.IcoStarted) {
            tokensIco[_investor] = tokensIco[_investor].add(_value);
        }
    }

    /**
        @dev Issues tokens for users who made purchases in other cryptocurrencies
        @param _investor     address the tokens will be issued to
        @param _txHash       transaction hash of investor's payment
        @param _aidValue     number of Aida tokens
    */
    function buyForInvestor(
        address _investor,
        uint256 _aidValue,
        string _txHash
    )
        external controllersOnly {
        require(statusICO == StatusICO.PreIcoStarted || statusICO == StatusICO.IcoStarted);
        createTokens(_investor, _aidValue);
        LogBuyForInvestor(_investor, _aidValue, _txHash);
    }

    /**
        @dev Issue tokens for investors
        @param _investor     address which the tokens will be issued to
        @param _aidValue     number of Aida tokens
    */
    function createTokens(address _investor, uint256 _aidValue) internal {
        require(_aidValue > 0);
        uint256 bonus = getBonus(_aidValue);
        uint256 total = _aidValue.add(bonus);
        rememberTokens(total, _investor);
        AID.mintTokens(_investor, total);
    }

    /**
        @dev Calculates bonus if PreIco sales still not over
        @param _value        amount of invested ether in Wei
        @return              bonus value
    */
    function getBonus(uint256 _value)
        public
        constant
        returns(uint256)
    {
        uint256 bonus = 0;
        if (statusICO == StatusICO.PreIcoStarted) {
            bonus = _value.mul(15).div(100);
        }
        return bonus;
    }

    /**
        @dev Count days from Ico start day
    */
    function daysFromIcoStart()
        public
        constant
        returns(uint256)
    {
        return now.sub(startTime) / 24 hours;
    }

    /**
        @dev Allows users to return their investments
        if RETURN_DURATION is not over yet
        and burns tokens
    */
    function returnEther() public {
        require(!used[msg.sender]);
        uint256 eth = 0;
        uint256 tokens = 0;
        if (statusICO == StatusICO.PreIcoStarted) {
            require(ethPreIco[msg.sender] > 0);
            eth = ethPreIco[msg.sender];
            tokens = tokensPreIco[msg.sender];
            ethPreIco[msg.sender] = 0;
            tokensPreIco[msg.sender] = 0;
        }
        if (statusICO == StatusICO.IcoStarted) {
            require(ethIco[msg.sender] > 0);
            require(daysFromIcoStart() <= ICO_RETURN_DURATION);
            eth = ethIco[msg.sender];
            tokens = tokensIco[msg.sender];
            ethIco[msg.sender] = 0;
            tokensIco[msg.sender] = 0;
        }
        msg.sender.transfer(eth);
        used[msg.sender] = true;
        AID.burnTokens(msg.sender, tokens);
        LogReturnEth(msg.sender, eth);
    }

    /**
        @dev Allows Company withdraw investments when RETURN_DURATION is over
        @param _value        amount of ETH to send in Wei
    */
    function withdrawEther(uint256 _value) external managerOnly {
        require(daysFromIcoStart() > ICO_RETURN_DURATION);
        Company.transfer(_value);
    }

}


/**
    @title AidaToken
    @dev Aida token contract
*/
contract AidaToken is ERC20 {
    using SafeMath for uint256;
    string public name = "Aida TOKEN";
    string public symbol = "AID";
    uint256 public decimals = 18;

    //Ico contract address
    address public ico;
    event Burn(address indexed from, uint256 value);

    // Disables/enables token transfers
    bool public tokensAreFrozen = true;

    //Allows execution by the owner only
    modifier icoOnly {
        require(msg.sender == ico);
        _;
    }

    /**
        @dev Contract constructor function sets Ico address
        @param _ico          ico address
    */
    function AidaToken(address _ico) public {
        ico = _ico;
    }

    /**
        @dev Mint tokens
        @param _holder       beneficiary address the tokens will be issued to
        @param _value        number of tokens to issue
    */
    function mintTokens(address _holder, uint256 _value) external icoOnly {
        require(_value > 0);
        balances[_holder] = balances[_holder].add(_value);
        totalSupply = totalSupply.add(_value);
        Transfer(0x0, _holder, _value);
    }

    /**
        @dev Disables/enables token transfers
    */
    function defrostTokens() external icoOnly {
      tokensAreFrozen = false;
    }

    /**
        @dev Burn Tokens
        @param _investor     token holder address which the tokens will be burnt
        @param _value        number of tokens to burn
    */
    function burnTokens(address _investor, uint256 _value) public icoOnly {
        require(balances[_investor] > 0);
        totalSupply = totalSupply.sub(_value);
        balances[_investor] = balances[_investor].sub(_value);
        Burn(_investor, _value);
    }

    /**
        @dev Get balance of investor
        @param _owner        investor's address
        @return              balance of investor
    */
    function balanceOf(address _owner) public constant returns(uint256) {
      return balances[_owner];
    }

    /**
        @dev Send coins
        throws on any error rather then return a false flag to minimize
        user errors
        @param _to           target address
        @param _amount       transfer amount

        @return true if the transfer was successful
    */
    function transfer(address _to, uint256 _amount) public returns(bool) {
        require(!tokensAreFrozen);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
        @dev An account/contract attempts to get the coins
        throws on any error rather then return a false flag to minimize user errors

        @param _from         source address
        @param _to           target address
        @param _amount       transfer amount

        @return true if the transfer was successful
    */
    function transferFrom(address _from, address _to, uint256 _amount) public returns(bool) {
        require(!tokensAreFrozen);
        balances[_from] = balances[_from].sub(_amount);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        Transfer(_from, _to, _amount);
        return true;
    }

    /**
        @dev Allows another account/contract to spend some tokens on its behalf
        throws on any error rather then return a false flag to minimize user errors

        also, to minimize the risk of the approve/transferFrom attack vector
        approve has to be called twice in 2 separate transactions - once to
        change the allowance to 0 and secondly to change it to the new allowance
        value

        @param _spender      approved address
        @param _amount       allowance amount

        @return true if the approval was successful
    */
    function approve(address _spender, uint256 _amount) public returns(bool) {
        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
        @dev Function to check the amount of tokens that an owner allowed to a spender.

        @param _owner        the address which owns the funds
        @param _spender      the address which will spend the funds

        @return              the amount of tokens still avaible for the spender
   */
    function allowance(address _owner, address _spender) public constant returns(uint256) {
        return allowed[_owner][_spender];
    }
}
