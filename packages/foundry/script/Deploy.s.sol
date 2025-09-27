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

contract DeployScript is Script {
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

        // Set up authorizations
        credits.setAuthorizedMinter(address(player), true);  // Player can mint starter credits
        tokens.setAuthorizedMinter(address(mining), true);   // Mining can mint resources
        ships.setAuthorizedMinter(address(player), true);    // Player can mint starter ships
        ships.setAuthorizedManager(address(player), true);   // Player can manage spice for travel
        ships.setAuthorizedManager(address(mining), true);   // Mining can manage spice (future use)

        console.log("Authorizations configured successfully");
        console.log("Deployment complete!");

        vm.stopBroadcast();
    }
}