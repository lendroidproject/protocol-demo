pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "ds-math/math.sol";

import "./WETH.sol";
import "./Oracle.sol";
import "./NetworkParameters.sol";
import "./Wallet.sol";
import "./LoanManager.sol";
import "./PositionManager.sol";

/*
# Steps to test Margin Trading calculation

Deploy contracts
————————————————
Deploy Oracle.sol as LendroidOracle
Deploy NetworkParameters.sol as LendroidNetworkParameters
Deploy Wallet.sol as LendroidWallet
Deploy LoanManager.sol as LendroidLoanManager
Deploy PositionManager.sol as LendroidPositionManager

Link contracts
——————————————
LendroidOracle.setLendroidNetworkParameters()
LendroidLoanManager.setLendroidNetworkParameters()
LendroidLoanManager.setLendroidWallet()
LendroidPositionManager.setLendroidNetworkParameters()
LendroidPositionManager.setLendroidWallet()
LendroidPositionManager.setLendroidOracle()

Update Token settings
—————————————————————
LendroidNetworkParameters.addToken(“W-ETH”, …)
LendroidNetworkParameters.addToken(“OMG”, …)
Oracle.updateTokenPrice(“OMG”, …)

Add lending funds to Wallet
———————————————————————————
LendroidWallet.depositLendingFunds(_amount)

Margin Account - Add collateral
———————————————————————————————
LendroidWallet.depositCollateral(_amount)

Margin account - Borrow Loan
————————————————————————————
LendroidLoanManager.availLoan(_amount)

Margin account - Open Position
——————————————————————————————
LendroidPositionManager.openPosition(“OMG”, _tokenAmount)

Margin account - Calculation
————————————————————————————
LendroidWallet.getTotalBorrowedAmount(_address)
LendroidWallet.getMarginValue(_address)
LendroidWallet.getNetValue(_address)
LendroidWallet.getCurrentMargin(_address)
LendroidWallet.isMarginAccountHealthy(_address)
*/


contract MarginTradingTest is DSTest, DSMath {
    /*contracts*/
    DSEthToken LendroidWethToken;
    DSToken OMGToken;
    Oracle LendroidOracle;
    NetworkParameters LendroidNetworkParameters;
    Wallet LendroidWallet;
    LoanManager LendroidLoanManager;
    PositionManager LendroidPositionManager;

    /*test values*/
    uint currentOMGPrice = 1355538690000000;
    uint lendingAmount = 3000000000000000;
    uint collateralAmount = 1000000000000000;
    uint loanAmount = 1500000000000000;

    function setUp() public {
        /*Deploy contracts*/
        LendroidWethToken = new DSEthToken();
        OMGToken = new DSToken("OMG");
        OMGToken.setName("OmiseGo");
        OMGToken.mint(1000);
        LendroidNetworkParameters = new NetworkParameters();
        LendroidOracle = new Oracle();
        LendroidWallet = new Wallet();
        LendroidLoanManager = new LoanManager();
        LendroidPositionManager = new PositionManager();
        /*Link Contracts*/
        LendroidOracle.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidLoanManager.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidLoanManager.setLendroidWallet(address(LendroidWallet));
        LendroidPositionManager.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidPositionManager.setLendroidWallet(address(LendroidWallet));
        LendroidPositionManager.setLendroidOracle(address(LendroidOracle));
        LendroidWallet.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidWallet.setLendroidLoanManager(address(LendroidLoanManager));
        LendroidWallet.setLendroidPositionManager(address(LendroidPositionManager));
        /*Update Token settings*/
        LendroidNetworkParameters.addToken(
          address(LendroidWethToken),
          "Wrapped ETH",
          "W-ETH",
          18,
          1000000000000000000,
          false,true,false
        );
        LendroidNetworkParameters.addToken(
          address(OMGToken),
          "OmiseGo",
          "OMG",
          18,
          currentOMGPrice,
          false,false,true
        );
        LendroidOracle.updateTokenPrice("OMG", currentOMGPrice);
    }

    function test_GetPrice() public {
        assertEq(LendroidOracle.getPrice("OMG"), currentOMGPrice);
    }

    function test_MarginCalculation() public {
        /*Deposit colateral*/
        assert(LendroidWallet.call.value(1000000000000000)(bytes4(keccak256("depositCollateral()"))));
        /*Check balances*/
        assertEq(
          LendroidWallet.getMarginValue(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getNetValue(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getTotalBorrowedValue(this),
          0
        );
        assertEq(
          LendroidWallet.getTotalOpenPositionsValue(this),
          0
        );
        assertEq(
          LendroidWallet.getMaximumBorrowableAmount(this),
          2500000000000000
        );
        assertEq(
          LendroidWallet.getMaximumWithdrawableAmount(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getCurrentMargin(this),
          0
        );
        assert(
          !LendroidWallet.isMarginAccountHealthy(this)
        );
        /*Deposit Lending funds*/
        assert(LendroidWallet.call.value(lendingAmount)(bytes4(keccak256("depositLendingFunds()"))));
        /*Avail Loan*/
        LendroidLoanManager.availLoan(1500000000000000);
        assertEq(
          LendroidWallet.getFundingBalance(),
          1500000000000000
        );
        assertEq(
          LendroidWallet.getMarginValue(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getNetValue(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getTotalBorrowedValue(this),
          1500000000000000
        );
        assertEq(
          LendroidWallet.getMaximumBorrowableAmount(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getMaximumWithdrawableAmount(this),
          400000000000000
        );
        /*Open Position*/
        LendroidPositionManager.createPosition(this, "OMG", 1);
        assertEq(
          LendroidWallet.getMarginValue(this),
          1000000000000000
        );
        assertEq(
          LendroidWallet.getTotalOpenPositionsValue(this),
          currentOMGPrice
        );
        assertEq(
          LendroidWallet.getNetValue(this),
          1000000000000000
        );
        assert(
          LendroidWallet.isMarginAccountHealthy(this)
        );
        uint OMGPriceChange = 755538690000000;
        currentOMGPrice -= OMGPriceChange;
        LendroidOracle.updateTokenPrice("OMG", currentOMGPrice);
        assertEq(
          LendroidWallet.getNetValue(this),
          1000000000000000 - OMGPriceChange
        );
        /*assertEq(
          LendroidWallet.getCurrentMargin(this),
          1000000000000000
        );*/
        assert(
          !LendroidWallet.isMarginAccountHealthy(this)
        );
    }
}
