
/*
    Coinmarketcap-based price updater
    For now, this is manual. Will be updated every ~60 seconds.
*/

pragma solidity ^0.4.17;
import "./oraclizeAPI.sol";
import "./Ownable.sol";
import "../PriceFeedProviderBase.sol";
import "../PriceFeedManager.sol";

contract PriceFeedProviderCoinMarketCap is PriceFeedProviderBase, usingOraclize, Ownable {

    mapping (bytes32 => string) tokenIds;
    mapping (bytes32 => bytes32) queuedTokens;
    mapping (bytes32 => bool) validQueryIds;

    event LogSendingQuery(string description);
    event LogPriceUpdated(bytes32 indexed _symbol, string _price);
    event LogTokenIdUpdated(bytes32 indexed _symbol, string _id);

    function PriceFeedProviderCoinMarketCap() {
        oraclize_setCustomGasPrice(4000000000 wei);
    }

    function setTokenId(bytes32 _symbol, string _id) public onlyOwner returns (bool){
        LogTokenIdUpdated(_symbol, _id);
        tokenIds[_symbol] = _id;
        return true;
    }

    // // an optimization in case of network congestion
    // function setTokenIds(bytes32[] _symbols, bytes32[] _ids) public onlyOwner {
    //     require(_symbols.length == _ids.length );
    //     for(uint i = 0; i < _symbols.length; i++) {
    //         // setTokenId(_symbols[i], _ids[i]);
    //         tokenIds[_symbols[i]] = _ids[i];
    //         // TokenIdUpdated(_symbol, _id);
    //     }
    // }

    function __callback(bytes32 _qId, string result, bytes proof) {
        require(validQueryIds[_qId]);
        require(msg.sender == oraclize_cbAddress());
        LogPriceUpdated(_symbol, result);
        bytes32 _symbol = queuedTokens[_qId];
        tokenPrices[_symbol] = parseInt(result, 8);
        delete queuedTokens[_qId];
        delete validQueryIds[_qId];
    }

    function getPrice(bytes32 _symbol) public constant returns (uint) {
        return tokenPrices[_symbol];
    }

    function updatePrice(bytes32 _symbol)
        public
        isValidSymbol(_symbol)
        payable
    {
        if (oraclize_getPrice("URL") > this.balance) {
            LogSendingQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            LogSendingQuery("Oraclize query was sent, standing by for the answer..");
            string memory queryUrl = strConcat("json(https://api.coinmarketcap.com/v1/ticker/", tokenIds[_symbol], "/?convert=ETH).0.price_eth");
            bytes32 queryId = oraclize_query(60, "URL", queryUrl);
            queuedTokens[queryId] = _symbol;
            validQueryIds[queryId] = true;
        }
    }

    // @dev Payable which can be called only by the contract owner.
    // @return true the contract's balance was successfully refilled
    function refillBalance() public onlyOwner payable returns (bool) {
        return true;
    }

    // @dev Payable function which can be called only by the contract owner.
    // @return true the contract's balance was successfully withdrawn
    function withdrawBalance(uint256 _amount) public onlyOwner  returns (bool) {
        msg.sender.transfer(_amount);
        return true;
    }

}
