// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract World is Ownable, ReentrancyGuard {
    struct Planet {
        string name;
        uint256 x;
        uint256 y;
        uint256 z;
        bool active;
        uint256[4] resourceConcentration; // [IRON, COPPER, WATER, FUEL] percentages (0-100)
        uint256 baseMiningDifficulty; // Base difficulty multiplier (100 = 1x)
    }

    struct TravelCost {
        uint256 fuelCost;
        uint256 timeCost; // in blocks
    }

    mapping(uint256 => Planet) public planets;
    mapping(uint256 => mapping(uint256 => TravelCost)) public travelCosts; // from planetId => to planetId => cost
    mapping(string => uint256) public planetNameToId;

    uint256 public planetCount;
    uint256 public constant MAX_COORDINATE = 10000;
    uint256 public constant BASE_FUEL_PER_DISTANCE = 1; // fuel per distance unit

    event PlanetCreated(uint256 indexed planetId, string name, uint256 x, uint256 y, uint256 z);
    event PlanetUpdated(uint256 indexed planetId);
    event TravelCostUpdated(uint256 indexed fromPlanet, uint256 indexed toPlanet, uint256 fuelCost, uint256 timeCost);

    constructor(address initialOwner) Ownable(initialOwner) {
        _initializeDefaultPlanets();
    }

    function createPlanet(
        string memory name,
        uint256 x,
        uint256 y,
        uint256 z,
        uint256[4] memory resourceConcentration,
        uint256 baseMiningDifficulty
    ) public onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Planet name cannot be empty");
        require(planetNameToId[name] == 0, "Planet name already exists");
        require(x <= MAX_COORDINATE && y <= MAX_COORDINATE && z <= MAX_COORDINATE, "Coordinates out of bounds");
        require(_validateResourceConcentrations(resourceConcentration), "Invalid resource concentrations");

        planetCount++;
        uint256 planetId = planetCount;

        planets[planetId] = Planet({
            name: name,
            x: x,
            y: y,
            z: z,
            active: true,
            resourceConcentration: resourceConcentration,
            baseMiningDifficulty: baseMiningDifficulty
        });

        planetNameToId[name] = planetId;

        // Calculate travel costs to all existing planets
        _calculateTravelCosts(planetId);

        emit PlanetCreated(planetId, name, x, y, z);
        return planetId;
    }

    function updatePlanetResources(
        uint256 planetId,
        uint256[4] memory resourceConcentration,
        uint256 baseMiningDifficulty
    ) external onlyOwner {
        require(planetId > 0 && planetId <= planetCount, "Planet does not exist");
        require(_validateResourceConcentrations(resourceConcentration), "Invalid resource concentrations");

        planets[planetId].resourceConcentration = resourceConcentration;
        planets[planetId].baseMiningDifficulty = baseMiningDifficulty;

        emit PlanetUpdated(planetId);
    }

    function setPlanetActive(uint256 planetId, bool active) external onlyOwner {
        require(planetId > 0 && planetId <= planetCount, "Planet does not exist");

        planets[planetId].active = active;
        emit PlanetUpdated(planetId);
    }

    function setTravelCost(
        uint256 fromPlanetId,
        uint256 toPlanetId,
        uint256 fuelCost,
        uint256 timeCost
    ) external onlyOwner {
        require(fromPlanetId > 0 && fromPlanetId <= planetCount, "From planet does not exist");
        require(toPlanetId > 0 && toPlanetId <= planetCount, "To planet does not exist");
        require(fromPlanetId != toPlanetId, "Cannot travel to same planet");

        travelCosts[fromPlanetId][toPlanetId] = TravelCost(fuelCost, timeCost);
        emit TravelCostUpdated(fromPlanetId, toPlanetId, fuelCost, timeCost);
    }

    function getPlanet(uint256 planetId) external view returns (Planet memory) {
        require(planetId > 0 && planetId <= planetCount, "Planet does not exist");
        return planets[planetId];
    }

    function getPlanetByName(string memory name) external view returns (uint256, Planet memory) {
        uint256 planetId = planetNameToId[name];
        require(planetId > 0, "Planet does not exist");
        return (planetId, planets[planetId]);
    }

    function getTravelCost(uint256 fromPlanetId, uint256 toPlanetId) external view returns (TravelCost memory) {
        require(fromPlanetId > 0 && fromPlanetId <= planetCount, "From planet does not exist");
        require(toPlanetId > 0 && toPlanetId <= planetCount, "To planet does not exist");

        return travelCosts[fromPlanetId][toPlanetId];
    }

    function getPlanetResourceConcentration(uint256 planetId, uint256 resourceIndex) external view returns (uint256) {
        require(planetId > 0 && planetId <= planetCount, "Invalid planet ID");
        require(resourceIndex < 4, "Invalid resource index");
        return planets[planetId].resourceConcentration[resourceIndex];
    }

    function getPlanetBaseMiningDifficulty(uint256 planetId) external view returns (uint256) {
        require(planetId > 0 && planetId <= planetCount, "Invalid planet ID");
        return planets[planetId].baseMiningDifficulty;
    }

    function calculateDistance(uint256 fromPlanetId, uint256 toPlanetId) public view returns (uint256) {
        require(fromPlanetId > 0 && fromPlanetId <= planetCount, "From planet does not exist");
        require(toPlanetId > 0 && toPlanetId <= planetCount, "To planet does not exist");

        Planet memory fromPlanet = planets[fromPlanetId];
        Planet memory toPlanet = planets[toPlanetId];

        uint256 dx = fromPlanet.x > toPlanet.x ? fromPlanet.x - toPlanet.x : toPlanet.x - fromPlanet.x;
        uint256 dy = fromPlanet.y > toPlanet.y ? fromPlanet.y - toPlanet.y : toPlanet.y - fromPlanet.y;
        uint256 dz = fromPlanet.z > toPlanet.z ? fromPlanet.z - toPlanet.z : toPlanet.z - fromPlanet.z;

        // Simplified 3D distance calculation (Manhattan distance for gas efficiency)
        return dx + dy + dz;
    }

    function getAllPlanets() external view returns (uint256[] memory planetIds, Planet[] memory planetData) {
        planetIds = new uint256[](planetCount);
        planetData = new Planet[](planetCount);

        for (uint256 i = 1; i <= planetCount; i++) {
            planetIds[i-1] = i;
            planetData[i-1] = planets[i];
        }

        return (planetIds, planetData);
    }

    function getActivePlanets() external view returns (uint256[] memory planetIds, Planet[] memory planetData) {
        uint256 activeCount = 0;

        // Count active planets
        for (uint256 i = 1; i <= planetCount; i++) {
            if (planets[i].active) {
                activeCount++;
            }
        }

        planetIds = new uint256[](activeCount);
        planetData = new Planet[](activeCount);

        uint256 index = 0;
        for (uint256 i = 1; i <= planetCount; i++) {
            if (planets[i].active) {
                planetIds[index] = i;
                planetData[index] = planets[i];
                index++;
            }
        }

        return (planetIds, planetData);
    }

    function _validateResourceConcentrations(uint256[4] memory concentrations) internal pure returns (bool) {
        uint256 total = 0;
        for (uint256 i = 0; i < 4; i++) {
            if (concentrations[i] > 100) return false;
            total += concentrations[i];
        }
        return total <= 400; // Allow some overlap but prevent excessive total
    }

    function _calculateTravelCosts(uint256 newPlanetId) internal {
        for (uint256 i = 1; i < newPlanetId; i++) {
            if (planets[i].active) {
                uint256 distance = calculateDistance(i, newPlanetId);
                uint256 fuelCost = distance * BASE_FUEL_PER_DISTANCE;
                uint256 timeCost = distance / 10 + 1; // Simplified time calculation

                // Set bidirectional travel costs
                travelCosts[i][newPlanetId] = TravelCost(fuelCost, timeCost);
                travelCosts[newPlanetId][i] = TravelCost(fuelCost, timeCost);

                emit TravelCostUpdated(i, newPlanetId, fuelCost, timeCost);
                emit TravelCostUpdated(newPlanetId, i, fuelCost, timeCost);
            }
        }
    }

    function _initializeDefaultPlanets() internal {
        // Earth (starting planet)
        createPlanet("Earth", 5000, 5000, 5000, [uint256(30), uint256(20), uint256(40), uint256(10)], 100);

        // Mars (iron rich)
        createPlanet("Mars", 5200, 5100, 4900, [uint256(60), uint256(15), uint256(10), uint256(15)], 120);

        // Europa (water rich)
        createPlanet("Europa", 4800, 5300, 5200, [uint256(10), uint256(15), uint256(65), uint256(10)], 150);

        // Titan (fuel rich)
        createPlanet("Titan", 5100, 4700, 5300, [uint256(15), uint256(20), uint256(20), uint256(45)], 140);

        // Ceres (copper rich)
        createPlanet("Ceres", 4900, 5200, 4800, [uint256(20), uint256(50), uint256(15), uint256(15)], 110);
    }
}