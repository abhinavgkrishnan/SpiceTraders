"use client";

import { useState, useEffect } from "react";
import { useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import { CONTRACTS } from "@/constants/contracts";
import { PlayerABI } from "@/constants/abis";
import { Rocket } from "lucide-react";

interface OnboardingDialogProps {
  open: boolean;
  onSuccess: () => void;
}

export function OnboardingDialog({ open, onSuccess }: OnboardingDialogProps) {
  const { address } = useAccount();
  const { writeContractAsync, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  const { toast } = useToast();
  const [shipName, setShipName] = useState("");

  const handleOnboard = async () => {
    if (!address || !shipName.trim()) return;

    try {
      const txHash = await writeContractAsync({
        address: CONTRACTS.Player,
        abi: PlayerABI,
        functionName: "onboardNewPlayer",
        args: [address, shipName.trim()],
      });

      toast({
        title: "Transaction Submitted",
        description: "Waiting for confirmation...",
      });
    } catch (error: any) {
      toast({
        title: "Onboarding Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  // Watch for transaction success
  useEffect(() => {
    if (isSuccess && hash) {
      toast({
        title: "Welcome, Commander!",
        description: `${shipName} is ready for duty`,
      });
      setTimeout(() => {
        onSuccess();
      }, 1000);
    }
  }, [isSuccess, hash, shipName, onSuccess, toast]);

  return (
    <Dialog open={open}>
      <DialogContent className="sm:max-w-[425px]" onPointerDownOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="text-amber-500 flex items-center gap-2 text-2xl">
            <Rocket className="h-6 w-6" />
            Welcome to Spice Traders
          </DialogTitle>
          <DialogDescription>
            Begin your journey across the stars. You&apos;ll receive:
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-sm">
              <span className="text-amber-400">✓</span>
              <span>Atreides Scout Ship</span>
            </div>
            <div className="flex items-center gap-2 text-sm">
              <span className="text-amber-400">✓</span>
              <span>1,500 Solaris starting credits</span>
            </div>
            <div className="flex items-center gap-2 text-sm">
              <span className="text-amber-400">✓</span>
              <span>2,000 units of spice fuel</span>
            </div>
            <div className="flex items-center gap-2 text-sm">
              <span className="text-amber-400">✓</span>
              <span>Stationed at Caladan</span>
            </div>
          </div>

          <div className="space-y-2">
            <label htmlFor="shipName" className="text-sm font-medium">
              Name your ship
            </label>
            <Input
              id="shipName"
              placeholder="e.g., Atreides Glory"
              value={shipName}
              onChange={(e) => setShipName(e.target.value)}
              maxLength={32}
              disabled={isPending}
            />
          </div>
        </div>

        <DialogFooter>
          <Button
            onClick={handleOnboard}
            disabled={!shipName.trim() || isPending || isConfirming}
            size="lg"
            className="w-full"
          >
            {isPending ? "Confirming in wallet..." : isConfirming ? "Waiting for confirmation..." : "Begin Journey"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}