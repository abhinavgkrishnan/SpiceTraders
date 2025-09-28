"use client";

import { useState, useEffect } from "react";
import { useMiniKit } from "@/components/MiniKitProvider";
import { authenticateWallet, getUserProperties } from "@/lib/minikit";
import { Button } from "@/components/ui/button";
import { Rocket, Wallet, CheckCircle } from "lucide-react";

export function WorldWalletButton() {
  const { isWorldApp, isInitialized, userProperties, refreshUserProperties } = useMiniKit();
  const [isConnecting, setIsConnecting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [walletAddress, setWalletAddress] = useState<string | null>(null);

  useEffect(() => {
    if (isWorldApp && isInitialized && userProperties && 'walletAddress' in userProperties) {
      setIsConnected(true);
      setWalletAddress((userProperties as any).walletAddress);
    }
  }, [isWorldApp, isInitialized, userProperties]);

  const handleConnect = async () => {
    if (!isWorldApp || !isInitialized) return;

    setIsConnecting(true);
    try {
      // Authenticate with World wallet
      const authResult = await authenticateWallet();
      
      // Check if authentication was successful
      if (authResult && 'success' in authResult && (authResult as any).success) {
        // Immediately mark as connected
        setIsConnected(true);
        
        // Refresh user properties from MiniKit provider
        setTimeout(() => {
          refreshUserProperties();
          
          // Also try to get fresh properties directly
          const freshUserProps = getUserProperties();
          
          if (freshUserProps && 'walletAddress' in freshUserProps) {
            setWalletAddress((freshUserProps as any).walletAddress);
          }
        }, 1000);
      }
    } catch (error) {
      // Silent error handling - could add user-friendly error message here
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDisconnect = () => {
    setIsConnected(false);
    setWalletAddress(null);
  };

  if (!isWorldApp) {
    return null; // Don't show in regular web app
  }

  if (!isConnected) {
    return (
      <Button
        onClick={handleConnect}
        disabled={isConnecting || !isInitialized}
        className="bg-amber-500 hover:bg-amber-600 text-black font-medium"
      >
        {isConnecting ? (
          <>
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-black mr-2" />
            Connecting...
          </>
        ) : (
          <>
            <Rocket className="h-4 w-4 mr-2" />
            Connect World Wallet
          </>
        )}
      </Button>
    );
  }

  if (isConnected) {
    return (
      <div className="flex items-center gap-2">
        <div className="flex items-center gap-2 px-3 py-2 bg-amber-500/20 rounded-lg">
          <CheckCircle className="h-4 w-4 text-amber-500" />
          <span className="text-sm text-amber-500 font-medium">
            World Wallet Connected
            {walletAddress && (
              <span className="text-xs block text-amber-400">
                {walletAddress.substring(0, 6)}...{walletAddress.substring(walletAddress.length - 4)}
              </span>
            )}
          </span>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleDisconnect}
          className="text-xs"
        >
          Disconnect
        </Button>
      </div>
    );
  }

}
