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
        uint256 fuelCapacity;
        uint256 currentFuel;
        uint256 shipClass; // 0: Scout, 1: Trader, 2: Industrial, 3: Capital
        bool active;
    }

    mapping(uint256 => ShipAttributes) public ships;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedManagers;

    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    // Ship class configurations
    mapping(uint256 => uint256) public defaultCargoCapacity;
    mapping(uint256 => uint256) public defaultFuelCapacity;

    event ShipMinted(uint256 indexed tokenId, address indexed to, uint256 shipClass);
    event ShipAttributesUpdated(uint256 indexed tokenId);
    event AuthorizedMinterSet(address indexed minter, bool authorized);
    event AuthorizedManagerSet(address indexed manager, bool authorized);
    event FuelUpdated(uint256 indexed tokenId, uint256 newFuelAmount);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    modifier onlyAuthorizedManager() {
        require(authorizedManagers[msg.sender] || msg.sender == owner(), "Not authorized to manage");
        _;
    }

    constructor(address initialOwner)
        ERC721("Space Ships", "SHIPS")
        Ownable(initialOwner)
    {
        authorizedMinters[initialOwner] = true;
        authorizedManagers[initialOwner] = true;

        // Set default ship class specifications
        defaultCargoCapacity[0] = 100;  // Scout: 100 units
        defaultCargoCapacity[1] = 500;  // Trader: 500 units
        defaultCargoCapacity[2] = 1000; // Industrial: 1000 units
        defaultCargoCapacity[3] = 2000; // Capital: 2000 units

        defaultFuelCapacity[0] = 200;   // Scout: 200 fuel
        defaultFuelCapacity[1] = 300;   // Trader: 300 fuel
        defaultFuelCapacity[2] = 500;   // Industrial: 500 fuel
        defaultFuelCapacity[3] = 800;   // Capital: 800 fuel

        _baseTokenURI = "https://api.spacetrade.game/ships/";
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
        uint256 fuelCapacity = defaultFuelCapacity[shipClass];

        ships[tokenId] = ShipAttributes({
            name: shipName,
            cargoCapacity: cargoCapacity,
            fuelCapacity: fuelCapacity,
            currentFuel: fuelCapacity, // Start with full fuel
            shipClass: shipClass,
            active: true
        });

        _safeMint(to, tokenId);
        emit ShipMinted(tokenId, to, shipClass);
        return tokenId;
    }

    function mintStarterShip(address to, string memory shipName) external onlyAuthorizedMinter returns (uint256) {
        return _mintShip(to, shipName, 0); // Mint a Scout ship as starter
    }

    function updateFuel(uint256 tokenId, uint256 newFuelAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");
        require(newFuelAmount <= ships[tokenId].fuelCapacity, "Fuel amount exceeds capacity");

        ships[tokenId].currentFuel = newFuelAmount;
        emit FuelUpdated(tokenId, newFuelAmount);
    }

    function consumeFuel(uint256 tokenId, uint256 fuelAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");
        require(ships[tokenId].currentFuel >= fuelAmount, "Insufficient fuel");

        ships[tokenId].currentFuel -= fuelAmount;
        emit FuelUpdated(tokenId, ships[tokenId].currentFuel);
    }

    function refillFuel(uint256 tokenId, uint256 fuelAmount) external onlyAuthorizedManager {
        require(_ownerOf(tokenId) != address(0), "Ship does not exist");

        uint256 newFuelAmount = ships[tokenId].currentFuel + fuelAmount;
        if (newFuelAmount > ships[tokenId].fuelCapacity) {
            newFuelAmount = ships[tokenId].fuelCapacity;
        }

        ships[tokenId].currentFuel = newFuelAmount;
        emit FuelUpdated(tokenId, newFuelAmount);
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