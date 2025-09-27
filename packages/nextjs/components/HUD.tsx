"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { useShipDetails } from "@/hooks/useShipDetails";
import { useOwnedShips, useSwitchShip, useRefuelShip } from "@/hooks/useShips";
import { useToast } from "@/hooks/use-toast";
import { PLANET_NAMES, RESOURCE_NAMES } from "@/constants/contracts";
import { Rocket, MapPin, Coins, ChevronDown, Fuel } from "lucide-react";

const SHIP_CLASS_NAMES = ["Scout", "Frigate", "Harvester", "Dreadnought"];

export function HUD() {
  const { currentPlanetId, activeShipId, isTraveling, travelTimeRemaining, destinationPlanetId, refetch: refetchPlayer } =
    usePlayerState();
  const { credits, metal, sapho, water, spice, refetchAll } = useBalances();
  const { ship } = useShipDetails(activeShipId);
  const { shipIds } = useOwnedShips();
  const { switchShip, isPending: isSwitching } = useSwitchShip();
  const { refuel, isPending: isRefueling } = useRefuelShip();
  const { toast } = useToast();

  const [showShipSelector, setShowShipSelector] = useState(false);
  const [showRefuelDialog, setShowRefuelDialog] = useState(false);
  const [refuelAmount, setRefuelAmount] = useState("");

  const handleSwitchShip = async (shipId: number) => {
    try {
      await switchShip(shipId);
      toast({
        title: "Ship Changed!",
        description: "Your active ship has been updated",
      });
      setShowShipSelector(false);
      setTimeout(() => refetchPlayer(), 2000);
    } catch (error: any) {
      toast({
        title: "Failed to Switch Ship",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const handleRefuel = async () => {
    if (!refuelAmount || Number(refuelAmount) <= 0) return;

    try {
      await refuel(activeShipId, Number(refuelAmount));
      toast({
        title: "Refueled!",
        description: `Added ${refuelAmount} spice to your ship`,
      });
      setShowRefuelDialog(false);
      setRefuelAmount("");
      setTimeout(() => {
        refetchPlayer();
        refetchAll();
      }, 2000);
    } catch (error: any) {
      toast({
        title: "Refuel Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const maxRefuel = ship ? Math.min(spice, ship.spiceCapacity - ship.currentSpice) : 0;

  return (
    <Card className="border-amber-900/50 bg-gradient-to-br from-card to-amber-950/20">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <Dialog open={showShipSelector} onOpenChange={setShowShipSelector}>
            <DialogTrigger asChild>
              <Button
                variant="ghost"
                className="text-amber-500 hover:text-amber-400 hover:bg-amber-950/20 p-0 h-auto font-semibold text-lg"
                disabled={isTraveling}
              >
                <Rocket className="h-5 w-5 mr-2" />
                {ship?.name || "Loading..."}
                {shipIds.length > 1 && <ChevronDown className="h-4 w-4 ml-1" />}
              </Button>
            </DialogTrigger>
            {shipIds.length > 1 && (
              <DialogContent>
                <DialogHeader>
                  <DialogTitle className="text-amber-500">Select Ship</DialogTitle>
                  <DialogDescription>
                    Choose which ship to make active
                  </DialogDescription>
                </DialogHeader>
                <div className="space-y-2 py-4">
                  {shipIds.map((shipId) => {
                    const ShipDetails = () => {
                      const { ship: s } = useShipDetails(shipId);
                      return (
                        <Button
                          key={shipId}
                          variant={shipId === activeShipId ? "default" : "outline"}
                          className="w-full justify-between"
                          onClick={() => handleSwitchShip(shipId)}
                          disabled={shipId === activeShipId || isSwitching}
                        >
                          <span>
                            {s?.name || `Ship #${shipId}`}{" "}
                            <span className="text-xs text-muted-foreground">
                              ({SHIP_CLASS_NAMES[s?.shipClass || 0]})
                            </span>
                          </span>
                          {shipId === activeShipId && (
                            <span className="text-xs">Active</span>
                          )}
                        </Button>
                      );
                    };
                    return <ShipDetails key={shipId} />;
                  })}
                </div>
              </DialogContent>
            )}
          </Dialog>

          {ship && (
            <Dialog open={showRefuelDialog} onOpenChange={setShowRefuelDialog}>
              <DialogTrigger asChild>
                <Button
                  size="sm"
                  variant="outline"
                  className="gap-1"
                  disabled={isTraveling || spice === 0 || ship.currentSpice >= ship.spiceCapacity}
                >
                  <Fuel className="h-3 w-3" />
                  Refuel
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle className="text-amber-500">Refuel Ship</DialogTitle>
                  <DialogDescription>
                    Convert SPICE tokens to ship fuel
                  </DialogDescription>
                </DialogHeader>

                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span>Current Fuel:</span>
                      <span>
                        {ship.currentSpice} / {ship.spiceCapacity}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Available SPICE:</span>
                      <span className="text-amber-400">{spice}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Can Refuel:</span>
                      <span className="text-amber-400">{maxRefuel} max</span>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-medium">Amount of SPICE</label>
                    <div className="flex gap-2">
                      <Input
                        type="number"
                        placeholder="0"
                        value={refuelAmount}
                        onChange={(e) => setRefuelAmount(e.target.value)}
                        max={maxRefuel}
                      />
                      <Button
                        variant="outline"
                        onClick={() => setRefuelAmount(String(maxRefuel))}
                      >
                        MAX
                      </Button>
                    </div>
                  </div>
                </div>

                <DialogFooter>
                  <Button
                    variant="outline"
                    onClick={() => setShowRefuelDialog(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleRefuel}
                    disabled={
                      !refuelAmount ||
                      Number(refuelAmount) <= 0 ||
                      Number(refuelAmount) > maxRefuel ||
                      isRefueling
                    }
                  >
                    {isRefueling ? "Refueling..." : "Refuel"}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          )}
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-center gap-2 text-sm">
          <MapPin className="h-4 w-4 text-amber-400" />
          <span className="text-muted-foreground">Location:</span>
          <span className="text-foreground font-medium">
            {isTraveling && travelTimeRemaining > 0
              ? `En route to ${PLANET_NAMES[destinationPlanetId] || "Unknown"} (${travelTimeRemaining}s)`
              : isTraveling && travelTimeRemaining === 0
              ? `Arrived at ${PLANET_NAMES[destinationPlanetId] || "Unknown"}`
              : PLANET_NAMES[currentPlanetId] || "Unknown"}
          </span>
        </div>

        <div className="flex items-center gap-2 text-sm">
          <Coins className="h-4 w-4 text-amber-400" />
          <span className="text-muted-foreground">Solaris:</span>
          <span className="text-amber-300 font-bold">
            {parseFloat(credits).toLocaleString(undefined, {
              maximumFractionDigits: 2,
            })}
          </span>
        </div>

        {ship && (
          <>
            <div className="text-sm">
              <span className="text-muted-foreground">Spice Fuel:</span>
              <div className="flex items-center gap-2 mt-1">
                <div className="flex-1 bg-secondary rounded-full h-2 overflow-hidden">
                  <div
                    className="h-full bg-amber-500 transition-all"
                    style={{
                      width: `${(ship.currentSpice / ship.spiceCapacity) * 100}%`,
                    }}
                  />
                </div>
                <span className="text-xs text-foreground">
                  {ship.currentSpice}/{ship.spiceCapacity}
                </span>
              </div>
            </div>

            <div className="text-sm">
              <span className="text-muted-foreground">Cargo Hold:</span>
              <div className="flex items-center gap-2 mt-1">
                <div className="flex-1 bg-secondary rounded-full h-2 overflow-hidden">
                  <div
                    className="h-full bg-blue-500 transition-all"
                    style={{
                      width: `${((metal + sapho + water + spice) / ship.cargoCapacity) * 100}%`,
                    }}
                  />
                </div>
                <span className="text-xs text-foreground">
                  {metal + sapho + water + spice}/{ship.cargoCapacity}
                </span>
              </div>
            </div>
          </>
        )}

        <div className="pt-2 border-t border-border">
          <p className="text-xs text-muted-foreground mb-2">Cargo Hold</p>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">{RESOURCE_NAMES[0]}:</span>
              <span className="text-foreground font-medium">{metal}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">{RESOURCE_NAMES[1]}:</span>
              <span className="text-foreground font-medium">{sapho}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">{RESOURCE_NAMES[2]}:</span>
              <span className="text-foreground font-medium">{water}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">{RESOURCE_NAMES[3]}:</span>
              <span className="text-amber-300 font-medium">{spice}</span>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}