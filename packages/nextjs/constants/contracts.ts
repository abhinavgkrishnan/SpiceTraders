export const CONTRACTS = {
  Credits: "0xBB84D65c98B5374dC12C8254b9164C66AB02ae4a" as `0x${string}`,
  Tokens: "0x5Fa5730Fcf0aaaab51A374324c9E68b74f1ae749" as `0x${string}`,
  Ships: "0x940A1060ED998dF1045c7F8E4209771659161b75" as `0x${string}`,
  World: "0x12fFD98a1CeEC817AB1887F07965DcB70ceAf2A3" as `0x${string}`,
  Player: "0xca03eBB7D3640c452450D3be2d14F52DD2Ecac46" as `0x${string}`,
  Mining: "0x3d4D4AC5A8aa6AB64dB1137e51D72dC01Bb44432" as `0x${string}`,
  MetalWrapper: "0x1E6D48490b39DebA723A7185171F5711c50AB6F8" as `0x${string}`,
  SaphoWrapper: "0xfd0C0B77E4Da91620EAf206748D158b871a9E14D" as `0x${string}`,
  WaterWrapper: "0xBA464d0C256A5Fc153F8796386024C881005F86E" as `0x${string}`,
  SpiceWrapper: "0x8B808b89D3862807ce73E5e6653785d570277329" as `0x${string}`,
  PoolManager: "0x075c6d85116FBDbd5e69D1ea368b1Bf48496886F" as `0x${string}`,
  Market: "0x184f5433cF1B9Cd28135BD8775F91C6535E65C6d" as `0x${string}`,
  Hook: "0x20a26e0e46c3F2F08201Aa75b731eFE02Fb44080" as `0x${string}`,
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