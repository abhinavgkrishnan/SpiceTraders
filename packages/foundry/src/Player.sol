// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./World.sol";
import "./Ships.sol";
import "./Credits.sol";
import "./Tokens.sol";

contract Player is Ownable, ReentrancyGuard {
    struct PlayerState {
        address playerAddress;          // 20 bytes
        uint64 activeShipId;            // 8 bytes  - supports up to 18 quintillion ships
        uint8 currentPlanetId;          // 1 byte   - supports up to 255 planets
        uint8 currentTripToPlanetId;    // 1 byte   - packed with currentPlanetId
        uint40 lastActionTimestamp;     // 5 bytes  - valid until year 36,812
        uint40 currentTripStartTime;    // 5 bytes  - packed in slot 2
        uint40 currentTripEndTime;      // 5 bytes  - packed in slot 2
        uint256[] shipIds;              // All ships owned by the player
    }

    World public worldContract;
    Ships public shipsContract;
    Credits public creditsContract;
    Tokens public tokensContract;

    mapping(address => PlayerState) public playerStates;
    mapping(address => bool) public isPlayerRegistered;

    event PlayerRegistered(address indexed player, uint256 startPlanetId);
    event PlayerLocationChanged(address indexed player, uint256 newPlanetId, uint256 activeShipId);
    event ActiveShipChanged(address indexed player, uint256 newActiveShipId);
    event PlayerTripStarted(address indexed player, uint256 fromPlanet, uint256 toPlanet, uint256 endTime);
    event ShipRefueled(address indexed player, uint256 shipId, uint256 spiceAmount);

    constructor(address initialOwner, address _worldContract, address _shipsContract, address _creditsContract, address _tokensContract) Ownable(initialOwner) {
        worldContract = World(_worldContract);
        shipsContract = Ships(_shipsContract);
        creditsContract = Credits(_creditsContract);
        tokensContract = Tokens(_tokensContract);
    }

    function registerPlayer(address player, uint256 startPlanetId, uint256 startShipId) external onlyOwner {
        require(!isPlayerRegistered[player], "Player already registered");
        require(startPlanetId > 0 && startPlanetId <= worldContract.planetCount(), "Invalid start planet");
        require(shipsContract.ownerOf(startShipId) == player, "Player does not own start ship");

        playerStates[player].playerAddress = player;
        playerStates[player].currentPlanetId = uint8(startPlanetId);
        playerStates[player].activeShipId = uint64(startShipId);
        playerStates[player].shipIds.push(startShipId);
        playerStates[player].lastActionTimestamp = uint40(block.timestamp);

        isPlayerRegistered[player] = true;
        emit PlayerRegistered(player, startPlanetId);
    }

    function onboardNewPlayer(address player, string calldata shipName) external nonReentrant {
        require(!isPlayerRegistered[player], "Player already registered");

        // Mint starter credits (1500 Solaris)
        creditsContract.mintStarterAmount(player);

        // Mint starter ship (Atreides Scout with full spice tank)
        uint256 shipId = shipsContract.mintStarterShip(player, shipName);

        // Register player on Caladan (planet ID 1)
        uint256 startPlanetId = 1;

        playerStates[player].playerAddress = player;
        playerStates[player].currentPlanetId = uint8(startPlanetId);
        playerStates[player].activeShipId = uint64(shipId);
        playerStates[player].shipIds.push(shipId);
        playerStates[player].lastActionTimestamp = uint40(block.timestamp);

        isPlayerRegistered[player] = true;
        emit PlayerRegistered(player, startPlanetId);
    }

    function setActiveShip(uint256 shipId) external {
        require(isPlayerRegistered[msg.sender], "Player not registered");
        require(shipsContract.ownerOf(shipId) == msg.sender, "Player does not own this ship");
        require(!isPlayerTraveling(msg.sender), "Cannot change ships during travel");

        playerStates[msg.sender].activeShipId = uint64(shipId);
        emit ActiveShipChanged(msg.sender, shipId);
    }

    function addShipToPlayer(address player, uint256 shipId) external onlyOwner {
        require(isPlayerRegistered[player], "Player not registered");
        require(shipsContract.ownerOf(shipId) == player, "Player does not own this ship");

        playerStates[player].shipIds.push(shipId);
    }

    function buyShip(string calldata shipName, uint256 shipClass) external nonReentrant {
        require(isPlayerRegistered[msg.sender], "Player not registered");
        require(!isPlayerTraveling(msg.sender), "Cannot buy ships during travel");

        uint256 price = shipsContract.getShipPrice(shipClass);
        require(creditsContract.balanceOf(msg.sender) >= price, "Insufficient credits");

        // Transfer credits from player to Ships contract owner
        creditsContract.transferFrom(msg.sender, owner(), price);

        // Mint the ship directly since we handled payment
        uint256 shipId = shipsContract.mintShip(msg.sender, shipName, shipClass);

        // Add ship to player's fleet
        playerStates[msg.sender].shipIds.push(shipId);
    }

    function refuelShip(uint256 shipId, uint256 spiceAmount) external nonReentrant {
        require(isPlayerRegistered[msg.sender], "Player not registered");
        require(shipsContract.ownerOf(shipId) == msg.sender, "Player does not own this ship");
        require(!isPlayerTraveling(msg.sender), "Cannot refuel during travel");
        require(spiceAmount > 0, "Amount must be greater than zero");

        // Check player has enough SPICE tokens (token ID 3)
        require(tokensContract.balanceOf(msg.sender, 3) >= spiceAmount, "Insufficient SPICE tokens");

        // Burn SPICE tokens from player inventory
        tokensContract.burn(msg.sender, 3, spiceAmount);

        // Refill ship with spice (capped at ship's max capacity)
        shipsContract.refillSpice(shipId, spiceAmount);

        emit ShipRefueled(msg.sender, shipId, spiceAmount);
    }


    function instantTravel(uint256 toPlanetId) external nonReentrant {
        address player = msg.sender;
        require(isPlayerRegistered[player], "Player not registered");
        require(!isPlayerTraveling(player), "Player is already traveling");

        uint256 fromPlanetId = playerStates[player].currentPlanetId;
        require(fromPlanetId != toPlanetId, "Cannot travel to the same planet");

        // Get travel cost from World contract
        World.TravelCost memory cost = worldContract.getTravelCost(fromPlanetId, toPlanetId);
        require(cost.spiceCost > 0 || fromPlanetId == toPlanetId, "Travel not possible");

        // Cache activeShipId to avoid repeated storage reads
        uint256 activeShipId = playerStates[player].activeShipId;

        // Use optimized view functions instead of full struct
        uint256 currentSpice = shipsContract.getShipSpice(activeShipId);
        require(currentSpice >= cost.spiceCost, "Insufficient spice for travel");

        uint256 shipSpeed = shipsContract.getShipSpeed(activeShipId);

        // Calculate adjusted travel time based on ship speed (unchecked: overflow impossible with realistic values)
        uint256 adjustedTimeCost;
        unchecked {
            adjustedTimeCost = (cost.timeCost * 100) / shipSpeed;
        }

        // Deduct spice and set travel state with time delay
        shipsContract.consumeSpice(activeShipId, cost.spiceCost);

        // Cache timestamp to avoid multiple TIMESTAMP opcodes
        uint40 currentTime = uint40(block.timestamp);

        // Set travel state
        playerStates[player].currentTripStartTime = currentTime;
        playerStates[player].currentTripEndTime = uint40(currentTime + adjustedTimeCost);
        playerStates[player].currentTripToPlanetId = uint8(toPlanetId);
        playerStates[player].currentPlanetId = 0; // In transit
        playerStates[player].lastActionTimestamp = currentTime;

        emit PlayerTripStarted(player, fromPlanetId, toPlanetId, currentTime + adjustedTimeCost);
    }

    function completeTravel() external {
        address player = msg.sender;
        require(isPlayerRegistered[player], "Player not registered");
        require(isPlayerTraveling(player), "Player is not traveling");
        require(block.timestamp >= playerStates[player].currentTripEndTime, "Travel not yet complete");

        // Cache values before clearing
        uint256 destinationPlanetId = playerStates[player].currentTripToPlanetId;
        uint256 activeShipId = playerStates[player].activeShipId;

        // Complete the travel
        playerStates[player].currentPlanetId = uint8(destinationPlanetId);
        playerStates[player].currentTripStartTime = 0;
        playerStates[player].currentTripEndTime = 0;
        playerStates[player].currentTripToPlanetId = 0;
        playerStates[player].lastActionTimestamp = uint40(block.timestamp);

        emit PlayerLocationChanged(player, destinationPlanetId, activeShipId);
    }

    function getPlayerState(address player) external view returns (PlayerState memory) {
        require(isPlayerRegistered[player], "Player not registered");
        return playerStates[player];
    }

    function getPlayerLocation(address player) external view returns (uint256 planetId) {
        require(isPlayerRegistered[player], "Player not registered");
        return playerStates[player].currentPlanetId;
    }

    function getPlayerActiveShip(address player) external view returns (uint256 shipId) {
        require(isPlayerRegistered[player], "Player not registered");
        return playerStates[player].activeShipId;
    }

    function isPlayerTraveling(address player) public view returns (bool) {
        return playerStates[player].currentTripEndTime > 0;
    }

    function updateLastActionTimestamp(address player) external onlyOwner {
        require(isPlayerRegistered[player], "Player not registered");
        playerStates[player].lastActionTimestamp = uint40(block.timestamp);
    }

    function getTripEndTime(address player) external view returns (uint256) {
        return playerStates[player].currentTripEndTime;
    }

    function getDestinationPlanet(address player) external view returns (uint256) {
        return playerStates[player].currentTripToPlanetId;
    }
}