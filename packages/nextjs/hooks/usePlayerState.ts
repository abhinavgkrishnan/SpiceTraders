import { useReadContract, useAccount } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { PlayerABI } from "@/constants/abis";
import { useState, useEffect } from "react";

export function usePlayerState() {
  const { address } = useAccount();
  const [currentTime, setCurrentTime] = useState(Math.floor(Date.now() / 1000));

  const { data: isRegistered, isLoading: isLoadingRegistered, error: errorRegistered, refetch: refetchRegistered } = useReadContract({
    address: CONTRACTS.Player,
    abi: PlayerABI,
    functionName: "isPlayerRegistered",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      retry: false,
    },
  });

  const { data: playerState, isLoading: isLoadingState, refetch: refetchState, error: errorState } = useReadContract({
    address: CONTRACTS.Player,
    abi: PlayerABI,
    functionName: "getPlayerState",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!isRegistered,
    },
  });

  if (errorRegistered) console.error("Error checking registration:", errorRegistered);
  if (errorState) console.error("Error fetching player state:", errorState);

  // If contract call fails, treat as not registered
  const hasError = !!errorRegistered || !!errorState;

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentTime(Math.floor(Date.now() / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const isTraveling = playerState ? Number(playerState.currentTripEndTime) > currentTime : false;
  const travelTimeRemaining = playerState ? Math.max(0, Number(playerState.currentTripEndTime) - currentTime) : 0;

  const refetch = async () => {
    await refetchRegistered();
    await refetchState();
  };

  return {
    isRegistered: hasError ? false : !!isRegistered,
    playerState,
    currentPlanetId: playerState ? Number(playerState.currentPlanetId) : 0,
    activeShipId: playerState ? Number(playerState.activeShipId) : 0,
    isTraveling,
    travelEndTime: playerState ? Number(playerState.currentTripEndTime) : 0,
    travelTimeRemaining,
    destinationPlanetId: playerState ? Number(playerState.currentTripToPlanetId) : 0,
    isLoading: (isLoadingRegistered || isLoadingState) && !hasError,
    hasError,
    refetch,
  };
}