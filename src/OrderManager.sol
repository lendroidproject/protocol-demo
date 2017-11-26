pragma solidity ^0.4.17;

import 'ds-math/math.sol';
import 'ds-stop/stop.sol';

import './PositionManager.sol';
import "./NetworkParameters.sol";

/**
    @title OrderManager
    @notice The OrderManager contract inherits the DSMath & DSStop contracts.
        It just accepts 0x orders and opens / closes positions.
 */
contract OrderManager is DSMath, DSStop {

    PositionManager public LendroidPositionManager;
    NetworkParameters public LendroidNetworkParameters;

    enum Status {
        UNISSUED,
        FILLABLE,
        FILLED,
        CLOSED,
        DEFAULTED
    }

    struct Order {
        uint timestamp;
        address maker;
        address taker;
        bytes32 makerTokenSymbol;
        bytes32 takerTokenSymbol;
        address makerToken;
        address takerToken;
        uint makerTokenAmount;
        uint takerTokenAmount;
        uint lastUpdated;
        uint expiresOn;
        Status status;
        bytes32 orderHash;
    }

    mapping (bytes32 => Order) public orders;

    event LogOrderUpdated(
        bytes32 _orderHash,         // The Hash of the Order
        address _maker,             // The address of maker
        address _taker,             // The address of taker
        bytes32 _makerTokenSymbol,  // The symbol of maker token
        bytes32 _takerTokenSymbol,  // The symbol of taker token
        address _makerToken,        // The token address of maker token
        address _takerToken,        // The token address of taker token
        uint _makerTokenAmount,  // The amount of maker token
        uint _takerTokenAmount,  // The amount of taker token
        bytes32 _action             // The type of action: "trade opened", "trade closed"
    );

    function percentOf(uint _quantity, uint _percentage) internal view returns (uint256){
        return wdiv(wmul(_quantity, _percentage), 10 ** LendroidNetworkParameters.decimals());
    }

    /**
        @dev Throws if called by any account.
    */
    function() public {
        revert();
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

    /// @dev Allows owner to set the PositionManager contract.
    /// @param _address Address of the PositionManager contract.
    function setLendroidPositionManager(address _address)
        public
        stoppable
        auth
        returns (bool)
    {
        LendroidPositionManager = PositionManager(_address);
        return true;
    }

    /**
        @notice Create a new order. Sender is the maker
        @return true the order was successfully created
    */
    function createOrder(
            bytes32 _makerTokenSymbol,
            bytes32 _takerTokenSymbol,
            uint _makerTokenAmount,
            uint _takerTokenAmount
        )
        public
        stoppable
        returns (bool)
    {
        // Validate inputs
        require(LendroidNetworkParameters.isValidTradingSymbol(_makerTokenSymbol));
        require(LendroidNetworkParameters.isValidTradingSymbol(_takerTokenSymbol));
        address _makerToken = LendroidNetworkParameters.getTokenAddressBySymbol(_makerTokenSymbol);
        address _takerToken = LendroidNetworkParameters.getTokenAddressBySymbol(_takerTokenSymbol);
        require((_makerTokenAmount > 0) && (_takerTokenAmount > 0));
        // Create order
        Order memory order;
        order.timestamp = now;
        order.maker = msg.sender;
        order.makerTokenSymbol = _makerTokenSymbol;
        order.takerTokenSymbol = _takerTokenSymbol;
        order.makerToken = _makerToken;
        order.takerToken = _takerToken;
        order.makerTokenAmount = _makerTokenAmount;
        order.takerTokenAmount = _takerTokenAmount;
        order.expiresOn = now + LendroidNetworkParameters.maxLoanPeriodDays();
        order.status = Status.FILLABLE;
        order.orderHash = getOrderHash(
            order.timestamp,
            order.maker,
            order.makerTokenSymbol,
            order.takerTokenSymbol,
            order.makerToken,
            order.takerToken,
            order.makerTokenAmount,
            order.takerTokenAmount,
            order.expiresOn
        );
        // Save order
        orders[order.orderHash] = order;
        // Log update
        LogOrderUpdated(
            order.orderHash,         // The Hash of the Order
            order.maker,             // The address of maker
            address(0),             // The address of taker
            order.makerTokenSymbol,  // The symbol of maker token
            order.takerTokenSymbol,  // The symbol of taker token
            order.makerToken,        // The token address of maker token
            order.takerToken,        // The token address of taker token
            order.makerTokenAmount,  // The amount of maker token
            order.takerTokenAmount,  // The amount of taker token
            "order created"
        );
        return true;
    }

    /**
        @notice Fill an existing order. Sender is the taker
        @return true the order was successfully filled
    */
    function fillOrder(
            bytes32 _orderHash
        )
        public
        stoppable
        returns (bool)
    {
        Order storage order = orders[_orderHash];
        // Confirm order is available
        require(order.status == Status.FILLABLE);
        require(order.expiresOn <= now);
        // Open position
        require(LendroidPositionManager.createPosition(
                msg.sender,
                order.takerTokenSymbol,
                order.takerTokenAmount
            )
        );
        // Update order
        order.taker = msg.sender;
        order.status = Status.FILLED;
        order.lastUpdated = now;
        return true;
    }

    /// @return Keccak-256 hash of trade.
    function getOrderHash(
            uint timestamp,
            address maker,
            bytes32 makerTokenSymbol,
            bytes32 takerTokenSymbol,
            address makerToken,
            address takerToken,
            uint makerTokenAmount,
            uint takerTokenAmount,
            uint expiresOn
        )
        internal
        constant
        returns (bytes32)
    {
        return keccak256(
            address(this),
            timestamp,
            maker,
            makerTokenSymbol,
            takerTokenSymbol,
            makerToken,
            takerToken,
            makerTokenAmount,
            takerTokenAmount,
            expiresOn
        );
    }

    /**
        @param _orderHash the hash of the order whose availability is checked for
        @return bool : order availability
    */
    function isOrderFillable(bytes32 _orderHash)
        public
        stoppable
        constant
        returns (bool)
    {
        Order storage order = orders[_orderHash];
        return ((order.expiresOn < now) && (order.status == Status.FILLABLE));
    }

}
