pragma solidity ^0.4.2;

import './math.sol';
import './stop.sol';

import './Wallet.sol';
import "./NetworkParameters.sol";

/**
    @title LoanManager
    @notice The LoanManager contract inherits the Ownable contract, and manages loans on Lendroid.
 */
contract LoanManager is DSMath, DSStop {

    Wallet public LendroidWallet;
    NetworkParameters public LendroidNetworkParameters;

    enum Status {
        UNISSUED,
        ACTIVE,
        CLOSED,
        DEFAULTED
    }

    struct Loan {
        uint timestamp;
        address borrower;
        uint amount;
        uint amountPaid;
        uint lastUpdated;
        uint expiresOn;
        uint interestRate;
        Status status;
        bytes32 loanHash;
    }

    mapping (bytes32 => Loan) public loans;

    event LogLoanUpdated(
        bytes32 _loanHash,  // The Hash of the Loan
        address _address,   // The address that caused the action
        uint256 _amount,    // The amount associated with the action
        bytes32 _action     // The tyoe of action: "loan availed", "loan closed"
    );

    function percentOf(uint _quantity, uint _percentage) internal returns (uint256){
        return wdiv(mul(_quantity, _percentage), 10 ** LendroidNetworkParameters.decimals());
    }

    /**
        @dev Throws if called by any account.
    */
    function() {
        revert();
    }

    /// @dev Allows owner to set the NetworkParameters contract.
    /// @param _address Address of the NetworkParameters contract.
    function setLendroidNetworkParameters(address _address)
        public
        stoppable
        auth
        returns (bool) 
    {
        LendroidNetworkParameters = NetworkParameters(_address);
        return true;
    }

    /// @dev Allows owner to set the Wallet contract.
    /// @param _address Address of the Wallet contract.
    function setLendroidWallet(address _address)
        public
        stoppable
        auth
        returns (bool) 
    {
        LendroidWallet = Wallet(_address);
        return true;
    }

    /**
        @notice Avail a loan
        @return true the loan was successfully created
    */
    function availLoan() 
        public 
        stoppable
        returns (bool) 
    {
        var (_encumbered, _lockedAmount) = LendroidWallet.encumberCollateral(msg.sender);
        assert(_encumbered);
        // Set loan fields and save loan
        Loan memory loan;
        loan.timestamp = now;
        loan.borrower = msg.sender;
        loan.amount = percentOf(_lockedAmount, LendroidNetworkParameters.initialMargin());
        loan.expiresOn = now + LendroidNetworkParameters.maxLoanPeriodDays();
        loan.interestRate = LendroidNetworkParameters.interestRatePerDay();
        loan.status = Status.ACTIVE;

        loan.loanHash = getLoanHash(
            loan.timestamp,
            loan.borrower,
            loan.amount,
            loan.expiresOn,
            loan.interestRate
        );
        loans[loan.loanHash] = loan;
        msg.sender.transfer(loan.amount);
        LogLoanUpdated(
            loan.loanHash,  // The Hash of the Loan
            msg.sender,   // The address that caused the action
            loan.amount,    // The amount associated with the action
            "loan availed"     // The tyoe of action: "loan availed", "loan closed"
        );
        return true;
    }

    /**
        @param _loanHash the hash of the loan that has to be closed
        @return true the loan was successfully closed
    */
    function closeLoan(bytes32 _loanHash) 
        payable 
        stoppable
        returns (bool) 
    {
        // Get Active loan based on hash
        Loan storage activeLoan = loans[_loanHash];
        // Validations
        // Verify borrower
        require(activeLoan.borrower == msg.sender);
        // Verify expiry date
        require(add(activeLoan.expiresOn, LendroidNetworkParameters.gracePeriodDays()) >= now);
        // Verify interest
        uint daysSinceLoan = wdiv(now - activeLoan.timestamp, 86400);
        uint interestAccrued = mul(percentOf(activeLoan.amount , LendroidNetworkParameters.interestRatePerDay()), daysSinceLoan);
        require(add(interestAccrued, activeLoan.amount) == msg.value);
        // Archive the active loan
        activeLoan.status = Status.CLOSED;
        activeLoan.amountPaid = msg.value;
        activeLoan.lastUpdated = now;
        //require(collateralManager.unencumberCollateral(activeLoan.ensDomainHash, msg.sender));
        LogLoanUpdated(
            activeLoan.loanHash,  // The Hash of the Loan
            msg.sender,   // The address that caused the action
            activeLoan.amountPaid,    // The amount associated with the action
            "loan closed"     // The tyoe of action: "loan availed", "loan closed"
        );
        
        return true;
    }

    /// @return Keccak-256 hash of loan.
    function getLoanHash(
            uint timestamp,
            address borrower,
            uint amount,
            uint expiresOn,
            uint interestRate
        )
        public
        constant
        returns (bytes32)
    {
        return keccak256(
            address(this),
            timestamp,
            borrower,
            amount,
            expiresOn,
            interestRate
        );
    }

    /**
        @param _loanHash the hash of the loan whose amount is owed
        @return uint the owed amount
    */
    function amountOwed(bytes32 _loanHash) constant returns (uint) {
        Loan storage activeLoan = loans[_loanHash];
        uint daysSinceLoan = wdiv(now - activeLoan.timestamp, 86400);
        uint interestAccrued = mul(percentOf(activeLoan.amount , LendroidNetworkParameters.interestRatePerDay()), daysSinceLoan);
        if (activeLoan.expiresOn < now) {
            return 0;
        }
        return add(interestAccrued, activeLoan.amount);
    }

    /**
        @dev Payable which can be called only by the contract owner.
        @return true the contract's balance was successfully refilled
    */
    function refillBalance() payable auth returns (bool) {
        return true;
    }

    /**
        @dev Payable function which can be called only by the contract owner.
        @return true the contract's balance was successfully withdrawn
    */
    function withdrawBalance(uint256 _amount) auth returns (bool) {
        msg.sender.transfer(_amount);
        return true;
    }

}