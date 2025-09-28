"use client";

import { useState, useCallback } from "react";
import { verifyWorldID } from "@/lib/minikit";
import { useMiniKit } from "@/components/MiniKitProvider";

interface WorldIDVerificationResult {
  status: "success" | "error";
  merkle_root?: string;
  nullifier_hash?: string;
  proof?: string;
  verification_level?: string;
  error?: string;
}

export function useWorldID() {
  const { isWorldApp, isInitialized } = useMiniKit();
  const [isVerifying, setIsVerifying] = useState(false);
  const [verificationResult, setVerificationResult] = useState<WorldIDVerificationResult | null>(null);

  const verify = useCallback(async (action: string, signal?: string) => {
    if (!isWorldApp || !isInitialized) {
      throw new Error("World ID verification is only available in World App");
    }

    setIsVerifying(true);
    setVerificationResult(null);

    try {
      const result = await verifyWorldID(action, signal);
      setVerificationResult(result);
      return result;
    } catch (error) {
      const errorResult: WorldIDVerificationResult = {
        status: "error",
        error: error instanceof Error ? error.message : "Unknown error occurred",
      };
      setVerificationResult(errorResult);
      throw error;
    } finally {
      setIsVerifying(false);
    }
  }, [isWorldApp, isInitialized]);

  const reset = useCallback(() => {
    setVerificationResult(null);
    setIsVerifying(false);
  }, []);

  return {
    verify,
    reset,
    isVerifying,
    verificationResult,
    isAvailable: isWorldApp && isInitialized,
  };
}
