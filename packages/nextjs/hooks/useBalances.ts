import { useReadContract, useAccount } from "wagmi";
import { CONTRACTS, RESOURCES } from "@/constants/contracts";
import { CreditsABI, TokensABI } from "@/constants/abis";
import { formatUnits } from "viem";

export function useBalances() {
  const { address } = useAccount();

  const { data: credits, refetch: refetchCredits } = useReadContract({
    address: CONTRACTS.Credits,
    abi: CreditsABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: metal, refetch: refetchMetal } = useReadContract({
    address: CONTRACTS.Tokens,
    abi: TokensABI,
    functionName: "balanceOf",
    args: address ? [address, BigInt(RESOURCES.METAL)] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: sapho, refetch: refetchSapho } = useReadContract({
    address: CONTRACTS.Tokens,
    abi: TokensABI,
    functionName: "balanceOf",
    args: address ? [address, BigInt(RESOURCES.SAPHO_JUICE)] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: water, refetch: refetchWater } = useReadContract({
    address: CONTRACTS.Tokens,
    abi: TokensABI,
    functionName: "balanceOf",
    args: address ? [address, BigInt(RESOURCES.WATER)] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const { data: spice, refetch: refetchSpice } = useReadContract({
    address: CONTRACTS.Tokens,
    abi: TokensABI,
    functionName: "balanceOf",
    args: address ? [address, BigInt(RESOURCES.SPICE)] : undefined,
    query: {
      enabled: !!address,
    },
  });

  const refetchAll = () => {
    refetchCredits();
    refetchMetal();
    refetchSapho();
    refetchWater();
    refetchSpice();
  };

  return {
    credits: credits ? formatUnits(credits, 18) : "0",
    creditsRaw: credits || 0n,
    metal: Number(metal || 0n),
    sapho: Number(sapho || 0n),
    water: Number(water || 0n),
    spice: Number(spice || 0n),
    refetchAll,
  };
}