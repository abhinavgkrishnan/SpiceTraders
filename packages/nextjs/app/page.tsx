"use client";

import { useEffect, useState } from "react";
import { ConnectKitButton } from "connectkit";
import { useAccount } from "wagmi";
import { usePlayerState } from "@/hooks/usePlayerState";
import { HUD } from "@/components/HUD";
import { MineButton } from "@/components/MineButton";
import { TravelCard } from "@/components/TravelCard";
import { MarketCard } from "@/components/MarketCard";
import { BuyShipCard } from "@/components/BuyShipCard";
import { OnboardingDialog } from "@/components/OnboardingDialog";
import { Toaster } from "@/components/ui/toaster";
import { Rocket } from "lucide-react";

export default function Home() {
  const { address, isConnected } = useAccount();
  const { isRegistered, isLoading, hasError, refetch } = usePlayerState();
  const [showOnboarding, setShowOnboarding] = useState(false);

  useEffect(() => {
    if (isConnected && !isLoading && !isRegistered && !hasError) {
      setShowOnboarding(true);
    } else {
      setShowOnboarding(false);
    }
  }, [isConnected, isLoading, isRegistered, hasError]);

  const handleOnboardingSuccess = () => {
    setShowOnboarding(false);
    refetch();
  };

  return (
    <main className="min-h-screen bg-background p-4">
      <div className="max-w-md mx-auto space-y-4">
        <header className="flex items-center justify-between py-4">
          <div className="flex items-center gap-2">
            <Rocket className="h-8 w-8 text-amber-500" />
            <h1 className="text-2xl font-bold text-amber-500">Spice Traders</h1>
          </div>
          <ConnectKitButton />
        </header>

        {!isConnected ? (
          <div className="flex flex-col items-center justify-center py-20 space-y-4">
            <Rocket className="h-20 w-20 text-amber-500/50" />
            <h2 className="text-xl font-semibold text-muted-foreground">
              Connect your wallet to begin
            </h2>
            <p className="text-sm text-muted-foreground text-center max-w-sm">
              Trade resources, mine on distant planets, and build your fortune across the stars
            </p>
          </div>
        ) : isLoading ? (
          <div className="flex items-center justify-center py-20">
            <div className="text-center space-y-2">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-amber-500 mx-auto" />
              <p className="text-sm text-muted-foreground">Loading...</p>
            </div>
          </div>
        ) : isRegistered ? (
          <>
            <HUD />
            <MineButton />
            <TravelCard />
            <MarketCard />
            <BuyShipCard />
          </>
        ) : null}

        <OnboardingDialog open={showOnboarding} onSuccess={handleOnboardingSuccess} />
      </div>

      <Toaster />
    </main>
  );
}