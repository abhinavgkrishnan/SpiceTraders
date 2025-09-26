// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";
import "./Tokens.sol";
import "./Player.sol";
import "./World.sol";
import "./Ships.sol";

contract Mining is Ownable, ReentrancyGuard, IEntropyConsumer {
    Tokens public tokensContract;
    Player public playerContract;
    World public worldContract;
    Ships public shipsContract;
    IEntropyV2 public entropy;

    uint256 public constant MINING_COOLDOWN = 90 seconds; // Fast engagement for better gameplay
    uint256 public constant BASE_MINING_RATE = 12; // Increased base units per cycle (20% boost)
    uint256 public constant SPICE_DIFFICULTY_MULTIPLIER = 150; // All spice mining is inherently difficult

    mapping(address => uint256) public lastMiningTimestamp;
    mapping(uint64 => address) public sequenceToPlayer;
    mapping(uint64 => uint256) public sequenceToPlanet;
    mapping(uint64 => uint256) public sequenceToShip;

    event MiningRequested(
        address indexed player,
        uint256 indexed planetId,
        uint64 indexed sequenceNumber
    );

    event Mined(
        address indexed player,
        uint256 indexed planetId,
        uint256[] resourceIds,
        uint256[] amounts
    );

    constructor(address initialOwner, address _tokens, address _player, address _world, address _ships, address _entropy)
        Ownable(initialOwner)
    {
        tokensContract = Tokens(_tokens);
        playerContract = Player(_player);
        worldContract = World(_world);
        shipsContract = Ships(_ships);
        entropy = IEntropyV2(_entropy);
    }

    function mine() external payable nonReentrant {
        address player = msg.sender;
        require(playerContract.isPlayerRegistered(player), "Player not registered");
        require(!playerContract.isPlayerTraveling(player), "Cannot mine while traveling");
        require(block.timestamp >= lastMiningTimestamp[player] + MINING_COOLDOWN, "Mining cooldown active");

        uint256 planetId = playerContract.getPlayerLocation(player);
        require(planetId > 0, "Player is not on a planet");

        uint256 shipId = playerContract.getPlayerActiveShip(player);
        Ships.ShipAttributes memory ship = shipsContract.getShipAttributes(shipId);
        require(ship.active, "Ship is not active");

        // Get the fee for the entropy request
        uint256 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee for entropy request");

        // Request random number from Pyth Entropy
        uint64 sequenceNumber = entropy.requestV2{value: fee}();

        // Store the sequence number mapping for callback
        sequenceToPlayer[sequenceNumber] = player;
        sequenceToPlanet[sequenceNumber] = planetId;
        sequenceToShip[sequenceNumber] = shipId;

        lastMiningTimestamp[player] = block.timestamp;
        playerContract.updateLastActionTimestamp(player);

        emit MiningRequested(player, planetId, sequenceNumber);

        // Refund excess payment
        if (msg.value > fee) {
            payable(player).transfer(msg.value - fee);
        }
    }

    function setEntropyAddress(address _entropy) external onlyOwner {
        entropy = IEntropyV2(_entropy);
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address, // provider - unused but required by interface
        bytes32 randomNumber
    ) internal override {
        address player = sequenceToPlayer[sequenceNumber];
        uint256 planetId = sequenceToPlanet[sequenceNumber];
        uint256 shipId = sequenceToShip[sequenceNumber];

        require(player != address(0), "Invalid sequence number");

        // Clean up mappings
        delete sequenceToPlayer[sequenceNumber];
        delete sequenceToPlanet[sequenceNumber];
        delete sequenceToShip[sequenceNumber];

        // Get ship and planet data
        Ships.ShipAttributes memory ship = shipsContract.getShipAttributes(shipId);
        World.Planet memory planet = worldContract.getPlanet(planetId);

        // Use entropy to get a random yield multiplier (50% to 150%)
        uint256 yieldMultiplier = 50 + (uint256(randomNumber) % 101);

        uint256[] memory resourceIds = new uint256[](4);
        uint256[] memory amounts = new uint256[](4);
        uint256 totalMinedAmount = 0;

        for (uint256 i = 0; i < 4; i++) {
            uint256 resourceId = i; // METAL, SAPHO_JUICE, WATER, SPICE
            uint256 concentration = planet.resourceConcentration[i];

            uint256 minedAmount = (BASE_MINING_RATE * concentration * yieldMultiplier) / (100 * 100);

            // Apply base planet difficulty
            minedAmount = (minedAmount * planet.baseMiningDifficulty) / 100;

            // Apply extra difficulty for SPICE mining (resource ID 3)
            if (resourceId == 3) { // SPICE
                minedAmount = (minedAmount * 100) / SPICE_DIFFICULTY_MULTIPLIER;
            }

            if (minedAmount > 0) {
                if (totalMinedAmount + minedAmount > ship.cargoCapacity) {
                    minedAmount = ship.cargoCapacity - totalMinedAmount;
                }

                resourceIds[i] = resourceId;
                amounts[i] = minedAmount;
                totalMinedAmount += minedAmount;
            }

            if (totalMinedAmount >= ship.cargoCapacity) {
                break;
            }
        }

        if (totalMinedAmount > 0) {
            tokensContract.mintBatch(player, resourceIds, amounts, "");
        }

        emit Mined(player, planetId, resourceIds, amounts);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function getMiningFee() external view returns (uint256) {
        return entropy.getFeeV2();
    }
}