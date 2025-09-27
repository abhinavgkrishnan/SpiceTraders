"use client";

import { useState } from "react";
import { useWriteContract, useAccount } from "wagmi";
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
  const { writeContractAsync, isPending } = useWriteContract();
  const { toast } = useToast();
  const [shipName, setShipName] = useState("");

  const handleOnboard = async () => {
    if (!address || !shipName.trim()) return;

    try {
      await writeContractAsync({
        address: CONTRACTS.Player,
        abi: PlayerABI,
        functionName: "onboardNewPlayer",
        args: [address, shipName.trim()],
      });

      toast({
        title: "Welcome, Commander!",
        description: `${shipName} is ready for duty`,
      });

      setTimeout(() => {
        onSuccess();
      }, 2000);
    } catch (error: any) {
      toast({
        title: "Onboarding Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  return (
    <Dialog open={open}>
      <DialogContent className="sm:max-w-[425px]" onPointerDownOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="text-amber-500 flex items-center gap-2 text-2xl">
            <Rocket className="h-6 w-6" />
            Welcome to Space Traders
          </DialogTitle>
          <DialogDescription>
            Begin your journey across the stars. You'll receive:
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
            disabled={!shipName.trim() || isPending}
            size="lg"
            className="w-full"
          >
            {isPending ? "Initializing..." : "Begin Journey"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}