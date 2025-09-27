"use client";

import { useState } from "react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { usePlayerState } from "@/hooks/usePlayerState";
import { useBalances } from "@/hooks/useBalances";
import { useMarket, useQuote } from "@/hooks/useMarket";
import { useToast } from "@/hooks/use-toast";
import { RESOURCE_NAMES, RESOURCES } from "@/constants/contracts";
import { TrendingUp, ArrowRightLeft } from "lucide-react";
import { formatUnits } from "viem";

export function MarketCard() {
  const { currentPlanetId } = usePlayerState();
  const { metal, sapho, water, spice, credits, refetchAll } = useBalances();
  const { executeTrade, isPending } = useMarket();
  const { toast } = useToast();

  const [selectedResource, setSelectedResource] = useState<number | null>(null);
  const [amountIn, setAmountIn] = useState("");
  const [sellMode, setSellMode] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);

  const { quoteAmount } = useQuote(
    currentPlanetId,
    selectedResource || 0,
    sellMode,
    amountIn
  );

  const resources = [
    { id: RESOURCES.METAL, name: RESOURCE_NAMES[0], balance: metal },
    { id: RESOURCES.SAPHO_JUICE, name: RESOURCE_NAMES[1], balance: sapho },
    { id: RESOURCES.WATER, name: RESOURCE_NAMES[2], balance: water },
    { id: RESOURCES.SPICE, name: RESOURCE_NAMES[3], balance: spice },
  ];

  const handleTradeClick = (resourceId: number, sell: boolean) => {
    setSelectedResource(resourceId);
    setSellMode(sell);
    setAmountIn("");
    setDialogOpen(true);
  };

  const handleTrade = async () => {
    if (selectedResource === null || !amountIn || Number(amountIn) <= 0) return;

    try {
      await executeTrade(currentPlanetId, selectedResource, sellMode, amountIn, 5);
      toast({
        title: "Trade Successful!",
        description: `Swapped ${amountIn} ${
          sellMode ? RESOURCE_NAMES[selectedResource] : "Solaris"
        }`,
      });
      setDialogOpen(false);
      setAmountIn("");
      setTimeout(() => refetchAll(), 2000);
    } catch (error: any) {
      toast({
        title: "Trade Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const selectedResourceData = resources.find((r) => r.id === selectedResource);

  return (
    <Card className="border-amber-900/50">
      <CardHeader>
        <CardTitle className="text-amber-500 flex items-center gap-2">
          <TrendingUp className="h-5 w-5" />
          Market
        </CardTitle>
        <CardDescription>Trade resources for Solaris</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {resources.map((resource) => (
          <div
            key={resource.id}
            className="flex items-center justify-between p-3 rounded-lg border border-border hover:border-amber-500/30 transition-colors"
          >
            <div>
              <p className="font-medium">{resource.name}</p>
              <p className="text-xs text-muted-foreground">
                Balance: {resource.balance}
              </p>
            </div>
            <div className="flex gap-2">
              <Dialog
                open={
                  dialogOpen && selectedResource === resource.id && sellMode
                }
                onOpenChange={(open) => {
                  if (!open && sellMode && selectedResource === resource.id) {
                    setDialogOpen(false);
                  }
                }}
              >
                <DialogTrigger asChild>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleTradeClick(resource.id, true)}
                    disabled={resource.balance === 0 || currentPlanetId === 0}
                  >
                    Sell
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle className="text-amber-500">
                      Sell {resource.name}
                    </DialogTitle>
                    <DialogDescription>
                      Trade {resource.name} for Solaris
                    </DialogDescription>
                  </DialogHeader>

                  <div className="space-y-4 py-4">
                    <div>
                      <label className="text-sm font-medium mb-2 block">
                        Amount to sell
                      </label>
                      <div className="flex gap-2">
                        <Input
                          type="number"
                          placeholder="0"
                          value={amountIn}
                          onChange={(e) => setAmountIn(e.target.value)}
                          max={resource.balance}
                        />
                        <Button
                          variant="outline"
                          onClick={() => setAmountIn(String(resource.balance))}
                        >
                          MAX
                        </Button>
                      </div>
                      <p className="text-xs text-muted-foreground mt-1">
                        Available: {resource.balance}
                      </p>
                    </div>

                    {Number(amountIn) > 0 && (
                      <div className="flex items-center justify-center gap-2 py-2">
                        <span className="text-lg font-medium">{amountIn}</span>
                        <ArrowRightLeft className="h-4 w-4 text-amber-400" />
                        <span className="text-lg font-medium text-amber-400">
                          ~{formatUnits(BigInt(quoteAmount || 0), 18)} Solaris
                        </span>
                      </div>
                    )}
                  </div>

                  <DialogFooter>
                    <Button
                      variant="outline"
                      onClick={() => setDialogOpen(false)}
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={handleTrade}
                      disabled={
                        !amountIn ||
                        Number(amountIn) <= 0 ||
                        Number(amountIn) > resource.balance ||
                        isPending
                      }
                    >
                      {isPending ? "Trading..." : "Confirm Trade"}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Dialog
                open={
                  dialogOpen && selectedResource === resource.id && !sellMode
                }
                onOpenChange={(open) => {
                  if (!open && !sellMode && selectedResource === resource.id) {
                    setDialogOpen(false);
                  }
                }}
              >
                <DialogTrigger asChild>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleTradeClick(resource.id, false)}
                    disabled={currentPlanetId === 0}
                  >
                    Buy
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle className="text-amber-500">
                      Buy {resource.name}
                    </DialogTitle>
                    <DialogDescription>
                      Trade Solaris for {resource.name}
                    </DialogDescription>
                  </DialogHeader>

                  <div className="space-y-4 py-4">
                    <div>
                      <label className="text-sm font-medium mb-2 block">
                        Amount of Solaris to spend
                      </label>
                      <Input
                        type="number"
                        placeholder="0"
                        value={amountIn}
                        onChange={(e) => setAmountIn(e.target.value)}
                        step="0.01"
                      />
                      <p className="text-xs text-muted-foreground mt-1">
                        Available: {parseFloat(credits).toFixed(2)} Solaris
                      </p>
                    </div>

                    {Number(amountIn) > 0 && (
                      <div className="flex items-center justify-center gap-2 py-2">
                        <span className="text-lg font-medium text-amber-400">
                          {amountIn} Solaris
                        </span>
                        <ArrowRightLeft className="h-4 w-4 text-amber-400" />
                        <span className="text-lg font-medium">
                          ~{quoteAmount} {resource.name}
                        </span>
                      </div>
                    )}
                  </div>

                  <DialogFooter>
                    <Button
                      variant="outline"
                      onClick={() => setDialogOpen(false)}
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={handleTrade}
                      disabled={
                        !amountIn ||
                        Number(amountIn) <= 0 ||
                        Number(amountIn) > Number(credits) ||
                        isPending
                      }
                    >
                      {isPending ? "Trading..." : "Confirm Trade"}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}