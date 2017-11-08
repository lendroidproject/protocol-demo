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
    mapping (address => uint) marginAccountBalances; // Simple margin account balance tracker
    mapping (address => mapping (bytes32 => uint)) positionBalances; // Trade positions, keys are position hashes
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
        add(fundingBalances[address(this)], msg.value);
        return true;
    }
    
    function depositCollateral() 
        public
        stoppable
        payable
        returns (bool)
    {
        
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
        // pull
        pull(DSToken(_token), msg.sender, msg.value);
        add(collateralBalances[msg.sender], msg.value);
        return true;
    }
    
    // Withdraw funds
    function withdrawCollateral(uint _amount) 
        public
        stoppable
        returns (bool)
    {
        // TODO: Verify margin account is healthy
        require(_amount >= collateralBalances[msg.sender]);
        sub(collateralBalances[msg.sender], _amount);
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol("W-ETH");
        // push
        push(DSToken(_token), msg.sender, _amount);
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

    // Get maximum amount that can be borrowed
    function getMaximumBorrowableAmount(
            address _address
        )
        public
        stoppable
        constant
        returns (uint)
    {
        return mul(LendroidNetworkParameters.initialMarginLevel(), getCollateralBalance(_address));
    }

    // authorized call to reshuffle balances
    function encumberCollateral(
            address _borrower,
            uint _loanTokenAmount
        )
        public
        stoppable
        auth// loanmanager
        view
        returns (bool)
    {
        // Check eligibility
        // lender has enough funds to lend loan
        require(this.balance >= _loanTokenAmount);
        require(fundingBalances[address(this)] >= _loanTokenAmount);
        // Update fundingBalances
        sub(fundingBalances[address(this)], _loanTokenAmount);
        // Update loanBalances
        add(marginAccountBalances[_borrower], _loanTokenAmount);
        
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
        auth// loanmanager
        view
        returns (bool)
    {
        // Check eligibility
        // borrower has enough funds to repay loan
        require(marginAccountBalances[_borrower] >= _loanTokenAmount);
        // Update loanBalances
        sub(marginAccountBalances[_borrower], _loanTokenAmount);
        // Update fundingBalances
        add(fundingBalances[address(this)], _loanTokenAmountPaid);
        
        return true;
    }

}