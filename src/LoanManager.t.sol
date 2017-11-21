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


contract LoanManagerTest is DSTest, DSMath {
    /*contracts*/
    Oracle LendroidOracle;
    NetworkParameters LendroidNetworkParameters;
    Wallet LendroidWallet;
    LoanManager LendroidLoanManager;
    PositionManager LendroidPositionManager;

    function setUp() public {
        /*Deploy contracts*/
        LendroidNetworkParameters = new NetworkParameters();
        LendroidOracle = new Oracle();
        LendroidWallet = new Wallet();
        LendroidLoanManager = new LoanManager();
        LendroidPositionManager = new PositionManager();
        /*Link Contracts*/
        LendroidLoanManager.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidLoanManager.setLendroidWallet(address(LendroidWallet));
        LendroidPositionManager.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidPositionManager.setLendroidWallet(address(LendroidWallet));
        LendroidPositionManager.setLendroidOracle(address(LendroidOracle));
        LendroidWallet.setLendroidNetworkParameters(address(LendroidNetworkParameters));
        LendroidWallet.setLendroidLoanManager(address(LendroidLoanManager));
        LendroidWallet.setLendroidPositionManager(address(LendroidPositionManager));
        assert(LendroidWallet.call.value(3000000000000000)(bytes4(keccak256("depositLendingFunds()"))));
    }

    function testFailAvailLoanWithoutDeposit() public {
      // Assert deposit has not been made
      assertEq(
        LendroidWallet.getMarginValue(this),
        0
      );
      // Avail loan
      LendroidLoanManager.availLoan(1500000000000000);// FAIL HERE
    }

    function testFailAvailLoanMoreThanBorrowable() public {
      // Deposit collateral
      assert(LendroidWallet.call.value(1000000000000000)(bytes4(keccak256("depositCollateral()"))));
      // Assert maximum borrowable loan amount
      assertEq(
        LendroidWallet.getMaximumBorrowableAmount(this),
        2500000000000000
      );
      // Avail loan
      LendroidLoanManager.availLoan(3000000000000000);// FAIL HERE
    }

    function testAvailLoan() public {
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
    }

}
