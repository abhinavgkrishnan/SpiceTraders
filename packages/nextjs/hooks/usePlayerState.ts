import { useReadContract, useAccount } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { PlayerABI } from "@/constants/abis";

export function usePlayerState() {
  const { address } = useAccount();

  const { data: isRegistered, isLoading: isLoadingRegistered } = useReadContract({
    address: CONTRACTS.Player,
    abi: PlayerABI,
    functionName: "isPlayerRegistered",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: playerState, isLoading: isLoadingState, refetch } = useReadContract({
    address: CONTRACTS.Player,
    abi: PlayerABI,
    functionName: "getPlayerState",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!isRegistered,
    },
  });

  const isTraveling = playerState ? Number(playerState.currentTripEndTime) > Date.now() / 1000 : false;

  return {
    isRegistered: !!isRegistered,
    playerState,
    currentPlanetId: playerState ? Number(playerState.currentPlanetId) : 0,
    activeShipId: playerState ? Number(playerState.activeShipId) : 0,
    isTraveling,
    travelEndTime: playerState ? Number(playerState.currentTripEndTime) : 0,
    destinationPlanetId: playerState ? Number(playerState.currentTripToPlanetId) : 0,
    isLoading: isLoadingRegistered || isLoadingState,
    refetch,
  };
}