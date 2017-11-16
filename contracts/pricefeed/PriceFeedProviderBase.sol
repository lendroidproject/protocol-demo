
/*
    Coinmarketcap-based price updater
    For now, this is manual. Will be updated every ~60 seconds.
*/

pragma solidity ^0.4.18;
import "../helpers/stop.sol";
import "../NetworkParameters.sol";
import "./PriceFeedManager.sol";


contract PriceFeedProviderBase is DSStop {

    mapping (bytes32 => uint) tokenPrices;

    NetworkParameters LendroidNetworkParameters;
    PriceFeedManager LendroidPriceFeedManager;

    modifier isValidSymbol(bytes32 _symbol) {
        require(LendroidNetworkParameters.isValidSymbol(_symbol));
        _;
    }

    /// @dev Allows owner to set the PriceFeedManager contract.
    /// @param _address Address of the PriceFeedManager contract.
    function setLendroidPriceFeedManager(address _address) public
        stoppable
        auth
        returns (bool)
    {
        LendroidPriceFeedManager = PriceFeedManager(_address);
        return true;
    }

    function setLendroidNetworkParameters(address _address) public
        stoppable
        auth
        returns (bool)
    {
        LendroidNetworkParameters = NetworkParameters(_address);
        return true;
    }

    function getDecimalsBySymbol(bytes32 _symbol) internal constant returns (uint) {
        return LendroidNetworkParameters.getTokenDecimalsBySymbol(_symbol);
    }

    function getDecimalsByAddress(address _address) internal constant returns (uint) {
        return LendroidNetworkParameters.getTokenDecimalsByAddress(_address);
    }

    function updateLendroidPriceFeed(bytes32 _symbol) public returns (bool){
        return LendroidPriceFeedManager.updatePriceFeed(_symbol, tokenPrices[_symbol]);
    }

}
