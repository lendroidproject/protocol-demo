pragma solidity ^0.4.17;

import "ds-test/test.sol";

import "./ProtocolDemoTest.sol";

contract ProtocolDemoTestTest is DSTest {
    ProtocolDemoTest test;

    function setUp() public {
        test = new ProtocolDemoTest();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
