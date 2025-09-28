export const CONTRACTS = {
  Credits: "0xDB8c117fc14bB4056BBe8b08bDe9B08481d4F7D2" as `0x${string}`,
  Tokens: "0x9fBBde39e06CC5FdeF1AaBb6FBceeA100b950C3B" as `0x${string}`,
  Ships: "0x045C7482C46df184B83C72303D9206b8B459cCAB" as `0x${string}`,
  World: "0x30dCA429f62B9703c4070b164c3bb16Fa2FD240a" as `0x${string}`,
  Player: "0xD5dAb3cAa5c3bDA2412351C5f4776FAC115e50b0" as `0x${string}`,
  Mining: "0x2224B0ab828B64Cb167A5354F500c5E7A194A973" as `0x${string}`,
  PoolManager: "0x0c22D7458563ce69D457c78fe81Ca956fb2b39E8" as `0x${string}`,
  Market: "0x2EBe5B7285D89fC8B88Bc91D8D1d901B5dE263aD" as `0x${string}`,
  Hook: "0x57f287a87Eabd9326603885024aDFc6225148080" as `0x${string}`,
} as const;

export const RESOURCES = {
  METAL: 0,
  SAPHO_JUICE: 1,
  WATER: 2,
  SPICE: 3,
} as const;

export const RESOURCE_NAMES = ["Metal", "Sapho Juice", "Water", "Spice"] as const;

export const PLANETS = {
  CALADAN: 1,
  ARRAKIS: 2,
  GIEDI_PRIME: 3,
  IX: 4,
  KAITAIN: 5,
} as const;

export const PLANET_NAMES = [
  "Unknown",
  "Caladan",
  "Arrakis",
  "Giedi Prime",
  "Ix",
  "Kaitain",
] as const;