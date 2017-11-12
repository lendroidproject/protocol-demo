pragma solidity 0.4.18;

import "./math.sol";
import "./token.sol";
import "./stop.sol";
import "./multivault.sol";

import "./NetworkParameters.sol";


contract Wallet is DSMultiVault, DSMath, DSStop {
    
    NetworkParameters LendroidNetworkParameters;

    mapping (address => uint) fundingBalances; // Simple Funding balance tracker
    mapping (address => uint) collateralBalances; // Simple Collateral balance tracker
    mapping (address => uint) tradeAccountBalances; // Simple trade account balance tracker
    mapping (address => uint) positionBalances; // Simple position balance tracker
    mapping (address => uint) wranglerBalances; // Simple Wrangler balance tracker

    /// @dev Throws if called by any account.
    function() {
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
        
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
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
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
        // push
        // push(DSToken(_token), msg.sender, _amount);
        msg.sender.transfer(_amount);
        return true;
    }

    function getCollateralBalance(
            address _address
        ) 
        public
        stoppable
        constant
        returns (uint)
    {
        return collateralBalances[_address];
    }

    function getTradeAccountBalance(
            address _address
        ) 
        public
        stoppable
        constant
        returns (uint)
    {
        return tradeAccountBalances[_address];
    }

    function getPositionBalance(
            address _address
        ) 
        public
        stoppable
        constant
        returns (uint)
    {
        return positionBalances[_address];
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
                wdiv(
                    LendroidNetworkParameters.initialMarginLevel(),
                    10 ** LendroidNetworkParameters.decimals()
                ),
                getCollateralBalance(_address)
            ),
            getTradeAccountBalance(_address)
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
        return sub(
            getCollateralBalance(_address),
            wdiv(
                getTradeAccountBalance(_address),
                wdiv(
                    LendroidNetworkParameters.initialMarginLevel(),
                    10 ** LendroidNetworkParameters.decimals()
                )
            )
        );
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
        return sub(
            wmul(
                wdiv(
                    LendroidNetworkParameters.liquidationMarginLevel(),
                    10 ** LendroidNetworkParameters.decimals()
                ),
                getCollateralBalance(_address)
            ),
            getPositionBalance(_address)
        );
    }

    // authorized call to reshuffle balances
    function encumberCollateral(
            address _borrower,
            uint _loanTokenAmount
        )
        public
        stoppable
        // auth// loanmanager
        returns (bool)
    {
        // Check eligibility
        // lender has enough funds to lend loan
        // require(this.balance >= _loanTokenAmount);
        require(fundingBalances[address(this)] >= _loanTokenAmount);
        // Update fundingBalances
        fundingBalances[address(this)] = sub(fundingBalances[address(this)], _loanTokenAmount);
        // Update tradeAccountBalances
        tradeAccountBalances[_borrower] = add(tradeAccountBalances[_borrower], _loanTokenAmount);
        
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
        returns (bool)
    {
        // Check eligibility
        // borrower has enough funds to repay loan
        require(tradeAccountBalances[_borrower] >= _loanTokenAmount);
        // Update tradeAccountBalances
        tradeAccountBalances[_borrower] = sub(tradeAccountBalances[_borrower], _loanTokenAmount);
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
        returns (bool)
    {
        // Check eligibility
        // borrower has enough margin account funds to open position
        require(tradeAccountBalances[_borrower] >= _positionAmount);
        // Update tradeAccountBalances
        tradeAccountBalances[_borrower] = sub(tradeAccountBalances[_borrower], _positionAmount);
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
        returns (bool)
    {
        // Check eligibility
        // borrower has enough margin account funds to close position
        require(positionBalances[_borrower] >= _positionAmount);
        // Update positionBalances
        positionBalances[_borrower] = sub(positionBalances[_borrower], _positionAmount);
        // Update tradeAccountBalances
        tradeAccountBalances[_borrower] = add(tradeAccountBalances[_borrower], _positionAmount);
        
        return true;
    }
}