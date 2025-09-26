// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./World.sol";
import "./Ships.sol";

contract Player is Ownable, ReentrancyGuard {
    struct PlayerState {
        address playerAddress;
        uint256 currentPlanetId;
        uint256 activeShipId;
        uint256[] shipIds; // All ships owned by the player
        uint256 lastActionTimestamp;
        uint256 currentTripStartBlock;
        uint256 currentTripEndBlock;
        uint256 currentTripToPlanetId;
    }

    World public worldContract;
    Ships public shipsContract;

    mapping(address => PlayerState) public playerStates;
    mapping(address => bool) public isPlayerRegistered;

    event PlayerRegistered(address indexed player, uint256 startPlanetId);
    event PlayerLocationChanged(address indexed player, uint256 newPlanetId, uint256 activeShipId);
    event ActiveShipChanged(address indexed player, uint256 newActiveShipId);
    event PlayerTripStarted(address indexed player, uint256 fromPlanet, uint256 toPlanet, uint256 endBlock);

    constructor(address initialOwner, address _worldContract, address _shipsContract) Ownable(initialOwner) {
        worldContract = World(_worldContract);
        shipsContract = Ships(_shipsContract);
    }

    function registerPlayer(address player, uint256 startPlanetId, uint256 startShipId) external onlyOwner {
        require(!isPlayerRegistered[player], "Player already registered");
        require(startPlanetId > 0 && startPlanetId <= worldContract.planetCount(), "Invalid start planet");
        require(shipsContract.ownerOf(startShipId) == player, "Player does not own start ship");

        playerStates[player].playerAddress = player;
        playerStates[player].currentPlanetId = startPlanetId;
        playerStates[player].activeShipId = startShipId;
        playerStates[player].shipIds.push(startShipId);
        playerStates[player].lastActionTimestamp = block.timestamp;

        isPlayerRegistered[player] = true;
        emit PlayerRegistered(player, startPlanetId);
    }

    function setActiveShip(uint256 shipId) external nonReentrant {
        require(isPlayerRegistered[msg.sender], "Player not registered");
        require(shipsContract.ownerOf(shipId) == msg.sender, "Player does not own this ship");
        require(!isPlayerTraveling(msg.sender), "Cannot change ships during travel");

        playerStates[msg.sender].activeShipId = shipId;
        emit ActiveShipChanged(msg.sender, shipId);
    }

    function addShipToPlayer(address player, uint256 shipId) external onlyOwner {
        require(isPlayerRegistered[player], "Player not registered");
        require(shipsContract.ownerOf(shipId) == player, "Player does not own this ship");

        playerStates[player].shipIds.push(shipId);
    }

    function startTravel(uint256 toPlanetId) external nonReentrant {
        address player = msg.sender;
        require(isPlayerRegistered[player], "Player not registered");
        require(!isPlayerTraveling(player), "Player is already traveling");

        uint256 fromPlanetId = playerStates[player].currentPlanetId;
        uint256 activeShipId = playerStates[player].activeShipId;

        World.TravelCost memory cost = worldContract.getTravelCost(fromPlanetId, toPlanetId);
        require(cost.spiceCost > 0 || fromPlanetId == toPlanetId, "Travel not possible"); // No cost means no route

        // Consume spice from active ship (spice is the only fuel)
        shipsContract.consumeSpice(activeShipId, cost.spiceCost);

        uint256 endBlock = block.number + cost.timeCost;

        // Update player state to traveling
        playerStates[player].currentTripStartBlock = block.number;
        playerStates[player].currentTripEndBlock = endBlock;
        playerStates[player].currentTripToPlanetId = toPlanetId;
        playerStates[player].currentPlanetId = 0; // In transit, not on any planet

        emit PlayerTripStarted(player, fromPlanetId, toPlanetId, endBlock);
    }

    function completeTravel() external nonReentrant {
        address player = msg.sender;
        require(isPlayerRegistered[player], "Player not registered");
        require(playerStates[player].currentTripEndBlock > 0, "Player is not traveling");
        require(block.number >= playerStates[player].currentTripEndBlock, "Trip not yet complete");

        uint256 destinationPlanetId = playerStates[player].currentTripToPlanetId;

        // Update player state to be at the destination
        playerStates[player].currentPlanetId = destinationPlanetId;
        playerStates[player].currentTripStartBlock = 0;
        playerStates[player].currentTripEndBlock = 0;
        playerStates[player].currentTripToPlanetId = 0;
        playerStates[player].lastActionTimestamp = block.timestamp;

        emit PlayerLocationChanged(player, destinationPlanetId, playerStates[player].activeShipId);
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
        return playerStates[player].currentTripEndBlock > block.number;
    }

    function updateLastActionTimestamp(address player) external onlyOwner {
        require(isPlayerRegistered[player], "Player not registered");
        playerStates[player].lastActionTimestamp = block.timestamp;
    }
}