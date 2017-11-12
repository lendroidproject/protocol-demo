pragma solidity ^0.4.2;

import './math.sol';
import './stop.sol';

import './Wallet.sol';
import "./NetworkParameters.sol";
import "./Oracle.sol";

/**
    @title PositionManager
    @notice The PositionManager contract inherits the DSMath & DSStop contracts, 
        and manages trade positions on Lendroid.
 */
contract PositionManager is DSMath, DSStop {

    Wallet public LendroidWallet;
    NetworkParameters public LendroidNetworkParameters;
    Oracle public LendroidOracle;

    enum Status {
        UNISSUED,
        ACTIVE,
        CLOSED,
        DEFAULTED
    }

    struct Position {
        uint timestamp;
        bytes32 orderHash;
        bytes32 makerTokenSymbol;
        bytes32 takerTokenSymbol;
        uint makerTokenAmount;
        uint takerTokenAmount;
        uint makerTokenOpeningRate;
        uint takerTokenOpeningRate;
        bytes32 positionHash;
        uint positionId;
        Status status;
    }

    mapping (bytes32 => Position) positions;
    mapping (address => bytes32[]) accountpositions; // Trade positions array per address

    event LogPositionUpdated(
        bytes32 _positionHash,  // The Hash of the Position
        address _address,       // The address that caused the action
        bytes32 _action         // The tyoe of action: "position opened", "position closed"
    );

    function percentOf(uint _quantity, uint _percentage) internal view returns (uint256){
        return wdiv(wmul(_quantity, _percentage), 10 ** LendroidNetworkParameters.decimals());
    }

    /**
        @dev Throws if called by any account.
    */
    function() {
        revert();
    }

    /// @dev Allows owner to set the NetworkParameters contract.
    /// @param _address Address of the NetworkParameters contract.
    function setLendroidNetworkParameters(address _address)
        public
        stoppable
        auth// owner
        returns (bool) 
    {
        LendroidNetworkParameters = NetworkParameters(_address);
        return true;
    }

    /// @dev Allows owner to set the Wallet contract.
    /// @param _address Address of the Wallet contract.
    function setLendroidWallet(address _address)
        public
        stoppable
        auth// owner
        returns (bool) 
    {
        LendroidWallet = Wallet(_address);
        return true;
    }

    /// @dev Allows owner to set the Oracle contract.
    /// @param _address Address of the Oracle contract.
    function setLendroidOracle(address _address)
        public 
        stoppable
        auth// owner
        returns (bool)
    {
        LendroidOracle = Oracle(_address);
        return true;
    }

    function createPosition(
            bytes32 _orderHash,
            address _borrower,
            bytes32 _makerTokenSymbol,
            bytes32 _takerTokenSymbol,
            uint _makerTokenAmount,
            uint _takerTokenAmount
        )
        public
        stoppable
        // auth// ordermanager
        returns (bool)
    {
        // TODO: Check if borrower account is healthy
        // Calculate WETH rate and verify if borrower can open a positiCalculate
        uint _maxAmount = LendroidWallet.getMaximumPositionOpenableAmount(_borrower);
        uint _positionTokenOpeningRate = LendroidOracle.getPrice(_takerTokenSymbol);
        uint _positionAmount = wmul(_positionTokenOpeningRate, _takerTokenAmount);
        require(_maxAmount >= _positionAmount);
        // Update balances
        require(LendroidWallet.openPosition(msg.sender, _positionAmount));
        // Open a position
        Position memory position;
        position.timestamp = now;
        position.orderHash = _orderHash;
        position.makerTokenSymbol = _makerTokenSymbol;
        position.takerTokenSymbol = _takerTokenSymbol;
        position.makerTokenAmount = _makerTokenAmount;
        position.takerTokenAmount = _takerTokenAmount;
        position.positionId = accountpositions[msg.sender].length;
        position.positionHash = getPositionHash(
            position.timestamp,
            position.orderHash,
            position.makerTokenSymbol,
            position.takerTokenSymbol,
            position.makerTokenAmount,
            position.takerTokenAmount,
            position.positionId
        );
        position.status = Status.ACTIVE;
        // Add current market rate of tokens wrt WETH
        position.makerTokenOpeningRate = LendroidOracle.getPrice(_makerTokenSymbol);
        position.takerTokenOpeningRate = _positionTokenOpeningRate;
        // Save position
        positions[position.positionHash] = position;
        accountpositions[msg.sender].push(position.positionHash);
        // Log position update
        
        return true;
    }
    
    function closePosition(bytes32 _positionHash) 
        public
        payable 
        stoppable
        returns (bool) 
    {
        // TODO: Check if borrower account is healthy
        // Get position based on hash
        Position storage position = positions[_positionHash];
        return true;
    }

    /// @return Keccak-256 hash of position.
    function getPositionHash(
            uint timestamp,
            bytes32 orderHash,
            bytes32 makerTokenSymbol,
            bytes32 takerTokenSymbol,
            uint makerTokenAmount,
            uint takerTokenAmount,
            uint positionId
        )
        internal
        constant
        returns (bytes32)
    {
        return keccak256(
            address(this),
            timestamp,
            orderHash,
            makerTokenSymbol,
            takerTokenSymbol,
            makerTokenAmount,
            takerTokenAmount,
            positionId
        );
    }

    function positionHealth(bytes32 _positionHash)
        public
        stoppable
        constant
        returns (bytes32, uint)
    {
        Position storage position = positions[_positionHash];
        require (position.status == Status.ACTIVE);
        uint openingTotal = add(
            mul(position.makerTokenAmount, position.makerTokenOpeningRate),
            mul(position.takerTokenAmount, position.takerTokenOpeningRate)
        );
        uint currentTotal = add(
            mul(position.makerTokenAmount, LendroidOracle.getPrice(position.makerTokenSymbol)),
            mul(position.takerTokenAmount, LendroidOracle.getPrice(position.takerTokenSymbol))
        );
        if (openingTotal > currentTotal) {
            return ("decreasing", sub(openingTotal, currentTotal));
        }
        if (currentTotal > openingTotal) {
            return ("increasing", sub(currentTotal, openingTotal));
        }
        if (currentTotal == openingTotal) {
            return ("equal", 0);
        }
        return ("invalid", 0);
    }

}