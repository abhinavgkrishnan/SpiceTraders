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

contract DeployScript is Script {
    function deployHook(IPoolManager poolManager, address mining, address player, address market)
        internal
        returns (UniswapV4Hook)
    {
        // Find the correct salt for hook deployment with BEFORE_SWAP_FLAG
        uint160 hookFlags = uint160(Hooks.BEFORE_SWAP_FLAG);

        // Use standard CREATE2 deployer address as per Uniswap docs
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        // Get the creation code and constructor args
        bytes memory creationCode = type(UniswapV4Hook).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager, mining, player, market);

        // Mine for a valid hook address using the standard CREATE2 deployer
        (address hookAddress, bytes32 salt) = HookMiner.find(
            create2Deployer,
            hookFlags,
            creationCode,
            constructorArgs
        );

        console.log("Found valid hook address:", hookAddress);
        console.log("Using salt:", vm.toString(salt));

        // Deploy using Solidity's CREATE2 syntax with the mined salt
        UniswapV4Hook hook = new UniswapV4Hook{salt: salt}(poolManager, mining, player, market);

        require(address(hook) == hookAddress, "Hook deployed to wrong address");
        console.log("UniswapV4Hook deployed to:", address(hook));

        return hook;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get configurable URIs from environment
        string memory tokensBaseURI = vm.envOr("TOKENS_BASE_URI", string("https://api.dunetrade.game/tokens/{id}.json"));
        string memory shipsBaseURI = vm.envOr("SHIPS_BASE_URI", string("https://api.dunetrade.game/ships/"));

        // Get Pyth Entropy address from environment
        address entropyAddress = vm.envOr("PYTH_ENTROPY_ADDRESS", address(0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c));

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying contracts to:", block.chainid);
        console.log("Deployer address:", deployer);
        console.log("Tokens Base URI:", tokensBaseURI);
        console.log("Ships Base URI:", shipsBaseURI);
        console.log("Pyth Entropy Address:", entropyAddress);

        // Deploy core contracts
        Credits credits = new Credits(deployer);
        console.log("Credits (Solaris) deployed to:", address(credits));

        Tokens tokens = new Tokens(deployer, tokensBaseURI);
        console.log("Tokens (Resources) deployed to:", address(tokens));

        Ships ships = new Ships(deployer, shipsBaseURI, address(credits));
        console.log("Ships (Guild Heighliners) deployed to:", address(ships));

        World world = new World(deployer);
        console.log("World (Planets) deployed to:", address(world));

        Player player = new Player(deployer, address(world), address(ships), address(credits));
        console.log("Player (Registration/Travel) deployed to:", address(player));

        Mining mining = new Mining(
            deployer,
            address(tokens),
            address(player),
            address(world),
            address(ships),
            entropyAddress
        );
        console.log("Mining (Resource Extraction) deployed to:", address(mining));

        // Deploy Resource Wrappers (ERC20 wrappers for ERC1155 resources)
        console.log("Deploying Resource Wrappers...");

        ResourceWrapper metalWrapper = new ResourceWrapper(
            address(tokens),
            0, // METAL
            "Wrapped Metal",
            "wMETAL",
            deployer
        );
        console.log("Metal Wrapper deployed to:", address(metalWrapper));

        ResourceWrapper saphoWrapper = new ResourceWrapper(
            address(tokens),
            1, // SAPHO_JUICE
            "Wrapped Sapho Juice",
            "wSAPHO",
            deployer
        );
        console.log("Sapho Wrapper deployed to:", address(saphoWrapper));

        ResourceWrapper waterWrapper = new ResourceWrapper(
            address(tokens),
            2, // WATER
            "Wrapped Water",
            "wWATER",
            deployer
        );
        console.log("Water Wrapper deployed to:", address(waterWrapper));

        ResourceWrapper spiceWrapper = new ResourceWrapper(
            address(tokens),
            3, // SPICE
            "Wrapped Spice",
            "wSPICE",
            deployer
        );
        console.log("Spice Wrapper deployed to:", address(spiceWrapper));

        // Deploy Uniswap V4 Infrastructure
        console.log("Deploying Uniswap V4 infrastructure...");

        IPoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager deployed to:", address(poolManager));

        // Deploy Market first so we can pass it to the hook
        Market market = new Market(deployer, address(player), address(tokens), address(credits), address(poolManager));
        console.log("Market deployed to:", address(market));

        UniswapV4Hook hook = deployHook(poolManager, address(mining), address(player), address(market));

        // Set up authorizations
        credits.setAuthorizedMinter(address(player), true);  // Player can mint starter credits
        tokens.setAuthorizedMinter(address(mining), true);   // Mining can mint resources
        ships.setAuthorizedMinter(address(player), true);    // Player can mint starter ships
        ships.setAuthorizedManager(address(player), true);   // Player can manage spice for travel
        ships.setAuthorizedManager(address(mining), true);   // Mining can manage spice (future use)

        // Set up token approvals for PoolManager
        tokens.setApprovalForAll(address(poolManager), true);

        console.log("Authorizations configured successfully");
        console.log("Uniswap V4 market infrastructure deployed!");
        console.log("Deployment complete!");

        vm.stopBroadcast();
    }
}