"use client";

import { useState, useCallback } from "react";
import { makePayment } from "@/lib/minikit";
import { useMiniKit } from "@/components/MiniKitProvider";

interface PaymentResult {
  status: "success" | "error";
  transaction_id?: string;
  reference?: string;
  error?: string;
}

export function useWorldPayment() {
  const { isWorldApp, isInitialized } = useMiniKit();
  const [isProcessing, setIsProcessing] = useState(false);
  const [paymentResult, setPaymentResult] = useState<PaymentResult | null>(null);

  const pay = useCallback(async (amount: string, token: string, reference: string, to: string, description: string) => {
    if (!isWorldApp || !isInitialized) {
      throw new Error("World payments are only available in World App");
    }

    setIsProcessing(true);
    setPaymentResult(null);

    try {
      const result = await makePayment(amount, token, reference, to, description);
      setPaymentResult(result);
      return result;
    } catch (error) {
      const errorResult: PaymentResult = {
        status: "error",
        error: error instanceof Error ? error.message : "Payment failed",
      };
      setPaymentResult(errorResult);
      throw error;
    } finally {
      setIsProcessing(false);
    }
  }, [isWorldApp, isInitialized]);

  const reset = useCallback(() => {
    setPaymentResult(null);
    setIsProcessing(false);
  }, []);

  return {
    pay,
    reset,
    isProcessing,
    paymentResult,
    isAvailable: isWorldApp && isInitialized,
  };
}
