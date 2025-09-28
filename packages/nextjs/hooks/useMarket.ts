import { useReadContract, useWriteContract } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { MarketABI } from "@/constants/abis";
import { parseUnits } from "viem";

export function useMarket() {
  const { writeContractAsync, isPending } = useWriteContract();

  const executeTrade = async (
    planetId: number,
    resourceId: number,
    resourceToCredits: boolean,
    amountIn: string,
    slippage: number = 5
  ) => {
    const amountInBig = parseUnits(amountIn, 18);
    const minAmountOut = (amountInBig * BigInt(100 - slippage)) / 100n;

    const hash = await writeContractAsync({
      address: CONTRACTS.Market,
      abi: MarketABI,
      functionName: "executeTrade",
      args: [
        BigInt(planetId),
        BigInt(resourceId),
        resourceToCredits,
        amountInBig,
        minAmountOut,
      ],
    });

    return hash;
  };

  return {
    executeTrade,
    isPending,
  };
}

export function useQuote(
  planetId: number,
  resourceId: number,
  resourceToCredits: boolean,
  amountIn: string
) {
  const amountInBig =
    amountIn && Number(amountIn) > 0 ? parseUnits(amountIn, 18) : 0n;

  const { data: quote, isLoading } = useReadContract({
    address: CONTRACTS.Market,
    abi: MarketABI,
    functionName: "getQuote",
    args:
      planetId > 0 && amountInBig > 0
        ? [
            BigInt(planetId),
            BigInt(resourceId),
            resourceToCredits,
            amountInBig,
          ]
        : undefined,
    query: {
      enabled: planetId > 0 && amountInBig > 0,
    },
  });

  return {
    quoteAmount: quote ? String(quote) : "0",
    isLoading,
  };
}