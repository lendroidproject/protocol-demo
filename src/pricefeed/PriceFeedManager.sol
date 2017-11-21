pragma solidity ^0.4.17;
import "ds-stop/stop.sol";

import "../NetworkParameters.sol";
import "../Oracle.sol";


/// @title Contract that contains supported Oracle. Open to Governance.
/// @author Lendroid - <vii@lendroid.io>, Inspired from 0xProject
contract PriceFeedManager is DSStop {

    NetworkParameters LendroidNetworkParameters;
    Oracle LendroidOracle;

    event LogAddProvider(
        address indexed provider,
        bytes32 name
    );

    event LogRemoveProvider(
        address indexed provider,
        bytes32 name
    );

    event LogDeactivateProvider(
        address indexed provider,
        bytes32 name
    );

    event LogActivateProvider(
        address indexed provider,
        bytes32 name
    );

    event LogProviderAddressChange(bytes32 indexed name, address oldAddress, address newAddress);

    enum Status {
        INACTIVE, // Set to inactive when a provider is deactivated
        ACTIVE    // Default status when a new provider is added
    }

    struct ProviderMetaData {
        address provider;
        bytes32 name;
        Status status;
    }

    mapping (address => ProviderMetaData) public providers;
    mapping (bytes32 => address) providerByName;
    bytes32[] public providerNames;

    modifier nameExists(bytes32 _name) {
        require(providerByName[_name] != address(0));
        _;
    }

    modifier nameDoesNotExist(bytes32 _name) {
        require(providerByName[_name] == address(0));
        _;
    }

    modifier addressNotNull(address _address) {
        require(_address != address(0));
        _;
    }

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

    /// @dev Allows owner to set the Oracle contract.
    /// @param _address Address of the Oracle contract.
    function setLendroidOracle(address _address)
        public
        stoppable
        auth
        returns (bool)
    {
        LendroidOracle = Oracle(_address);
        return true;
    }

    function isValidProvider(
        address _address)
        public
        addressNotNull(_address)
        constant
        returns (bool validProviderAddress)
    {
        if (providers[_address].status == Status.ACTIVE) {
            validProviderAddress = true;
        }
        else {
            validProviderAddress = false;
        }
    }

    /// @dev Allows PriceFeedProvider contract to update the token price.
    /// @param _symbol Token symbol of type bytes32.
    /// @param _price price value of type uint.
    function updatePriceFeed(bytes32 _symbol, uint _price)
        public
        stoppable
        returns (bool) {
        require(isValidProvider(msg.sender));
        require(LendroidOracle.updateTokenPrice(_symbol, _price));
        return true;
    }

    /// @dev Allows owner to add a new provider to the registry.
    /// @param _provider Address of new provider.
    /// @param _name Name of new provider.
    function addProvider(
        address _provider,
        bytes32 _name)
        public
        addressNotNull(_provider)
        nameDoesNotExist(_name)
        stoppable
        auth// owner
    {
        providers[_provider] = ProviderMetaData({
            provider: _provider,
            name: _name,
            status: Status.ACTIVE
        });
        providerNames.push(_name);
        providerByName[_name] = _provider;
        LogAddProvider(
            _provider,
            _name
        );
    }

    /// @dev Allows owner to remove an existing provider from the registry.
    /// @param _name Name of existing provider.
    function removeProvider(bytes32 _name, uint _index)
        public
        nameExists(_name)
        stoppable
        auth
    {
        require(providerNames[_index] == _name);

        providerNames[_index] = providerNames[providerNames.length - 1];
        providerNames.length -= 1;

        ProviderMetaData storage provider = providers[providerByName[_name]];
        LogRemoveProvider(
            provider.provider,
            provider.name
        );
        delete providers[providerByName[_name]];
        delete providerByName[_name];
    }

    /// @dev Allows owner to deactivate an existing provider.
    /// @param _name Name of existing provider.
    function deactivateProvider(bytes32 _name)
        public
        nameExists(_name)
        stoppable
        auth
        returns (bool)
    {
        ProviderMetaData storage provider = providers[providerByName[_name]];
        LogDeactivateProvider(
            provider.provider,
            provider.name
        );
        provider.status = Status.INACTIVE;
        return true;
    }

    /// @dev Allows owner to activate an existing provider.
    /// @param _name Name of existing provider.
    function activateProvider(bytes32 _name)
        public
        nameExists(_name)
        stoppable
        auth
    {
        ProviderMetaData storage provider = providers[providerByName[_name]];
        LogActivateProvider(
            provider.provider,
            provider.name
        );
        provider.status = Status.ACTIVE;
    }

    function getProviderMetaData(bytes32 _name)
        public
        constant
        returns (
            address, //providerAddress
            bytes32,  //name
            Status   //status
        )
    {
        ProviderMetaData memory provider = providers[providerByName[_name]];
        return (
            provider.provider,
            provider.name,
            provider.status
        );
    }

}
