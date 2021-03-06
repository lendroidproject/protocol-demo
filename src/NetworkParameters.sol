pragma solidity ^0.4.17;

import "ds-math/math.sol";
import "ds-stop/stop.sol";

// FOR DEMO

contract NetworkParameters is DSMath, DSStop {
    bool public tradingAllowed;
    uint public maximumAllowedMarginAccounts;
    uint public decimals;
    uint public initialMargin;
    uint public liquidationMargin;

    uint public interestRatePercentage;
    bytes32 public interestRateInterval;
    uint public maxLoanPeriodDays;
    uint public gracePeriodDays;

    bytes32 internal TOKEN_TYPE_LENDING = "lending";
    bytes32 internal TOKEN_TYPE_COLLATERAL = "collateral";
    bytes32 internal TOKEN_TYPE_TRADING = "trading";

    mapping (address => TokenMetadata) public tokens;
    mapping (bytes32 => bool) public lendingTokens;
    mapping (bytes32 => bool) public collateralTokens;
    mapping (bytes32 => bool) public tradingTokens;
    mapping (bytes32 => address) public tokenBySymbol;

    address[] public tokenAddresses;

    // Token Registry
    event LogTokenUpdated(
        address indexed token,
        bytes32 name,
        bytes32 symbol,
        uint tokenDecimals,
        Status status,
        uint value,
        bytes32 action
    );

    enum Status {
        INACTIVE, // Set to inactive when a token is deactivated
        ACTIVE    // Default status when a new token is added
    }

    struct TokenMetadata {
        address token;
        bytes32 name;
        bytes32 symbol;
        uint decimals;
        Status status;
        uint value;
    }

    modifier tokenExists(address _token) {
        require(tokens[_token].status == Status.ACTIVE);
        _;
    }

    modifier tokenDoesNotExist(address _token) {
        require(tokens[_token].status != Status.ACTIVE);
        _;
    }

    modifier symbolExists(bytes32 _symbol) {
        require(tokens[tokenBySymbol[_symbol]].status == Status.ACTIVE);
        _;
    }

    modifier addressNotNull(address _address) {
        require(_address != address(0));
        _;
    }

    function NetworkParameters() public {

        tradingAllowed = true;
        maximumAllowedMarginAccounts = 50;
        decimals = 18;
        initialMargin = 40;// Borrowable = 100 / 40 = 2.5
        liquidationMargin = 20;

        interestRatePercentage = 10;
        interestRateInterval = "day";
        maxLoanPeriodDays = 30 days;
        gracePeriodDays = 100 days;
    }

    function isValidSymbol(bytes32 _symbol)
        public
        constant
        symbolExists(_symbol)
        returns (bool)
    {
        if (tokens[tokenBySymbol[_symbol]].status == Status.ACTIVE) {
            return true;
        }
        else {
            return false;
        }
    }

    function isValidTradingSymbol(bytes32 _symbol)
        public
        constant
        symbolExists(_symbol)
        returns (bool)
    {
        return tradingTokens[_symbol];
    }

    /// @dev Allows owner to add a new token to the registry.
    /// @param _token Address of new token.
    /// @param _name Name of new token.
    /// @param _symbol Symbol for new token.
    /// @param _decimals Number of decimals, divisibility of new token.
    function addToken(
            address _token,
            bytes32 _name,
            bytes32 _symbol,
            uint _decimals,
            uint _value,
            bool isLendingToken,
            bool isCollateralToken,
            bool isTradingToken
        )
        public
        tokenDoesNotExist(_token)
        addressNotNull(_token)
        stoppable
        auth
    {
        tokens[_token] = TokenMetadata({
            token: _token,
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            status: Status.ACTIVE,
            value: _value
        });
        tokenAddresses.push(_token);
        tokenBySymbol[_symbol] = _token;

        if (isLendingToken) {
            lendingTokens[_symbol] = true;
        }
        if (isCollateralToken) {
            collateralTokens[_symbol] = true;
        }
        if (isTradingToken) {
            tradingTokens[_symbol] = true;
        }
        LogTokenUpdated(
            _token,
            _name,
            _symbol,
            _decimals,
            Status.ACTIVE,
            _value,
            "token added"
        );
    }

    function addSupport(
            bytes32 _symbol,
            bytes32[3] _tokenTypes
        )
        public
        symbolExists(_symbol)
        stoppable
        auth
        returns (bool)
    {
        if (_tokenTypes[0] == TOKEN_TYPE_LENDING) {
            lendingTokens[_symbol] = true;
        }
        if (_tokenTypes[1] == TOKEN_TYPE_COLLATERAL) {
            collateralTokens[_symbol] = true;
        }
        if (_tokenTypes[2] == TOKEN_TYPE_TRADING) {
            tradingTokens[_symbol] = true;
        }
        return true;
    }

    function removeSupport(
            bytes32 _symbol,
            bytes32[3] _tokenTypes
        )
        public
        symbolExists(_symbol)
        stoppable
        auth
        returns (bool)
    {
        if (_tokenTypes[0] == TOKEN_TYPE_LENDING) {
            lendingTokens[_symbol] = false;
        }
        if (_tokenTypes[1] == TOKEN_TYPE_COLLATERAL) {
            collateralTokens[_symbol] = false;
        }
        if (_tokenTypes[2] == TOKEN_TYPE_TRADING) {
            tradingTokens[_symbol] = false;
        }
        return true;
    }

    /// @dev Allows owner to remove an existing token from the registry.
    /// @param _token Address of existing token.
    function removeToken(
            address _token,
            uint _index
        )
        public
        tokenExists(_token)
        stoppable
        auth
    {
        require(tokenAddresses[_index] == _token);

        tokenAddresses[_index] = tokenAddresses[tokenAddresses.length - 1];
        tokenAddresses.length -= 1;

        TokenMetadata storage token = tokens[_token];

        LogTokenUpdated(
            token.token,
            token.name,
            token.symbol,
            token.decimals,
            token.status,
            token.value,
            "token removed"
        );
        delete tokenBySymbol[token.symbol];
        delete lendingTokens[token.symbol];
        delete collateralTokens[token.symbol];
        delete tradingTokens[token.symbol];
        delete tokens[_token];

    }

    /// @dev Provides a registered token's metadata, looked up by address.
    /// @param _token Address of registered token.
    /// @return Token metadata.
    function getTokenMetaData(address _token)
        public
        constant
        returns (
            address, //tokenAddress
            bytes32, //name
            bytes32, //symbol
            uint,    //decimals
            Status,  //status
            uint     //value
        )
    {
        TokenMetadata memory token = tokens[_token];
        return (
            token.token,
            token.name,
            token.symbol,
            token.decimals,
            token.status,
            token.value
        );
    }

    /// @dev Provides a registered token's metadata, looked up by symbol.
    /// @param _symbol Symbol of registered token.
    /// @return Token metadata.
    function getTokenBySymbol(bytes32 _symbol)
        public
        constant
        returns (
            address, //tokenAddress
            bytes32, //name
            bytes32, //symbol
            uint,    //decimals
            Status,  //status
            uint     //value
            )
    {
        address _token = tokenBySymbol[_symbol];
        return getTokenMetaData(_token);
    }

    /// @dev Provides a registered token's decimals, looked up by address.
    /// @param _address Address of registered token.
    /// @return Token decimals.
    function getTokenDecimalsByAddress(address _address)
        public
        constant
        returns (uint)
    {
        TokenMetadata memory token = tokens[_address];
        return token.decimals;
    }

    /// @dev Provides a registered token's decimals, looked up by symbol.
    /// @param _symbol Symbol of registered token.
    /// @return Token decimals.
    function getTokenDecimalsBySymbol(bytes32 _symbol)
        public
        constant
        returns (uint)
    {
        TokenMetadata memory token = tokens[tokenBySymbol[_symbol]];
        return token.decimals;
    }

    /// @dev Provides a registered token's address, looked up by symbol.
    /// Useful when called by an external contract
    /// @param _symbol Symbol of registered token.
    /// @return Token address.
    function getTokenAddressBySymbol(bytes32 _symbol)
        public
        constant
        returns (address)
    {
        return tokenBySymbol[_symbol];
    }


    /// @dev Provides a registered token's symbol, looked up by address.
    /// @param _address Address of registered token.
    /// @return Token symbol.
    function getTokenSymbolByAddress(address _address)
        public
        constant
        returns (bytes32)
    {
        TokenMetadata memory token = tokens[_address];
        return token.symbol;
    }

    /// @dev Returns an array containing all token addresses.
    /// @return Array of token addresses.
    function getTokenAddresses()
        public
        constant
        returns (address[])
    {
        return tokenAddresses;
    }

    function interestRate()
        public
        constant
        returns (uint)
    {
        return wmul(wdiv(interestRatePercentage, 100), 10 ** decimals);
    }

    function borrowableLevel()
        public
        constant
        returns (uint)
    {
        return wmul(wdiv(100, initialMargin), 10 ** decimals);
    }

    /**
        @notice allows the current owner to change the interestRateInterval.
        @param _i bytes32 value as the interestRateInterval
        @return true an acknowledgement that the interestRateInterval was set by the owner
    */
    function setInterestRateInterval(bytes32 _i) public auth returns (bool) {
        interestRateInterval = _i;
        return true;
    }

    /**
        @notice allows the current owner to change the interestRatePercentage.
        @param _i integer value as the interestRatePercentage
        @return true an acknowledgement that the interestRatePercentage was set by the owner
    */
    function setInterestRatePercentage(uint _i) public auth returns (bool) {
        interestRatePercentage = _i;
        return true;
    }

    /**
        @notice allows the current owner to change the daily interest rate.
        @param _d integer value as the daily interest rate
        @return true an acknowledgement that the daily interest rate was set by the owner
    */
    function setMaxLoanPeriodDays(uint _d) public auth returns (bool) {
        maxLoanPeriodDays = _d;
        return true;
    }

    /**
        @notice allows the current owner to change the grace period.
        @param _d integer value as the grace period
        @return true an acknowledgement that the grace period was set by the owner
    */
    function setGracePeriodDays(uint _d) public auth returns (bool) {
        gracePeriodDays = _d;
        return true;
    }

    /**
        @notice allows the current owner to change the initialMarginPercentage.
        @param _percentage integer value as the initialMarginPercentage
        @return true an acknowledgement that the initialMarginPercentage was set by the owner
    */
    function setInitialMarginPercentage(uint _percentage) public auth returns (bool) {
        require(_percentage <= 100);
        initialMargin = _percentage;
        return true;
    }

    /**
        @notice allows the current owner to change the liquidationMarginPercentage.
        @param _percentage integer value as the liquidationMarginPercentage
        @return true an acknowledgement that the liquidationMarginPercentage was set by the owner
    */
    function setLiquidationMarginPercentage(uint _percentage) public auth returns (bool) {
        require(_percentage <= 100);
        liquidationMargin = _percentage;
        return true;
    }
}
