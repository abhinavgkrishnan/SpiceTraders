export const CONTRACTS = {
  Credits: "0xA751797e3FFda42827a3BdbF3b737f1354831A18" as `0x${string}`,
  Tokens: "0x1A753a2DbDe68025F2d4AFb268d63814E16146d4" as `0x${string}`,
  Ships: "0xF8FBfCF61aE57FF4372fFcf4fB9C20177a4e1d7c" as `0x${string}`,
  World: "0x378590c511F289575Fb5BA1C7C9F1a0AD6D17886" as `0x${string}`,
  Player: "0x370421D96d83b89961145a912D9b355fb6FBD1F1" as `0x${string}`,
  Mining: "0x4a838591E0171B02875B37E81B0D77aE185B7644" as `0x${string}`,
  MetalWrapper: "0xb6314d8AADAbe22605d647e680C38B72B67bc8F4" as `0x${string}`,
  SaphoWrapper: "0xaBd5330d820f4b813D3a7D16c2eA4826542c2147" as `0x${string}`,
  WaterWrapper: "0x92548F0dC9244e03eba7Fee75dc8568C33F650c0" as `0x${string}`,
  SpiceWrapper: "0x53824598CEbD42C1e2913e59444dCaA98E0d05Ec" as `0x${string}`,
  PoolManager: "0x4F60AA3E8a13200ffD30c46b880041c9AEBe58eC" as `0x${string}`,
  Market: "0x6ED266d0371893e9e1fBC60Dc0AB7c2F5E929FFF" as `0x${string}`,
  Hook: "0xD505919A9317b21E50E91b0160Df1B1c4ED74080" as `0x${string}`,
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