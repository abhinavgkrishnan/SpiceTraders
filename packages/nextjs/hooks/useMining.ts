import { useWriteContract, useReadContract, useAccount } from "wagmi";
import { CONTRACTS } from "@/constants/contracts";
import { MiningABI } from "@/constants/abis";
import { useState, useEffect } from "react";

export function useMining() {
  const { address } = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();
  const [cooldownRemaining, setCooldownRemaining] = useState(0);

  const { data: lastMiningTimestamp } = useReadContract({
    address: CONTRACTS.Mining,
    abi: MiningABI,
    functionName: "lastMiningTimestamp",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
      refetchInterval: 1000,
    },
  });

  const { data: miningFee } = useReadContract({
    address: CONTRACTS.Mining,
    abi: MiningABI,
    functionName: "getMiningFee",
    query: {
      enabled: true,
      refetchInterval: 30000,
    },
  });

  useEffect(() => {
    if (!lastMiningTimestamp) return;

    const updateCooldown = () => {
      const now = Math.floor(Date.now() / 1000);
      const lastMined = Number(lastMiningTimestamp);
      const nextMineTime = lastMined + 60;
      const remaining = Math.max(0, nextMineTime - now);
      setCooldownRemaining(remaining);
    };

    updateCooldown();
    const interval = setInterval(updateCooldown, 1000);

    return () => clearInterval(interval);
  }, [lastMiningTimestamp]);

  const mine = async () => {
    if (!address) throw new Error("No wallet connected");
    if (cooldownRemaining > 0) throw new Error("Mining cooldown active");
    if (!miningFee) throw new Error("Mining fee not loaded");

    const hash = await writeContractAsync({
      address: CONTRACTS.Mining,
      abi: MiningABI,
      functionName: "mine",
      value: miningFee as bigint,
    });

    return hash;
  };

  return {
    mine,
    isPending,
    cooldownRemaining,
    canMine: cooldownRemaining === 0 && !isPending,
  };
}