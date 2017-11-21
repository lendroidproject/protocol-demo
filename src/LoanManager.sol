pragma solidity ^0.4.17;

import 'ds-math/math.sol';
import 'ds-stop/stop.sol';

import './Wallet.sol';
import "./NetworkParameters.sol";

/**
    @title LoanManager
    @notice The LoanManager contract inherits the DSMath & DSStop contracts,
        and manages loans on Lendroid.
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
        uint loanId;
    }

    mapping (bytes32 => Loan) public loans;
    mapping (address => bytes32[]) borrowedLoans;

    event LogLoanUpdated(
        bytes32 _loanHash,  // The Hash of the Loan
        address _address,   // The address that caused the action
        uint256 _amount,    // The amount associated with the action
        bytes32 _action     // The tyoe of action: "loan availed", "loan closed"
    );

    modifier onlyLendroidWallet() {
        require(msg.sender == address(LendroidWallet));
        _;
    }

    function percentOf(uint _quantity, uint _percentage) internal view returns (uint256){
        return wdiv(wmul(_quantity, _percentage), 10 ** LendroidNetworkParameters.decimals());
    }

    /**
        @dev Throws if called by any account.
    */
    function() public {
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
    function availLoan(
            uint _loanAmount
        )
        public
        stoppable
        returns (bool)
    {
        // TODO: Check if borrower account is healthy
        var _borrowableAmount = LendroidWallet.getMaximumBorrowableAmount(msg.sender);
        require(_borrowableAmount >= _loanAmount);
        require(LendroidWallet.encumberCollateral(msg.sender, _loanAmount));
        // Set loan fields and save loan
        Loan memory loan;
        loan.timestamp = now;
        loan.borrower = msg.sender;
        loan.amount = _loanAmount;
        loan.expiresOn = now + LendroidNetworkParameters.maxLoanPeriodDays();
        loan.interestRate = LendroidNetworkParameters.interestRate();
        loan.loanId = borrowedLoans[msg.sender].length;
        loan.status = Status.ACTIVE;

        loan.loanHash = getLoanHash(
            loan.timestamp,
            loan.borrower,
            loan.amount,
            loan.expiresOn,
            loan.interestRate,
            loan.loanId
        );
        loans[loan.loanHash] = loan;
        borrowedLoans[msg.sender].push(loan.loanHash);
        // msg.sender.transfer(loan.amount);
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
        public
        payable
        stoppable
        returns (bool)
    {
        // TODO: Check if borrower account is healthy
        // Get Active loan based on hash
        Loan storage activeLoan = loans[_loanHash];
        // Validations
        // Verify borrower
        require(activeLoan.borrower == msg.sender);
        // Verify expiry date
        require(add(activeLoan.expiresOn, LendroidNetworkParameters.gracePeriodDays()) >= now);
        // Verify interest
        require(amountOwed(_loanHash) == msg.value);
        // Archive the active loan
        activeLoan.status = Status.CLOSED;
        activeLoan.amountPaid = msg.value;
        activeLoan.lastUpdated = now;
        require(LendroidWallet.unEncumberCollateral(
            msg.sender,
            activeLoan.amount,
            activeLoan.amountPaid
        ));
        borrowedLoans[msg.sender][activeLoan.loanId] = borrowedLoans[msg.sender][borrowedLoans[msg.sender].length - 1];
        borrowedLoans[msg.sender].length--;
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
            uint interestRate,
            uint loanId
        )
        internal
        constant
        returns (bytes32)
    {
        return keccak256(
            address(this),
            timestamp,
            borrower,
            amount,
            expiresOn,
            interestRate,
            loanId
        );
    }

    /**
        @param _loanHash the hash of the loan whose amount is owed
        @return uint the owed amount
    */
    function amountOwed(bytes32 _loanHash)
        public
        stoppable
        constant
        returns (uint)
    {
        Loan storage activeLoan = loans[_loanHash];
        uint daysSinceLoan = wdiv(sub(now, activeLoan.timestamp), wdiv(86400, 3600));
        uint interestAccrued = wmul(percentOf(activeLoan.amount, LendroidNetworkParameters.interestRate()), daysSinceLoan);
        if (activeLoan.expiresOn < now) {
            return 0;
        }
        return add(interestAccrued, activeLoan.amount);
    }

    /**
        @param _loanHash the hash of the loan whose interest is owed
        @return uint the owed interest
    */
    function unRealizedLendingFee(bytes32 _loanHash)
        public
        stoppable
        constant
        returns (uint)
    {
        Loan storage activeLoan = loans[_loanHash];
        uint daysSinceLoan = wdiv(sub(now, activeLoan.timestamp), wdiv(86400, 3600));

        return wmul(percentOf(activeLoan.amount, LendroidNetworkParameters.interestRate()), daysSinceLoan);
    }

    /**
        @param _borrower the address of the account that has borrowed loans
        @return uint the total owed amount
    */
    function unRealizedLendingFees(address _borrower)
        public
        stoppable
        onlyLendroidWallet
        constant
        returns (uint)
    {
        uint totalInterestAccrued = 0;
        for (uint loanId = 0; loanId < borrowedLoans[_borrower].length; loanId++) {
            totalInterestAccrued = add(totalInterestAccrued, unRealizedLendingFee(borrowedLoans[_borrower][loanId]));
        }

        return totalInterestAccrued;
    }

    /**
        @param _borrower the address that has borrowed loans
        @return bytes32[] array of loan hashes
    */
    function loansBorrowed(address _borrower)
        public
        stoppable
        constant
        returns (bytes32[]) {
            return borrowedLoans[_borrower];
        }

}
