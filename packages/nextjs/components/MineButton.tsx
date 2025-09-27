"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useMining } from "@/hooks/useMining";
import { usePlayerState } from "@/hooks/usePlayerState";
import { useBalances } from "@/hooks/useBalances";
import { useToast } from "@/hooks/use-toast";
import { Pickaxe, Clock } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

export function MineButton() {
  const { mine, isPending, cooldownRemaining, canMine } = useMining();
  const { isTraveling } = usePlayerState();
  const { refetchAll } = useBalances();
  const { toast } = useToast();
  const [showRewards, setShowRewards] = useState<{ resource: string; amount: number }[]>([]);

  const handleMine = async () => {
    try {
      await mine();
      toast({
        title: "Mining Complete!",
        description: "Resources added to your cargo hold",
      });
      setTimeout(() => refetchAll(), 2000);

      setShowRewards([
        { resource: "Metal", amount: Math.floor(Math.random() * 20) + 10 },
        { resource: "Water", amount: Math.floor(Math.random() * 15) + 5 },
        { resource: "Sapho", amount: Math.floor(Math.random() * 10) + 3 },
      ]);
      setTimeout(() => setShowRewards([]), 3000);
    } catch (error: any) {
      toast({
        title: "Mining Failed",
        description: error.message || "Transaction failed",
        variant: "destructive",
      });
    }
  };

  const formatTime = (seconds: number) => {
    if (seconds <= 0) return "Ready";
    return `${seconds}s`;
  };

  return (
    <Card className="border-amber-900/50 relative overflow-hidden">
      <CardHeader>
        <CardTitle className="text-amber-500 flex items-center gap-2">
          <Pickaxe className="h-5 w-5" />
          Mining Operation
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <Button
          onClick={handleMine}
          disabled={!canMine || isTraveling || isPending}
          size="lg"
          className="w-full text-lg font-bold relative overflow-hidden"
        >
          {isPending ? (
            "Mining..."
          ) : cooldownRemaining > 0 ? (
            <span className="flex items-center gap-2">
              <Clock className="h-5 w-5" />
              {formatTime(cooldownRemaining)}
            </span>
          ) : isTraveling ? (
            "Cannot mine while traveling"
          ) : (
            <>
              <Pickaxe className="h-5 w-5 mr-2" />
              MINE RESOURCES
            </>
          )}
        </Button>

        <AnimatePresence>
          {showRewards.map((reward, i) => (
            <motion.div
              key={`${reward.resource}-${i}`}
              initial={{ opacity: 0, y: 50, scale: 0.5 }}
              animate={{ opacity: 1, y: -100, scale: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 2, delay: i * 0.2 }}
              className="absolute right-8 bottom-20 pointer-events-none"
            >
              <span className="text-amber-400 font-bold text-2xl drop-shadow-lg">
                +{reward.amount} {reward.resource}
              </span>
            </motion.div>
          ))}
        </AnimatePresence>

        <div className="text-xs text-muted-foreground">
          <p>• Mining cooldown: 60 seconds</p>
          <p>• Resources depend on planet concentration</p>
          <p>• Limited by ship cargo capacity</p>
        </div>
      </CardContent>
    </Card>
  );
}