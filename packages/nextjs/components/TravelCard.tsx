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
import { usePlanets, useTravelCost } from "@/hooks/usePlanets";
import { useTravel } from "@/hooks/useTravel";
import { useShipDetails } from "@/hooks/useShipDetails";
import { useToast } from "@/hooks/use-toast";
import { PLANET_NAMES } from "@/constants/contracts";
import { Rocket, MapPin, Fuel, Clock } from "lucide-react";

export function TravelCard() {
  const { currentPlanetId, activeShipId, isTraveling, travelTimeRemaining } =
    usePlayerState();
  const { planets } = usePlanets();
  const { ship } = useShipDetails(activeShipId);
  const { startTravel, finishTravel, isTraveling: isInitiating, isCompleting } =
    useTravel();
  const { toast } = useToast();
  const [selectedPlanet, setSelectedPlanet] = useState<number | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  const { spiceCost, timeCost } = useTravelCost(
    currentPlanetId,
    selectedPlanet || 0
  );

  const handleTravelClick = (planetId: number) => {
    setSelectedPlanet(planetId);
    setDialogOpen(true);
  };

  const handleConfirmTravel = async () => {
    if (!selectedPlanet) return;

    try {
      await startTravel(selectedPlanet);
      toast({
        title: "Journey Started!",
        description: `Traveling to ${PLANET_NAMES[selectedPlanet]}`,
      });
      setDialogOpen(false);
    } catch (error: any) {
      toast({
        title: "Travel Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const handleCompleteTravel = async () => {
    try {
      await finishTravel();
      toast({
        title: "Arrived!",
        description: "You have reached your destination",
      });
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const canComplete = isTraveling && travelTimeRemaining === 0;

  return (
    <Card className="border-amber-900/50">
      <CardHeader>
        <CardTitle className="text-amber-500 flex items-center gap-2">
          <Rocket className="h-5 w-5" />
          Travel
        </CardTitle>
        {isTraveling && (
          <CardDescription className="text-amber-400">
            {canComplete
              ? "Arrival complete - dock at station"
              : `Arriving in ${travelTimeRemaining}s`}
          </CardDescription>
        )}
      </CardHeader>
      <CardContent className="space-y-3">
        {canComplete && (
          <Button
            onClick={handleCompleteTravel}
            disabled={isCompleting}
            className="w-full mb-4"
          >
            Complete Travel
          </Button>
        )}

        {planets.map((planet) => {
          if (!planet || planet.id === currentPlanetId) return null;

          return (
            <Dialog
              key={planet.id}
              open={dialogOpen && selectedPlanet === planet.id}
              onOpenChange={(open) => {
                setDialogOpen(open);
                if (!open) setSelectedPlanet(null);
              }}
            >
              <DialogTrigger asChild>
                <Button
                  variant="outline"
                  className="w-full justify-between hover:border-amber-500/50"
                  onClick={() => handleTravelClick(planet.id)}
                  disabled={isTraveling}
                >
                  <span className="flex items-center gap-2">
                    <MapPin className="h-4 w-4" />
                    {planet.name}
                  </span>
                  <span className="text-xs text-muted-foreground">→</span>
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle className="text-amber-500">
                    Travel to {planet.name}?
                  </DialogTitle>
                  <DialogDescription>
                    Review travel requirements before departing
                  </DialogDescription>
                </DialogHeader>

                <div className="space-y-4 py-4">
                  <div className="flex items-center justify-between">
                    <span className="flex items-center gap-2 text-sm">
                      <Fuel className="h-4 w-4 text-amber-400" />
                      Spice Cost
                    </span>
                    <span
                      className={
                        ship && ship.currentSpice >= spiceCost
                          ? "text-foreground font-medium"
                          : "text-destructive font-medium"
                      }
                    >
                      {spiceCost} / {ship?.currentSpice || 0}
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="flex items-center gap-2 text-sm">
                      <Clock className="h-4 w-4 text-amber-400" />
                      Travel Time
                    </span>
                    <span className="text-foreground font-medium">{timeCost}s</span>
                  </div>

                  {ship && ship.currentSpice < spiceCost && (
                    <p className="text-destructive text-sm">
                      Insufficient spice fuel for this journey
                    </p>
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
                    onClick={handleConfirmTravel}
                    disabled={
                      !ship ||
                      ship.currentSpice < spiceCost ||
                      isInitiating
                    }
                  >
                    {isInitiating ? "Departing..." : "Depart"}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          );
        })}
      </CardContent>
    </Card>
  );
}