
/*
    Coinmarketcap-based price updater
    For now, this is manual. Will be updated every ~60 seconds.
*/

pragma solidity ^0.4.18;
import "./Ownable.sol";
import "./PriceFeedManager.sol";

contract PriceOracle is Ownable {

    mapping (bytes32 => uint) tokenPrices;
    
    PriceFeedManager LendroidPriceFeedManager;
    
    function PriceFeed() {}

    // @dev Throws if called by any account other than the owner.
    modifier onlyLendroidPriceFeedManager() {
        require(msg.sender == address(LendroidPriceFeedManager));
        _;
    }

    /// @dev Allows owner to set the PriceFeedManager contract.
    /// @param _address Address of the PriceFeedManager contract.
    function setLendroidPriceFeedManager(address _address) public onlyOwner returns (bool) {
        LendroidPriceFeedManager = PriceFeedManager(_address);
        return true;
    }

    function updateTokenPrice(bytes32 _symbol, uint _price) 
        public 
        onlyLendroidPriceFeedManager
        returns (bool)
    {
        tokenPrices[_symbol] = _price;
        return true;
    }
    
    function getPrice(bytes32 _symbol) public constant returns (uint) {
        return tokenPrices[_symbol];
    }
}