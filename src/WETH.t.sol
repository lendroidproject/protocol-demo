pragma solidity ^0.4.10;

import "ds-test/test.sol";
import 'ds-token/base.sol';
import 'ds-token/base.t.sol';
import './WETH.sol';

contract DSEthTokenTest is DSTokenBaseTest, DSEthTokenEvents {
    function() public payable {}

    function createToken() internal returns (ERC20) {
        return new DSEthToken();
    }
    function setUp() public {
        super.setUp();
        // TokenTest precondition
        assert(token.call.value(initialBalance)());
    }

    function testDeposit() public {
        expectEventsExact(token);
        Deposit(this, 10);

        assert(token.call.value(10)(bytes4(keccak256("deposit()"))));
        assertEq(token.balanceOf(this), initialBalance + 10);
        assertEq(token.totalSupply(), initialBalance + 10);
    }

    function testWithdraw() public {
        expectEventsExact(token);
        Deposit(this, 10);
        Withdrawal(this, 5);

        var startingBalance = this.balance;
        assert(token.call.value(10)(bytes4(keccak256("deposit()"))));
        assert(DSEthToken(token).tryWithdraw(5));
        assertEq(this.balance, startingBalance - 5);
        assertEq(token.totalSupply(), initialBalance + 5);
    }

    function testAliases() public {
        var startingBalance = this.balance;

        assert(token.call.value(10)(bytes4(keccak256("wrap()"))));
        assertEq(token.balanceOf(this), initialBalance + 10);
        assertEq(this.balance, startingBalance - 10);

        DSEthToken(token).unwrap(10);
        assertEq(token.balanceOf(this), initialBalance);
        assertEq(this.balance, startingBalance);
    }

    function testWithdrawAttackRegression() public {
        var attacker = new ReentrantWithdrawalAttack(DSEthToken(token));
        assert(attacker.send(100));
        attacker.attack();
        assertEq(attacker.balance, 0);
        assertEq(token.balanceOf(attacker), 100);
    }

    function testWithdrawAttack2Regression() public {
        var attacker = new ReentrantWithdrawalAttack2(DSEthToken(token));
        assert(attacker.send(100));
        attacker.attack();
        assertEq(attacker.balance, 25);
        assertEq(token.balanceOf(attacker), 75);
    }
}

contract ReentrantWithdrawalAttack {
    DSEthToken _token;
    address _owner;
    uint _bal;

    function ReentrantWithdrawalAttack(DSEthToken token) public {
        _owner = msg.sender;
        _token = token;
    }

    function attack() public {
        _bal = this.balance;
        _token.deposit.value(_bal)();
        _token.tryWithdraw(_bal);
    }

    function() public payable {
        if (msg.sender == _owner) return;
        _token.tryWithdraw(_bal);
    }
}

// throws on 2nd entry
contract ReentrantWithdrawalAttack2 {
    DSEthToken _token;
    address _owner;
    uint _bal;
    bool _entered;

    function ReentrantWithdrawalAttack2(DSEthToken token) public {
        _owner = msg.sender;
        _token = token;
    }

    function attack() public {
        _bal = this.balance;
        _token.deposit.value(_bal)();
        _token.withdraw(_bal / 4);
    }

    function() public payable {
        if (msg.sender == _owner) return;
        if (_entered) revert();
        _entered = true;
        _token.tryWithdraw(_bal / 4);
    }
}
