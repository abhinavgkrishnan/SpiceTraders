"use client";

import { useState, useMemo } from "react";
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
import { useBalances } from "@/hooks/useBalances";
import { useBuyShip, useShipPrice } from "@/hooks/useShips";
import { usePlayerState } from "@/hooks/usePlayerState";
import { useToast } from "@/hooks/use-toast";
import { useWorldPayment } from "@/hooks/useWorldPayment";
import { useMiniKit } from "@/components/MiniKitProvider";
import { ShoppingCart, Rocket } from "lucide-react";
import { formatUnits } from "viem";

const SHIP_CLASSES = [
  {
    id: 0,
    name: "Atreides Scout",
    cargo: 150,
    spice: 3000,
    speed: "1.0x",
    description: "Fast and nimble, perfect for scouting",
  },
  {
    id: 1,
    name: "Guild Frigate",
    cargo: 500,
    spice: 5000,
    speed: "1.2x",
    description: "Balanced speed and cargo capacity",
  },
  {
    id: 2,
    name: "Harkonnen Harvester",
    cargo: 1000,
    spice: 8000,
    speed: "0.8x",
    description: "Maximum cargo, slower but powerful",
  },
  {
    id: 3,
    name: "Imperial Dreadnought",
    cargo: 2000,
    spice: 12000,
    speed: "1.5x",
    description: "The ultimate ship, fast and massive",
  },
];

export function BuyShipCard() {
  const { credits, refetchAll } = useBalances();
  const { buyShip, isPending } = useBuyShip();
  const { isTraveling, refetch: refetchPlayer } = usePlayerState();
  const { toast } = useToast();
  const { isWorldApp } = useMiniKit();
  const { pay, isProcessing: isPaymentProcessing } = useWorldPayment();

  const [selectedClass, setSelectedClass] = useState<number | null>(null);
  const [shipName, setShipName] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  // Get price for the selected ship class - use 0 as default to avoid null
  const { price: selectedShipPrice } = useShipPrice(selectedClass ?? 0);
  
  // Memoize the price calculation to prevent unnecessary re-renders
  const priceFormatted = useMemo(() => {
    return formatUnits(BigInt(selectedShipPrice), 18);
  }, [selectedShipPrice]);

  const handleBuyClick = (classId: number) => {
    setSelectedClass(classId);
    setShipName("");
    setDialogOpen(true);
  };

  const handleBuy = async () => {
    if (selectedClass === null || !shipName.trim()) return;

    try {
      // In World App, use World payments
      if (isWorldApp) {
        const reference = `ship-${selectedClass}-${Date.now()}`;
        
        // Make payment through World App
        const paymentResult = await pay(
          priceFormatted, 
          "WLD", 
          reference,
          "0x0000000000000000000000000000000000000000", // TODO: Replace with actual recipient address
          `Purchase ${SHIP_CLASSES[selectedClass!].name} - ${shipName.trim()}`
        );
        
        if (paymentResult.status === "success") {
          // Verify payment on backend
          const verifyResponse = await fetch("/api/verify-payment", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ payload: paymentResult }),
          });
          
          const verification = await verifyResponse.json();
          
          if (verification.success) {
            // Proceed with ship purchase
            await buyShip(shipName.trim(), selectedClass);
            toast({
              title: "Ship Purchased!",
              description: `${SHIP_CLASSES[selectedClass].name} added to your fleet`,
            });
          } else {
            throw new Error("Payment verification failed");
          }
        } else {
          throw new Error("Payment failed");
        }
      } else {
        // Regular web flow
        await buyShip(shipName.trim(), selectedClass);
        toast({
          title: "Ship Purchased!",
          description: `${SHIP_CLASSES[selectedClass].name} added to your fleet`,
        });
      }
      
      setDialogOpen(false);
      setShipName("");
      setTimeout(() => {
        refetchPlayer();
        refetchAll();
      }, 2000);
    } catch (error: any) {
      toast({
        title: "Purchase Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const selectedShip = selectedClass !== null ? SHIP_CLASSES[selectedClass] : null;

  return (
    <Card className="border-amber-900/50">
      <CardHeader>
        <CardTitle className="text-amber-500 flex items-center gap-2">
          <ShoppingCart className="h-5 w-5" />
          Ship Dealer
        </CardTitle>
        <CardDescription>
          {isWorldApp ? "Expand your fleet with World payments" : "Expand your fleet"}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {SHIP_CLASSES.map((shipClass) => {
          const { price } = useShipPrice(shipClass.id);
          const shipPriceFormatted = formatUnits(BigInt(price), 18);
          const canAfford = Number(credits) >= Number(shipPriceFormatted);

          return (
            <div key={shipClass.id}>
              <div
                className={`p-3 rounded-lg border cursor-pointer transition-colors ${
                  canAfford
                    ? "border-border hover:border-amber-500/50"
                    : "border-destructive/30 opacity-60"
                }`}
                onClick={() => canAfford && handleBuyClick(shipClass.id)}
              >
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <p className="font-medium">{shipClass.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {shipClass.description}
                    </p>
                  </div>
                  <span className={`text-sm font-bold ${canAfford ? "text-amber-400" : "text-destructive"}`}>
                    {parseFloat(shipPriceFormatted).toLocaleString()} ☉
                  </span>
                </div>
                <div className="flex gap-4 text-xs text-muted-foreground">
                  <span>Cargo: {shipClass.cargo}</span>
                  <span>Spice: {shipClass.spice}</span>
                  <span>Speed: {shipClass.speed}</span>
                </div>
              </div>
              <Dialog
                open={dialogOpen && selectedClass === shipClass.id}
                onOpenChange={(open) => {
                  setDialogOpen(open);
                  if (!open) setSelectedClass(null);
                }}
              >
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle className="text-amber-500 flex items-center gap-2">
                      <Rocket className="h-5 w-5" />
                      Purchase {shipClass.name}
                    </DialogTitle>
                    <DialogDescription>
                      Name your new ship and confirm purchase
                    </DialogDescription>
                  </DialogHeader>

                  <div className="space-y-4 py-4">
                    <div className="space-y-2 p-3 bg-secondary/20 rounded-lg">
                      <div className="flex justify-between text-sm">
                        <span>Price:</span>
                        <span className="text-amber-400 font-bold">
                          {parseFloat(shipPriceFormatted).toLocaleString()} Solaris
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span>Your Balance:</span>
                        <span>
                          {parseFloat(credits).toLocaleString(undefined, {
                            maximumFractionDigits: 2,
                          })}{" "}
                          Solaris
                        </span>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <h4 className="font-medium text-sm">Ship Specifications</h4>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Cargo:</span>
                          <span>{shipClass.cargo} units</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Spice Tank:</span>
                          <span>{shipClass.spice} units</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Speed:</span>
                          <span>{shipClass.speed}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Class:</span>
                          <span>{shipClass.name}</span>
                        </div>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <label htmlFor="newShipName" className="text-sm font-medium">
                        Ship Name
                      </label>
                      <Input
                        id="newShipName"
                        placeholder="e.g., Desert Wind"
                        value={shipName}
                        onChange={(e) => setShipName(e.target.value)}
                        maxLength={32}
                      />
                    </div>
                  </div>

                  <DialogFooter>
                    <Button variant="outline" onClick={() => setDialogOpen(false)}>
                      Cancel
                    </Button>
                    <Button
                      onClick={handleBuy}
                      disabled={
                        !shipName.trim() ||
                        isPending ||
                        isPaymentProcessing ||
                        !canAfford
                      }
                    >
                      {isPending 
                        ? "Purchasing..." 
                        : isPaymentProcessing 
                        ? "Processing payment..." 
                        : isWorldApp 
                        ? "Pay with World" 
                        : "Purchase"
                      }
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}