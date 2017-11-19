pragma solidity ^0.4.2;

import './helpers/math.sol';
import './helpers/stop.sol';

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
        address trader;
        bytes32 tokenSymbol;
        uint tokenAmount;
        uint openingRate;
        uint positionAmount;
        bytes32 positionHash;
        uint positionId;
        Status status;
        uint lastUpdated;
    }

    mapping (bytes32 => Position) public positions;
    mapping (address => bytes32[]) openPositions; // Open trade positions array per address

    event LogPositionUpdated(
        bytes32 _positionHash,  // The Hash of the Position
        address _address,       // The address that caused the action
        bytes32 _action         // The tyoe of action: "position opened", "position closed"
    );

    modifier onlyLendroidWallet() {
        require(msg.sender == address(LendroidWallet));
        _;
    }

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
            address _trader,
            bytes32 _tokenSymbol,
            uint _tokenAmount
        )
        public
        stoppable
        // auth// ordermanager
        returns (bool)
    {
        // TODO: Check if trader account is healthy
        // Calculate WETH rate and verify if borrower can open a position
        uint _maxAmount = LendroidWallet.getMaximumPositionOpenableAmount(_trader);
        uint _tokenRate = LendroidOracle.getPrice(_tokenSymbol);
        uint _positionAmount = wmul(
            _tokenRate,
            mul(
                _tokenAmount,
                10 ** LendroidNetworkParameters.getTokenDecimalsBySymbol(_tokenSymbol)
            )
        );
        require(_maxAmount >= _positionAmount);
        // Update balances
        require(LendroidWallet.openPosition(msg.sender, _positionAmount));
        // Open a position
        Position memory position;
        position.timestamp = now;
        position.trader = _trader;
        position.tokenSymbol = _tokenSymbol;
        position.tokenAmount = _tokenAmount;
        position.openingRate = _tokenRate;
        position.positionAmount = _positionAmount;
        position.positionId = openPositions[msg.sender].length;
        position.positionHash = getPositionHash(
            position.timestamp,
            position.trader,
            position.tokenSymbol,
            position.tokenAmount,
            position.positionId
        );
        position.status = Status.ACTIVE;
        // Save position
        positions[position.positionHash] = position;
        openPositions[msg.sender].push(position.positionHash);
        // Log position update
        LogPositionUpdated(
            position.positionHash,
            _trader,
            "position opened"
        );

        return true;
    }

    function closePosition(
            bytes32 _positionHash,
            address _trader
        )
        public
        stoppable
        returns (bool)
    {
        // TODO: Check if borrower account is healthy
        // Get position based on hash
        Position storage position = positions[_positionHash];
        // Validations
        // Verify trader
        require(position.trader == msg.sender);
        // Update balances
        uint _positionAmount = wmul(
            LendroidOracle.getPrice(position.tokenSymbol),
            mul(
                position.tokenAmount,
                10 ** LendroidNetworkParameters.getTokenDecimalsBySymbol(position.tokenSymbol)
            )
        );
        require(LendroidWallet.closePosition(position.trader, _positionAmount));
        // Archive the active position
        position.status = Status.CLOSED;
        position.lastUpdated = now;
        openPositions[_trader][position.positionId] = openPositions[_trader][openPositions[_trader].length - 1];
        openPositions[_trader].length--;
        LogPositionUpdated(
            _positionHash,
            _trader,
            "position opened"
        );
        return true;
    }

    /// @return Keccak-256 hash of position.
    function getPositionHash(
            uint timestamp,
            address trader,
            bytes32 tokenSymbol,
            uint tokenAmount,
            uint positionId
        )
        internal
        constant
        returns (bytes32)
    {
        return keccak256(
            address(this),
            timestamp,
            trader,
            tokenSymbol,
            tokenAmount,
            positionId
        );
    }

    function unRealizedPL(bytes32 _positionHash)
        public
        stoppable
        constant
        returns (uint)
    {
        Position storage position = positions[_positionHash];
        require (position.status == Status.ACTIVE);
        return mul(position.tokenAmount, LendroidOracle.getPrice(position.tokenSymbol));
    }

    function unRealizedPLs(address _trader)
        public
        stoppable
        onlyLendroidWallet
        constant
        returns (uint)
    {
        uint totalPLs = 0;
        for (uint positionId = 0; positionId < openPositions[_trader].length; positionId++) {
            totalPLs = add(totalPLs, unRealizedPL(openPositions[_trader][positionId]));
        }

        return totalPLs;
    }

    /**
        @param _trader the address that has opened positions
        @return bytes32[] array of position hashes
    */
    function positionsOpened(address _trader)
        public
        stoppable
        constant
        returns (bytes32[]) {
            return openPositions[_trader];
        }

}
