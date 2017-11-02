pragma solidity 0.4.18;

import "./Ownable.sol";

contract NetworkParameters is Ownable {
    bool public tradingAllowed;
    uint public maximumAllowedMarginAccounts;
    uint public decimals;
    uint public initialMargin;
    uint public liquidationMargin;
    
    bytes32 internal TOKEN_TYPE_LENDING = "lending";
    bytes32 internal TOKEN_TYPE_COLLATERAL = "collateral";
    bytes32 internal TOKEN_TYPE_TRADING = "trading";
    
    mapping (bytes32 => mapping (address => TokenMetadata)) public tokens;
    mapping (bytes32 => address) tokenBySymbol;

    address[] public tokenAddresses;
    
    // Token Registry
    event LogTokenUpdated(
        address indexed token,
        bytes32 name,
        bytes32 symbol,
        uint decimals,
        Status status,
        uint value,
        bytes32 tokenType,
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

    modifier tokenExists(address _token, bytes32 _type) {
        require(tokens[_type][_token].status == Status.ACTIVE);
        _;
    }

    modifier tokenDoesNotExist(address _token, bytes32 _type) {
        require(tokens[_type][_token].status != Status.ACTIVE);
        _;
    }

    modifier symbolExists(bytes32 _symbol, bytes32 _type) {
        require(tokens[_type][tokenBySymbol[_symbol]].status == Status.ACTIVE);
        _;
    }

    modifier addressNotNull(address _address) {
        require(_address != address(0));
        _;
    }

    function NetworkParameters() {
        tradingAllowed = true;
        maximumAllowedMarginAccounts = 50;
        decimals = 4;
        initialMargin = 4000;
        liquidationMargin = 2000;
    }

    function isValidSymbol(bytes32 _symbol, bytes32 _type)
        public
        constant
        symbolExists(_symbol, _type) 
        returns (bool)
    {
        if (tokens[_type][tokenBySymbol[_symbol]].status == Status.ACTIVE) {
            return true;
        }
        else {
            return false;
        }
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
        bytes32 _type)
        public
        onlyOwner
        tokenDoesNotExist(_token,_type)
        addressNotNull(_token)
    {
        tokens[bytes32(_type)][_token] = TokenMetadata({
            token: _token,
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            status: Status.ACTIVE,
            value: _value
        });
        tokenAddresses.push(_token);
        tokenBySymbol[_symbol] = _token;
        
        bytes32 _action = "";
        if (_type == TOKEN_TYPE_LENDING) {
            _action = "lending token added";
        }
        if (_type == TOKEN_TYPE_COLLATERAL) {
            _action = "collateral token added";
        }
        if (_type == TOKEN_TYPE_TRADING) {
            _action = "trading token added";
        }
        LogTokenUpdated(
            _token,
            _name,
            _symbol,
            _decimals,
            Status.ACTIVE,
            _value,
            _type,
            _action
        );
    }

    /// @dev Allows owner to remove an existing token from the registry.
    /// @param _token Address of existing token.
    function removeToken(bytes32 _type, address _token, uint _index)
        public
        onlyOwner
        tokenExists(_token, _type)
    {
        require(tokenAddresses[_index] == _token);

        tokenAddresses[_index] = tokenAddresses[tokenAddresses.length - 1];
        tokenAddresses.length -= 1;

        TokenMetadata storage token = tokens[_type][_token];
        bytes32 _action = "";
        if (_type == TOKEN_TYPE_LENDING) {
            _action = "lending token removed";
        }
        if (_type == TOKEN_TYPE_COLLATERAL) {
            _action = "collateral token removed";
        }
        if (_type == TOKEN_TYPE_TRADING) {
            _action = "trading token removed";
        }
        LogTokenUpdated(
            token.token,
            token.name,
            token.symbol,
            token.decimals,
            token.status,
            token.value,
            _type,
            _action
        );
        delete tokenBySymbol[token.symbol];
        delete tokens[_type][_token];
    }

    /// @dev Provides a registered token's metadata, looked up by address.
    /// @param _token Address of registered token.
    /// @return Token metadata.
    function getTokenMetaData(address _token, bytes32 _type)
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
        TokenMetadata memory token = tokens[_type][_token];
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
    function getTokenBySymbol(bytes32 _symbol, bytes32 _type)
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
        return getTokenMetaData(_token, _type);
    }

    /// @dev Provides a registered token's decimals, looked up by address.
    /// @param _address Address of registered token.
    /// @return Token decimals.
    function getTokenDecimalsByAddress(address _address, bytes32 _type)
        public
        constant
        returns (uint)
    {
        TokenMetadata memory token = tokens[_type][_address];
        return token.decimals;
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

}