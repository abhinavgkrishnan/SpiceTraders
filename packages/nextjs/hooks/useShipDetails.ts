import { useReadContract } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { ShipsABI } from "@/constants/abis";

export function useShipDetails(shipId: number) {
  const { data: shipAttributes, isLoading } = useReadContract({
    address: CONTRACTS.Ships,
    abi: ShipsABI,
    functionName: "getShipAttributes",
    args: shipId > 0 ? [BigInt(shipId)] : undefined,
    query: {
      enabled: shipId > 0,
    },
  });

  return {
    ship: shipAttributes
      ? {
          name: shipAttributes.name,
          cargoCapacity: Number(shipAttributes.cargoCapacity),
          spiceCapacity: Number(shipAttributes.spiceCapacity),
          currentSpice: Number(shipAttributes.currentSpice),
          shipClass: Number(shipAttributes.shipClass),
          speed: Number(shipAttributes.speed),
          active: shipAttributes.active,
        }
      : null,
    isLoading,
  };
}