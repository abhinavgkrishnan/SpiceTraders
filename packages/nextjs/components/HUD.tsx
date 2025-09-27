"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { usePlayerState } from "@/hooks/usePlayerState";
import { useBalances } from "@/hooks/useBalances";
import { useShipDetails } from "@/hooks/useShipDetails";
import { PLANET_NAMES, RESOURCE_NAMES } from "@/constants/contracts";
import { Rocket, MapPin, Coins } from "lucide-react";

export function HUD() {
  const { currentPlanetId, activeShipId, isTraveling, destinationPlanetId } =
    usePlayerState();
  const { credits, metal, sapho, water, spice } = useBalances();
  const { ship } = useShipDetails(activeShipId);

  return (
    <Card className="border-amber-900/50 bg-gradient-to-br from-card to-amber-950/20">
      <CardHeader className="pb-3">
        <CardTitle className="text-amber-500 flex items-center gap-2">
          <Rocket className="h-5 w-5" />
          {ship?.name || "Loading..."}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-center gap-2 text-sm">
          <MapPin className="h-4 w-4 text-amber-400" />
          <span className="text-muted-foreground">Location:</span>
          <span className="text-foreground font-medium">
            {isTraveling
              ? `En route to ${PLANET_NAMES[destinationPlanetId]}`
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