pragma solidity 0.4.18;

import "./helpers/math.sol";
import "./helpers/token.sol";
import "./helpers/stop.sol";
import "./helpers/multivault.sol";

import "./NetworkParameters.sol";
import "./LoanManager.sol";
import "./PositionManager.sol";


contract Wallet is DSMultiVault, DSMath, DSStop {

    NetworkParameters LendroidNetworkParameters;
    LoanManager LendroidLoanManager;
    PositionManager LendroidPositionManager;

    mapping (address => uint) fundingBalances; // Simple Funding balance tracker
    mapping (address => uint) collateralBalances; // Simple Collateral balance tracker
    mapping (address => uint) loanBalances; // Simple balance tracker for loan amounts borrowed
    mapping (address => uint) positionBalances; // Simple balance tracker for position amounts opened
    mapping (address => uint) wranglerBalances; // Simple Wrangler balance tracker

    modifier onlyLoanManager() {
        require(msg.sender == address(LendroidLoanManager));
        _;
    }

    modifier onlyPositionManager() {
        require(msg.sender == address(LendroidPositionManager));
        _;
    }

    /// @dev Throws if called by any account.
    function() public {
        revert();
    }

    /// @dev Allows owner to set the NetworkParameters contract.
    /// @param _address Address of the NetworkParameters contract.
    function setLendroidNetworkParameters(address _address)
        public
        stoppable
        auth// owner
        returns (bool)
    {
        LendroidNetworkParameters = NetworkParameters(_address);
        return true;
    }

    /// @dev Allows owner to set the LoanManager contract.
    /// @param _address Address of the LoanManager contract.
    function setLendroidLoanManager(address _address)
        public
        stoppable
        auth// owner
        returns (bool)
    {
        LendroidLoanManager = LoanManager(_address);
        return true;
    }

    /// @dev Allows owner to set the PositionManager contract.
    /// @param _address Address of the PositionManager contract.
    function setLendroidPositionManager(address _address)
        public
        stoppable
        auth// owner
        returns (bool)
    {
        LendroidPositionManager = PositionManager(_address);
        return true;
    }

    // Deposit funds
    function depositLendingFunds()
        public
        stoppable
        payable
        auth
        returns (bool)
    {
        fundingBalances[address(this)] = add(fundingBalances[address(this)], msg.value);
        return true;
    }

    function getFundingBalance()
        public
        stoppable
        constant
        returns (uint)
    {
        return fundingBalances[address(this)];
    }

    function depositCollateral()
        public
        stoppable
        payable
        returns (bool)
    {

        // address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
        // pull
        // pull(DSToken(_token), msg.sender, msg.value);
        collateralBalances[msg.sender] = add(collateralBalances[msg.sender], msg.value);
        return true;
    }

    // Withdraw funds
    function withdrawCollateral(uint _amount)
        public
        stoppable
        returns (bool)
    {
        // TODO: Verify margin account is healthy
        require(
            (_amount > 0) &&
            (_amount <= getMaximumWithdrawableAmount(msg.sender))
        );
        collateralBalances[msg.sender] = sub(collateralBalances[msg.sender], _amount);
        // address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
        // push
        // push(DSToken(_token), msg.sender, _amount);
        msg.sender.transfer(_amount);
        return true;
    }

    function getMarginValue(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return collateralBalances[_address];
    }

    function getNetValue(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return sub(
                add(
                    getMarginValue(_address),
                    add(
                        LendroidPositionManager.unRealizedPLs(_address),
                        LendroidLoanManager.unRealizedLendingFees(_address)
                    )
                ),
                getTotalOpenPositionsValue(_address)
            );
    }

    function getTotalBorrowedValue(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return loanBalances[_address];
    }

    function getTotalOpenPositionsValue(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return positionBalances[_address];
    }

    function getCurrentMargin(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        if (getTotalBorrowedValue(_address) == 0) {
            return 0;
        }
        return wdiv(getNetValue(_address), getTotalBorrowedValue(_address));
    }

    function isMarginAccountHealthy(
            address _address
        )
        public
        stoppable
        constant
        returns (bool)
    {
        return getCurrentMargin(_address) > wdiv(LendroidNetworkParameters.liquidationMargin(), 100);
    }

    // Get maximum amount that can be borrowed
    function getMaximumBorrowableAmount(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return sub(
            wmul(
                LendroidNetworkParameters.borrowableLevel(),
                getNetValue(_address)
            ),
            getTotalBorrowedValue(_address)
        );
    }

    // Get maximum collateral amount that can be withdrawn
    function getMaximumWithdrawableAmount(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        if (getTotalBorrowedValue(_address) == 0) {
            return getNetValue(_address);
        }
        uint initialMarginPercentage = wdiv(LendroidNetworkParameters.initialMargin(), 100);
        if (getCurrentMargin(_address) > initialMarginPercentage) {
            return sub(
                getNetValue(_address),
                wmul(
                    getTotalBorrowedValue(_address),
                    initialMarginPercentage
                )
            );
        }
        else {
            return 0;
        }
    }

    // Get maximum position amount that can be opened
    function getMaximumPositionOpenableAmount(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return sub(loanBalances[_address], positionBalances[_address]);
    }

    // authorized call to reshuffle balances
    function encumberCollateral(
            address _borrower,
            uint _loanTokenAmount
        )
        public
        stoppable
        // auth// loanmanager
        onlyLoanManager
        returns (bool)
    {
        // Check eligibility
        // lender has enough funds to lend loan
        // require(this.balance >= _loanTokenAmount);
        require(fundingBalances[address(this)] >= _loanTokenAmount);
        // Update fundingBalances
        fundingBalances[address(this)] = sub(fundingBalances[address(this)], _loanTokenAmount);
        // Update loanBalances
        loanBalances[_borrower] = add(loanBalances[_borrower], _loanTokenAmount);
        return true;
    }

    // authorized call to reshuffle balances
    function unEncumberCollateral(
            address _borrower,
            uint _loanTokenAmount,
            uint _loanTokenAmountPaid
        )
        public
        stoppable
        // auth// loanmanager
        onlyLoanManager
        returns (bool)
    {
        // Check eligibility
        // borrower has enough funds to repay loan
        require(loanBalances[_borrower] >= _loanTokenAmount);
        // Update marginAccountBalances
        loanBalances[_borrower] = sub(loanBalances[_borrower], _loanTokenAmount);
        // Update fundingBalances
        fundingBalances[address(this)] = add(fundingBalances[address(this)], _loanTokenAmountPaid);
        return true;
    }

    // authorized call to reshuffle balances
    function openPosition(
            address _borrower,
            uint _positionAmount
        )
        public
        stoppable
        // auth// positionmanager
        onlyPositionManager
        returns (bool)
    {
        // Check eligibility
        // borrower has enough margin account funds to open position
        require(sub(loanBalances[_borrower], positionBalances[_borrower]) >= _positionAmount);
        // Update positionBalances
        positionBalances[_borrower] = add(positionBalances[_borrower], _positionAmount);

        return true;
    }

    // authorized call to reshuffle balances
    function closePosition(
            address _borrower,
            uint _positionAmount
        )
        public
        stoppable
        // auth// positionmanager
        onlyPositionManager
        returns (bool)
    {
        // Check eligibility
        // Update positionBalances
        positionBalances[_borrower] = sub(positionBalances[_borrower], _positionAmount);

        return true;
    }
}
