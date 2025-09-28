"use client";

import { useMiniKit } from "@/components/MiniKitProvider";
import { useWorldID } from "@/hooks/useWorldID";
import { useWorldPayment } from "@/hooks/useWorldPayment";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Globe, Shield, CreditCard, TestTube } from "lucide-react";

export function WorldAppDebug() {
  const { isWorldApp, isInitialized, deviceProperties, userProperties } = useMiniKit();
  const { verify, isVerifying, verificationResult, isAvailable: isWorldIDAvailable } = useWorldID();
  const { pay, isProcessing, paymentResult, isAvailable: isPaymentAvailable } = useWorldPayment();

  const handleTestWorldID = async () => {
    try {
      await verify("test-action", "test-signal");
    } catch (error) {
      console.error("World ID test failed:", error);
    }
  };

  const handleTestPayment = async () => {
    try {
      await pay(
        "0.001", 
        "WLD", 
        `test-payment-${Date.now()}`,
        "0x0000000000000000000000000000000000000000", // Test recipient
        "Test payment from Spice Traders"
      );
    } catch (error) {
      console.error("Payment test failed:", error);
    }
  };

  if (!isWorldApp) {
    return null;
  }

  return (
    <Card className="border-blue-500/50 bg-blue-950/20">
      <CardHeader>
        <CardTitle className="text-blue-400 flex items-center gap-2">
          <TestTube className="h-5 w-5" />
          World App Debug Panel
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Globe className="h-4 w-4" />
              <span className="text-sm font-medium">World App</span>
              <Badge variant={isWorldApp ? "default" : "secondary"}>
                {isWorldApp ? "Active" : "Inactive"}
              </Badge>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-sm">Initialized:</span>
              <Badge variant={isInitialized ? "default" : "secondary"}>
                {isInitialized ? "Yes" : "No"}
              </Badge>
            </div>
          </div>
          
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Shield className="h-4 w-4" />
              <span className="text-sm font-medium">World ID</span>
              <Badge variant={isWorldIDAvailable ? "default" : "secondary"}>
                {isWorldIDAvailable ? "Available" : "Unavailable"}
              </Badge>
            </div>
            <div className="flex items-center gap-2">
              <CreditCard className="h-4 w-4" />
              <span className="text-sm font-medium">Payments</span>
              <Badge variant={isPaymentAvailable ? "default" : "secondary"}>
                {isPaymentAvailable ? "Available" : "Unavailable"}
              </Badge>
            </div>
          </div>
        </div>

        {deviceProperties && (
          <div className="space-y-2 p-3 bg-muted/20 rounded-lg">
            <h4 className="text-sm font-medium">Device Properties</h4>
            <div className="text-xs space-y-1">
              <div>OS: {deviceProperties.deviceOS}</div>
              <div>App Version: {deviceProperties.worldAppVersion}</div>
              <div>Safe Area: {JSON.stringify(deviceProperties.safeAreaInsets)}</div>
            </div>
          </div>
        )}

        {userProperties && (
          <div className="space-y-2 p-3 bg-muted/20 rounded-lg">
            <h4 className="text-sm font-medium">User Properties</h4>
            <div className="text-xs">
              Analytics Opt-in: {userProperties.optedIntoOptionalAnalytics ? "Yes" : "No"}
            </div>
          </div>
        )}

        <div className="flex gap-2">
          <Button
            onClick={handleTestWorldID}
            disabled={!isWorldIDAvailable || isVerifying}
            size="sm"
            variant="outline"
          >
            {isVerifying ? "Testing..." : "Test World ID"}
          </Button>
          <Button
            onClick={handleTestPayment}
            disabled={!isPaymentAvailable || isProcessing}
            size="sm"
            variant="outline"
          >
            {isProcessing ? "Testing..." : "Test Payment"}
          </Button>
        </div>

        {verificationResult && (
          <div className="p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
            <h4 className="text-sm font-medium text-green-400">World ID Result</h4>
            <div className="text-xs text-green-300">
              Status: {verificationResult.status}
              {verificationResult.error && <div>Error: {verificationResult.error}</div>}
            </div>
          </div>
        )}

        {paymentResult && (
          <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg">
            <h4 className="text-sm font-medium text-blue-400">Payment Result</h4>
            <div className="text-xs text-blue-300">
              Status: {paymentResult.status}
              {paymentResult.transaction_id && <div>TX ID: {paymentResult.transaction_id}</div>}
              {paymentResult.error && <div>Error: {paymentResult.error}</div>}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
