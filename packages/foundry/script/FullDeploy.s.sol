// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Credits.sol";
import "../src/Tokens.sol";
import "../src/Ships.sol";
import "../src/World.sol";
import "../src/Player.sol";
import "../src/Mining.sol";
import "../src/Market.sol";
import "../src/UniswapV4Hook.sol";
import "../src/ResourceWrapper.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract FullDeployScript is Script {
    function deployHook(IPoolManager poolManager, address mining, address player, address market)
        internal
        returns (UniswapV4Hook)
    {
        uint160 hookFlags = uint160(Hooks.BEFORE_SWAP_FLAG);
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        bytes memory creationCode = type(UniswapV4Hook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, mining, player, market);

        (address hookAddress, bytes32 salt) = HookMiner.find(
            create2Deployer,
            hookFlags,
            creationCode,
            constructorArgs
        );

        console.log("Found valid hook address:", hookAddress);
        console.log("Using salt:", vm.toString(salt));

        UniswapV4Hook hook = new UniswapV4Hook{salt: salt}(poolManager, mining, player, market);
        require(address(hook) == hookAddress, "Hook deployed to wrong address");

        return hook;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        string memory tokensBaseURI = vm.envOr("TOKENS_BASE_URI", string("https://api.dunetrade.game/tokens/{id}.json"));
        string memory shipsBaseURI = vm.envOr("SHIPS_BASE_URI", string("https://api.dunetrade.game/ships/"));
        address entropyAddress = vm.envOr("PYTH_ENTROPY_ADDRESS", address(0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c));

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING CORE CONTRACTS ===");

        Credits credits = new Credits(deployer);
        console.log("Credits:", address(credits));

        Tokens tokens = new Tokens(deployer, tokensBaseURI);
        console.log("Tokens:", address(tokens));

        Ships ships = new Ships(deployer, shipsBaseURI, address(credits));
        console.log("Ships:", address(ships));

        World world = new World(deployer);
        console.log("World:", address(world));

        Player player = new Player(deployer, address(world), address(ships), address(credits), address(tokens));
        console.log("Player:", address(player));

        Mining mining = new Mining(deployer, address(tokens), address(player), address(world), address(ships), entropyAddress);
        console.log("Mining:", address(mining));

        console.log("\n=== DEPLOYING 20 RESOURCE WRAPPERS (4 resources x 5 planets) ===");

        ResourceWrapper[20] memory wrappers;
        string[4] memory resourceNames = ["Metal", "Sapho", "Water", "Spice"];
        string[4] memory resourceSymbols = ["wMETAL", "wSAPHO", "wWATER", "wSPICE"];
        string[5] memory planetNames = ["Caladan", "Arrakis", "GiediPrime", "Ix", "Kaitain"];

        uint256 wrapperIndex = 0;
        for (uint256 planetId = 1; planetId <= 5; planetId++) {
            for (uint256 resourceId = 0; resourceId < 4; resourceId++) {
                string memory name = string(abi.encodePacked(resourceNames[resourceId], "-", planetNames[planetId-1]));
                string memory symbol = string(abi.encodePacked(resourceSymbols[resourceId], planetNames[planetId-1]));

                wrappers[wrapperIndex] = new ResourceWrapper(
                    address(tokens),
                    resourceId,
                    name,
                    symbol,
                    deployer
                );
                console.log("Wrapper", wrapperIndex, ":", address(wrappers[wrapperIndex]));
                wrapperIndex++;
            }
        }

        console.log("\n=== DEPLOYING UNISWAP V4 ===");

        IPoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager:", address(poolManager));

        Market market = new Market(deployer, address(player), address(tokens), address(credits), address(poolManager));
        console.log("Market:", address(market));

        UniswapV4Hook hook = deployHook(poolManager, address(mining), address(player), address(market));
        console.log("Hook:", address(hook));

        console.log("\n=== SETTING UP AUTHORIZATIONS ===");

        credits.setAuthorizedMinter(address(player), true);
        tokens.setAuthorizedMinter(address(mining), true);
        ships.setAuthorizedMinter(address(player), true);
        ships.setAuthorizedManager(address(player), true);
        ships.setAuthorizedManager(address(mining), true);

        console.log("\n=== INITIALIZING 20 TRADING PAIRS ===");

        wrapperIndex = 0;
        for (uint256 planetId = 1; planetId <= 5; planetId++) {
            for (uint256 resourceId = 0; resourceId < 4; resourceId++) {
                market.initializeTradingPair(
                    planetId,
                    resourceId,
                    address(wrappers[wrapperIndex]),
                    500,  // 0.05% fee
                    10,   // tick spacing
                    address(hook),
                    79228162514264337593543950336  // sqrt(1) price
                );
                console.log("Initialized pair: Planet", planetId, "Resource", resourceId);
                wrapperIndex++;
            }
        }

        console.log("\n=== ADDING HIGH LIQUIDITY TO ALL 20 POOLS ===");

        // Liquidity configuration [resourceAmount, creditsAmount]
        // Reduced 100x for balanced game economy with meaningful price impact
        uint256[2][4] memory baseLiquidity = [
            [uint256(1000 ether), 10000 ether],  // Metal: 1:10
            [uint256(800 ether), 12000 ether],   // Sapho: 1:15
            [uint256(2000 ether), 10000 ether],  // Water: 1:5
            [uint256(200 ether), 10000 ether]    // Spice: 1:50
        ];

        credits.mint(deployer, 10000000 ether);
        console.log("Minted 10M credits for liquidity");

        wrapperIndex = 0;
        for (uint256 planetId = 1; planetId <= 5; planetId++) {
            for (uint256 resourceId = 0; resourceId < 4; resourceId++) {
                uint256 resourceAmount = baseLiquidity[resourceId][0];
                uint256 creditsAmount = baseLiquidity[resourceId][1];
                ResourceWrapper wrapper = wrappers[wrapperIndex];

                // Mint and wrap resources
                tokens.mint(deployer, resourceId, resourceAmount, "");
                tokens.setApprovalForAll(address(wrapper), true);
                wrapper.wrap(resourceAmount);

                // Approve market
                wrapper.approve(address(market), resourceAmount);
                credits.approve(address(market), creditsAmount);

                // Add liquidity
                market.addLiquidity(
                    planetId,
                    resourceId,
                    -120,
                    120,
                    resourceAmount,
                    creditsAmount,
                    50
                );

                console.log("Added liquidity: Planet", planetId, "Resource", resourceId);
                wrapperIndex++;
            }
        }

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("All 20 markets initialized with balanced liquidity!");

        vm.stopBroadcast();
    }
}