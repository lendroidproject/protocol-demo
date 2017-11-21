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


contract PositionManagerTest is DSTest, DSMath {
    /*contracts*/
    DSEthToken LendroidWethToken;
    DSToken OMGToken;
    Oracle LendroidOracle;
    NetworkParameters LendroidNetworkParameters;
    Wallet LendroidWallet;
    LoanManager LendroidLoanManager;
    PositionManager LendroidPositionManager;

    uint currentOMGPrice = 1355538690000000;

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
        assert(LendroidWallet.call.value(3000000000000000)(bytes4(keccak256("depositLendingFunds()"))));
    }

    function testFailOpenPositionWithoutDeposit() public {
      // Assert deposit has not been made
      assertEq(
        LendroidWallet.getMarginValue(this),
        0
      );
      // Open Position
      LendroidPositionManager.createPosition(this, "OMG", 1);// FAIL HERE
    }

    function testFailOpenPositionMoreThanOpenable() public {
      // Deposit collateral
      assert(LendroidWallet.call.value(1000000000000000)(bytes4(keccak256("depositCollateral()"))));
      // Assert maximum borrowable loan amount
      assertEq(
        LendroidWallet.getMaximumBorrowableAmount(this),
        2500000000000000
      );
      // Avail loan
      LendroidLoanManager.availLoan(2000000000000000);
      // Assert maximum openable amount
      assertEq(
        LendroidWallet.getMaximumPositionOpenableAmount(this),
        2000000000000000
      );
      // Open Position
      LendroidPositionManager.createPosition(this, "OMG", 2);// FAIL HERE
    }

    /*function testAvailLoan() public {
      // Deposit collateral
      assert(LendroidWallet.call.value(1000000000000000)(bytes4(keccak256("depositCollateral()"))));
      // Assert loan has not been availed
      assertEq(
        LendroidWallet.getTotalBorrowedValue(this),
        0
      );
      // Avail loan
      LendroidLoanManager.availLoan(1500000000000000);
      // Assert loan has been availed
      assertEq(
        LendroidWallet.getTotalBorrowedValue(this),
        1500000000000000
      );
    }*/

}
