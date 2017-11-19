
pragma solidity ^0.4.18;
import "./helpers/math.sol";
import "./helpers/stop.sol";

import "./NetworkParameters.sol";


contract Oracle is DSMath, DSStop {

    NetworkParameters public LendroidNetworkParameters;

    mapping (bytes32 => uint) tokenPrices;

    /// @dev Allows owner to set the NetworkParameters contract.
    /// @param _address Address of the NetworkParameters contract.
    function setLendroidNetworkParameters(address _address)
        public
        stoppable
        auth
        returns (bool) 
    {
        LendroidNetworkParameters = NetworkParameters(_address);
        return true;
    }

    function updateTokenPrice(bytes32 _symbol, uint _price)
        public
        stoppable
        auth// pricefeedmanager
        returns (bool)
    {
        tokenPrices[_symbol] = wmul(_price, 10 ** LendroidNetworkParameters.decimals());
        return true;
    }

    function getPrice(bytes32 _symbol) public constant returns (uint) {
        return tokenPrices[_symbol];
    }
}
