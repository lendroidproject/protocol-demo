pragma solidity 0.4.18;

import "./math.sol";
import "./token.sol";
import "./stop.sol";
import "./multivault.sol";

import "./NetworkParameters.sol";

contract Wallet is DSMultiVault, DSMath, DSStop {
    
    NetworkParameters LendroidNetworkParameters;

    enum AccountType {
        NONE,               // Null
        FUNDING_ACCOUNT,    // Lender account
        COLLATERAL_ACCOUNT, // Trader account to manage collaterals
        POSITION_ACCOUNT,   // Trade Positions
        WRANGLER_ACCOUNT    // Wrangler
    }
    
    mapping (address => mapping (bytes32 => uint)) fundingBalances; // Funding Account, keys are Token symbols
    mapping (address => mapping (bytes32 => uint)) collateralBalances; // Collateral Account, keys are Token symbols
    mapping (address => mapping (bytes32 => uint)) positionBalances; // Trade positions, keys are position hashes
    mapping (address => mapping (bytes32 => uint)) wranglerBalances; // Wrangler Account, keys are Token symbols

    // @dev Throws if symbol is not supported
    modifier isValidSymbol(bytes32 _symbol) {
        require(LendroidNetworkParameters.isValidSymbol(_symbol));
        _;
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

    function transferToAccount(
        bytes32 _symbol,
        uint _amount,
        AccountType _fromAccountType,
        AccountType _toAccountType) 
        public
        stoppable
        isValidSymbol(_symbol)
        returns (bool)
    {
        require(_fromAccountType != _toAccountType);
        require(_toAccountType != AccountType.WRANGLER_ACCOUNT || _toAccountType != AccountType.POSITION_ACCOUNT);
        require((_fromAccountType == AccountType.FUNDING_ACCOUNT) || 
                (_fromAccountType == AccountType.COLLATERAL_ACCOUNT) || 
                (_fromAccountType == AccountType.WRANGLER_ACCOUNT));
        // from
        if (_fromAccountType == AccountType.FUNDING_ACCOUNT) {
            require(_amount >= fundingBalances[msg.sender][_symbol]);
            fundingBalances[msg.sender][_symbol] -= _amount;
        }
        if (_fromAccountType == AccountType.COLLATERAL_ACCOUNT) {
            require(_amount >= collateralBalances[msg.sender][_symbol]);
            collateralBalances[msg.sender][_symbol] -= _amount;
        }
        if (_fromAccountType == AccountType.WRANGLER_ACCOUNT) {
            require(_amount >= wranglerBalances[msg.sender][_symbol]);
            wranglerBalances[msg.sender][_symbol] -= _amount;
        }
        // to
        if (_toAccountType == AccountType.FUNDING_ACCOUNT) {
            fundingBalances[msg.sender][_symbol] += _amount;
        }
        if (_toAccountType == AccountType.COLLATERAL_ACCOUNT) {
            collateralBalances[msg.sender][_symbol] += _amount;
        }
    }
    
    // Deposit funds
    function deposit(
            bytes32 _symbol,
            uint _amount,
            AccountType _toAccountType
        ) 
        public
        stoppable
        isValidSymbol(_symbol)
        returns (bool)
    {
        require(_toAccountType == AccountType.FUNDING_ACCOUNT || _toAccountType == AccountType.COLLATERAL_ACCOUNT);
        if (_toAccountType == AccountType.FUNDING_ACCOUNT) {
            fundingBalances[msg.sender][_symbol] += _amount;
        }
        if (_toAccountType == AccountType.COLLATERAL_ACCOUNT) {
            collateralBalances[msg.sender][_symbol] += _amount;
        }
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol(_symbol);
        // pull
        pull(DSToken(_token), msg.sender, _amount);
        
        return true;
    }
    
    // Withdraw funds
    function withdraw(
            bytes32 _symbol,
            uint _amount,
            AccountType _fromAccountType
        ) 
        public
        stoppable
        isValidSymbol(_symbol)
        returns (bool)
    {
        require(_fromAccountType == AccountType.FUNDING_ACCOUNT || _fromAccountType == AccountType.COLLATERAL_ACCOUNT || _fromAccountType == AccountType.WRANGLER_ACCOUNT);
        if (_fromAccountType == AccountType.FUNDING_ACCOUNT) {
            fundingBalances[msg.sender][_symbol] -= _amount;
        }
        if (_fromAccountType == AccountType.COLLATERAL_ACCOUNT) {
            collateralBalances[msg.sender][_symbol] -= _amount;
        }
        if (_fromAccountType == AccountType.WRANGLER_ACCOUNT) {
            wranglerBalances[msg.sender][_symbol] -= _amount;
        }
        address _token = LendroidNetworkParameters.getTokenAddressBySymbol(_symbol);
        // push
        push(DSToken(_token), msg.sender, _amount);

        return true;
    }

    function getFundingBalance(
            bytes32 _symbol,
            address _address
        ) 
        public
        stoppable
        isValidSymbol(_symbol)
        constant
        returns (uint)
    {
        return fundingBalances[_address][_symbol];
    }
    
    function getCollateralBalance(
            bytes32 _symbol,
            address _address
        ) 
        public
        stoppable
        isValidSymbol(_symbol)
        constant
        returns (uint)
    {
        return collateralBalances[_address][_symbol];
    }

    // Get maximum amount that can be borrowed
    function getMaximumBorrowableAmount(
            bytes32 _collateralSymbol,
            address _address
        )
        public
        stoppable
        isValidSymbol(_collateralSymbol)
        constant
        returns (uint)
    {
        uint collateralDecimals = LendroidNetworkParameters.getTokenDecimalsBySymbol(_collateralSymbol);
        return mul(LendroidNetworkParameters.initialMargin(), (wdiv(getCollateralBalance(_collateralSymbol, _address), (10 ** collateralDecimals))));
    }

    // authorized called to reshuffle balances
    function encumberCollateral(address _borrower)
        public
        stoppable
        auth// loanmanager
        returns (bool, uint)
    {
        // Check eligibility
        // Check if borrower has enough funds to borrow loan
        uint _loanTokenAmount = getMaximumBorrowableAmount("W-ETH" ,_borrower);
        // Check if lend has enough funds to lend loan
        require(this.balance <= _loanTokenAmount);
        
        // // Update fundingBalances
        // fundingBalances[_lender][_loanSymbol] = sub(fundingBalances[_lender][_loanSymbol], _loanTokenAmount);
        // fundingBalances[_lender][_loanHash] = _loanTokenAmount;
        // // Update positionBalances
        // positionBalances[_borrower][_loanHash] = add(positionBalances[_borrower][_loanHash], _loanTokenAmount);
        // // Update collateralBalances
        // collateralBalances[_borrower][_collateralSymbol] = sub(collateralBalances[_borrower][_collateralSymbol], _collateralTokenAmount);
        // collateralBalances[_borrower][_loanHash] = add(collateralBalances[_borrower][_loanHash], _collateralTokenAmount);
        
        return (true, _loanTokenAmount);
    }

    // authorized called to reshuffle balances
    function closeLoan(
            address _loanToken,
            address _collateralToken,
            uint _loanTokenAmount,
            uint _collateralTokenAmount,
            uint _repayAmount,
            address _lender,
            address _borrower,
            bytes32 _loanHash
        )
        public
        stoppable
        auth// loanmanager
        returns (bool)
    {
        bytes32 _loanSymbol = LendroidNetworkParameters.getTokenSymbolByAddress(_loanToken);
        bytes32 _collateralSymbol = LendroidNetworkParameters.getTokenSymbolByAddress(_collateralToken);
        // Update fundingBalances
        fundingBalances[_lender][_loanSymbol] = add(fundingBalances[_lender][_loanSymbol], _repayAmount);
        delete fundingBalances[_lender][_loanHash];
        // Update positionBalances
        delete positionBalances[_borrower][_loanHash];
        // Update collateralBalances
        collateralBalances[_borrower][_collateralSymbol] = add(collateralBalances[_borrower][_collateralSymbol], _collateralTokenAmount);
        delete collateralBalances[_borrower][_loanHash];
        
        return true;
    }

}