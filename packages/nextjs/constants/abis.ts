export const PlayerABI = [
  {
    type: "function",
    name: "onboardNewPlayer",
    stateMutability: "nonpayable",
    inputs: [
      { name: "player", type: "address" },
      { name: "shipName", type: "string" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "getPlayerState",
    stateMutability: "view",
    inputs: [{ name: "player", type: "address" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "playerAddress", type: "address" },
          { name: "currentPlanetId", type: "uint256" },
          { name: "activeShipId", type: "uint256" },
          { name: "shipIds", type: "uint256[]" },
          { name: "lastActionTimestamp", type: "uint256" },
          { name: "currentTripStartTime", type: "uint256" },
          { name: "currentTripEndTime", type: "uint256" },
          { name: "currentTripToPlanetId", type: "uint256" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "isPlayerRegistered",
    stateMutability: "view",
    inputs: [{ name: "player", type: "address" }],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "instantTravel",
    stateMutability: "nonpayable",
    inputs: [{ name: "toPlanetId", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "completeTravel",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
] as const;

export const MiningABI = [
  {
    type: "function",
    name: "mine",
    stateMutability: "payable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "lastMiningTimestamp",
    stateMutability: "view",
    inputs: [{ name: "player", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

export const CreditsABI = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
  },
] as const;

export const TokensABI = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "id", type: "uint256" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "setApprovalForAll",
    stateMutability: "nonpayable",
    inputs: [
      { name: "operator", type: "address" },
      { name: "approved", type: "bool" },
    ],
    outputs: [],
  },
] as const;

export const ShipsABI = [
  {
    type: "function",
    name: "getShipAttributes",
    stateMutability: "view",
    inputs: [{ name: "tokenId", type: "uint256" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "name", type: "string" },
          { name: "cargoCapacity", type: "uint256" },
          { name: "spiceCapacity", type: "uint256" },
          { name: "currentSpice", type: "uint256" },
          { name: "shipClass", type: "uint256" },
          { name: "speed", type: "uint256" },
          { name: "active", type: "bool" },
        ],
      },
    ],
  },
] as const;

export const WorldABI = [
  {
    type: "function",
    name: "getPlanet",
    stateMutability: "view",
    inputs: [{ name: "planetId", type: "uint256" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "name", type: "string" },
          { name: "x", type: "uint256" },
          { name: "y", type: "uint256" },
          { name: "z", type: "uint256" },
          { name: "active", type: "bool" },
          { name: "resourceConcentration", type: "uint256[4]" },
          { name: "baseMiningDifficulty", type: "uint256" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "getTravelCost",
    stateMutability: "view",
    inputs: [
      { name: "fromPlanetId", type: "uint256" },
      { name: "toPlanetId", type: "uint256" },
    ],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "spiceCost", type: "uint256" },
          { name: "timeCost", type: "uint256" },
        ],
      },
    ],
  },
] as const;

export const MarketABI = [
  {
    type: "function",
    name: "executeTrade",
    stateMutability: "nonpayable",
    inputs: [
      { name: "planetId", type: "uint256" },
      { name: "resourceId", type: "uint256" },
      { name: "resourceToCredits", type: "bool" },
      { name: "amountIn", type: "uint256" },
      { name: "minAmountOut", type: "uint256" },
    ],
    outputs: [{ name: "amountOut", type: "uint256" }],
  },
  {
    type: "function",
    name: "getQuote",
    stateMutability: "view",
    inputs: [
      { name: "planetId", type: "uint256" },
      { name: "resourceId", type: "uint256" },
      { name: "resourceToCredits", type: "bool" },
      { name: "amountIn", type: "uint256" },
    ],
    outputs: [{ name: "amountOut", type: "uint256" }],
  },
  {
    type: "function",
    name: "getTradingPair",
    stateMutability: "view",
    inputs: [
      { name: "planetId", type: "uint256" },
      { name: "resourceId", type: "uint256" },
    ],
    outputs: [
      {
        type: "tuple",
        components: [
          {
            name: "poolKey",
            type: "tuple",
            components: [
              { name: "currency0", type: "address" },
              { name: "currency1", type: "address" },
              { name: "fee", type: "uint24" },
              { name: "tickSpacing", type: "int24" },
              { name: "hooks", type: "address" },
            ],
          },
          { name: "poolId", type: "bytes32" },
          { name: "wrappedResource", type: "address" },
          { name: "isInitialized", type: "bool" },
        ],
      },
    ],
  },
] as const;