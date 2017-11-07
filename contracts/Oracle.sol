
/*
    Coinmarketcap-based price updater
    For now, this is manual. Will be updated every ~60 seconds.
*/

pragma solidity ^0.4.18;
import "./stop.sol";

contract Oracle is DSStop {

    mapping (bytes32 => uint) tokenPrices;

    function updateTokenPrice(bytes32 _symbol, uint _price) 
        public 
        stoppable
        auth// pricefeedmanager
        returns (bool)
    {
        tokenPrices[_symbol] = _price;
        return true;
    }
    
    function getPrice(bytes32 _symbol) public constant returns (uint) {
        return tokenPrices[_symbol];
    }
}