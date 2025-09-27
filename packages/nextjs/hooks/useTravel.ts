import { useWriteContract } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { PlayerABI } from "@/constants/abis";

export function useTravel() {
  const { writeContractAsync: instantTravel, isPending: isTraveling } = useWriteContract();
  const { writeContractAsync: completeTravel, isPending: isCompleting } = useWriteContract();

  const startTravel = async (toPlanetId: number) => {
    const hash = await instantTravel({
      address: CONTRACTS.Player,
      abi: PlayerABI,
      functionName: "instantTravel",
      args: [BigInt(toPlanetId)],
    });

    return hash;
  };

  const finishTravel = async () => {
    const hash = await completeTravel({
      address: CONTRACTS.Player,
      abi: PlayerABI,
      functionName: "completeTravel",
    });

    return hash;
  };

  return {
    startTravel,
    finishTravel,
    isTraveling,
    isCompleting,
  };
}