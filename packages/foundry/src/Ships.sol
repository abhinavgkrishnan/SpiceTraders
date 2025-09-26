// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Ships is ERC721, ERC721Enumerable, ERC721Pausable, Ownable {
    using Strings for uint256;

    struct ShipAttributes {
        string name;
        uint256 cargoCapacity;
        uint256 spiceCapacity;  // Only spice is used as fuel
        uint256 currentSpice;
        uint256 shipClass; // 0: Atreides Scout, 1: Guild Frigate, 2: Harkonnen Harvester, 3: Imperial Dreadnought
        uint256 speed; // Speed multiplier (100 = 1x, 120 = 1.2x faster)
        bool active;
    }

    mapping(uint256 => ShipAttributes) public ships;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedManagers;

    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    // Ship class configurations
    mapping(uint256 => uint256) public defaultCargoCapacity;
    mapping(uint256 => uint256) public defaultSpiceCapacity;
    mapping(uint256 => uint256) public defaultSpeed;

    event ShipMinted(uint256 indexed tokenId, address indexed to, uint256 shipClass);
    event ShipAttributesUpdated(uint256 indexed tokenId);
    event AuthorizedMinterSet(address indexed minter, bool authorized);
    event AuthorizedManagerSet(address indexed manager, bool authorized);
    event SpiceUpdated(uint256 indexed tokenId, uint256 newSpiceAmount);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    modifier onlyAuthorizedManager() {
        require(authorizedManagers[msg.sender] || msg.sender == owner(), "Not authorized to manage");
        _;
    }

    constructor(address initialOwner, string memory baseURI)
        ERC721("Guild Heighliners", "SHIPS")
        Ownable(initialOwner)
    {
        authorizedMinters[initialOwner] = true;
        authorizedManagers[initialOwner] = true;

        // Set default ship class specifications (balanced for 0.6 spice per distance travel)
        defaultCargoCapacity[0] = 150;  // Atreides Scout: 150 units
        defaultCargoCapacity[1] = 500;  // Guild Frigate: 500 units
        defaultCargoCapacity[2] = 1000; // Harkonnen Harvester: 1000 units
        defaultCargoCapacity[3] = 2000; // Imperial Dreadnought: 2000 units

        defaultSpiceCapacity[0] = 2000;  // Atreides Scout: 2000 spice (round-trip to nearest planet)
        defaultSpiceCapacity[1] = 5000;  // Guild Frigate: 5000 spice
        defaultSpiceCapacity[2] = 8000;  // Harkonnen Harvester: 8000 spice (multiple trips)
        defaultSpiceCapacity[3] = 12000; // Imperial Dreadnought: 12000 spice (long range)

        defaultSpeed[0] = 100;  // Atreides Scout: 1.0x speed (baseline)
        defaultSpeed[1] = 120;  // Guild Frigate: 1.2x speed (faster)
        defaultSpeed[2] = 80;   // Harkonnen Harvester: 0.8x speed (slower but high cargo)
        defaultSpeed[3] = 150;  // Imperial Dreadnought: 1.5x speed (fastest)

        _baseTokenURI = baseURI;
    }

    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterSet(minter, authorized);
    }

    function setAuthorizedManager(address manager, bool authorized) external onlyOwner {
        authorizedManagers[manager] = authorized;
        emit AuthorizedManagerSet(manager, authorized);
    }

    function mintShip(
        address to,
        string memory shipName,
        uint256 shipClass
    ) public onlyAuthorizedMinter returns (uint256) {
        return _mintShip(to, shipName, shipClass);
    }

    function _mintShip(
        address to,
        string memory shipName,
        uint256 shipClass
    ) internal returns (uint256) {
        require(shipClass <= 3, "Invalid ship class");
        require(bytes(shipName).length > 0, "Ship name cannot be empty");

        uint256 tokenId = _nextTokenId++;
        uint256 cargoCapacity = defaultCargoCapacity[shipClass];
        uint256 spiceCapacity = defaultSpiceCapacity[shipClass];
        uint256 speed = defaultSpeed[shipClass];

        ships[tokenId] = ShipAttributes({
            name: shipName,
            cargoCapacity: cargoCapacity,
            spiceCapacity: spiceCapacity,
            currentSpice: spiceCapacity, // Start with full spice tank
            shipClass: shipClass,
            speed: speed,
            active: true
        });

        _safeMint(to, tokenId);
        emit ShipMinted(tokenId, to, shipClass);
        return tokenId;
    }

    function mintStarterShip(address to, string memory shipName) external onlyAuthorizedMinter returns (uint256) {
        return _mintShip(to, shipName, 0); // Mint an Atreides Scout as starter
    }

    function updateSpice(uint256 tokenId, uint256 newSpiceAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");
        require(newSpiceAmount <= ships[tokenId].spiceCapacity, "Spice amount exceeds capacity");

        ships[tokenId].currentSpice = newSpiceAmount;
        emit SpiceUpdated(tokenId, newSpiceAmount);
    }

    function consumeSpice(uint256 tokenId, uint256 spiceAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");
        require(ships[tokenId].currentSpice >= spiceAmount, "Insufficient spice");

        ships[tokenId].currentSpice -= spiceAmount;
        emit SpiceUpdated(tokenId, ships[tokenId].currentSpice);
    }

    function refillSpice(uint256 tokenId, uint256 spiceAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");

        uint256 newSpiceAmount = ships[tokenId].currentSpice + spiceAmount;
        if (newSpiceAmount > ships[tokenId].spiceCapacity) {
            newSpiceAmount = ships[tokenId].spiceCapacity;
        }

        ships[tokenId].currentSpice = newSpiceAmount;
        emit SpiceUpdated(tokenId, newSpiceAmount);
    }

    function updateShipName(uint256 tokenId, string memory newName) external {
        require(ownerOf(tokenId) == msg.sender, "Not the ship owner");
        require(bytes(newName).length > 0, "Ship name cannot be empty");

        ships[tokenId].name = newName;
        emit ShipAttributesUpdated(tokenId);
    }

    function setShipActive(uint256 tokenId, bool active) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");

        ships[tokenId].active = active;
        emit ShipAttributesUpdated(tokenId);
    }

    function getShipAttributes(uint256 tokenId) external view returns (ShipAttributes memory) {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");
        return ships[tokenId];
    }

    function getShipsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokenIds;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString()));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}