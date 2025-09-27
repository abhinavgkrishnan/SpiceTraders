import { useReadContract } from "wagmi";
import { CONTRACTS, PLANETS } from "@/constants/contracts";
import { WorldABI } from "@/constants/abis";

export function usePlanets() {
  const planets = [
    PLANETS.CALADAN,
    PLANETS.ARRAKIS,
    PLANETS.GIEDI_PRIME,
    PLANETS.IX,
    PLANETS.KAITAIN,
  ];

  const planetQueries = planets.map((id) =>
    useReadContract({
      address: CONTRACTS.World,
      abi: WorldABI,
      functionName: "getPlanet",
      args: [BigInt(id)],
    })
  );

  const planetsData = planetQueries.map((query, index) => {
    if (!query.data) return null;
    return {
      id: planets[index],
      name: query.data.name,
      x: Number(query.data.x),
      y: Number(query.data.y),
      z: Number(query.data.z),
      active: query.data.active,
      resourceConcentration: query.data.resourceConcentration.map((c) => Number(c)),
      baseMiningDifficulty: Number(query.data.baseMiningDifficulty),
    };
  });

  return {
    planets: planetsData.filter((p) => p !== null),
    isLoading: planetQueries.some((q) => q.isLoading),
  };
}

export function useTravelCost(fromPlanetId: number, toPlanetId: number) {
  const { data: travelCost, isLoading } = useReadContract({
    address: CONTRACTS.World,
    abi: WorldABI,
    functionName: "getTravelCost",
    args:
      fromPlanetId > 0 && toPlanetId > 0
        ? [BigInt(fromPlanetId), BigInt(toPlanetId)]
        : undefined,
    query: {
      enabled: fromPlanetId > 0 && toPlanetId > 0 && fromPlanetId !== toPlanetId,
    },
  });

  return {
    spiceCost: travelCost ? Number(travelCost.spiceCost) : 0,
    timeCost: travelCost ? Number(travelCost.timeCost) : 0,
    isLoading,
  };
}