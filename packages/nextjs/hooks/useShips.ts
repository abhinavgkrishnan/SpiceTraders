import { useReadContract, useWriteContract, useAccount } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { ShipsABI, PlayerABI } from "@/constants/abis";

export function useOwnedShips() {
  const { address } = useAccount();

  const { data: shipIds, refetch } = useReadContract({
    address: CONTRACTS.Ships,
    abi: ShipsABI,
    functionName: "getShipsByOwner",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  return {
    shipIds: shipIds ? shipIds.map(id => Number(id)) : [],
    refetch,
  };
}

export function useSwitchShip() {
  const { writeContractAsync, isPending } = useWriteContract();

  const switchShip = async (shipId: number) => {
    const hash = await writeContractAsync({
      address: CONTRACTS.Player,
      abi: PlayerABI,
      functionName: "setActiveShip",
      args: [BigInt(shipId)],
    });

    return hash;
  };

  return {
    switchShip,
    isPending,
  };
}

export function useBuyShip() {
  const { writeContractAsync, isPending } = useWriteContract();

  const buyShip = async (shipName: string, shipClass: number) => {
    const hash = await writeContractAsync({
      address: CONTRACTS.Player,
      abi: PlayerABI,
      functionName: "buyShip",
      args: [shipName, BigInt(shipClass)],
    });

    return hash;
  };

  return {
    buyShip,
    isPending,
  };
}

export function useRefuelShip() {
  const { writeContractAsync, isPending } = useWriteContract();

  const refuel = async (shipId: number, spiceAmount: number) => {
    const hash = await writeContractAsync({
      address: CONTRACTS.Player,
      abi: PlayerABI,
      functionName: "refuelShip",
      args: [BigInt(shipId), BigInt(spiceAmount)],
    });

    return hash;
  };

  return {
    refuel,
    isPending,
  };
}

export function useShipPrice(shipClass: number) {
  const { data: price } = useReadContract({
    address: CONTRACTS.Ships,
    abi: ShipsABI,
    functionName: "getShipPrice",
    args: [BigInt(shipClass)],
    query: {
      enabled: shipClass >= 0 && shipClass <= 3,
    },
  });

  return {
    price: price ? String(price) : "0",
  };
}