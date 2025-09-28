"use client";

import { createContext, useContext, useEffect, ReactNode, useState } from "react";
import { initializeMiniKit, isWorldApp, getDeviceProperties, getUserProperties } from "@/lib/minikit";

interface MiniKitContextType {
  isWorldApp: boolean;
  isInitialized: boolean;
  deviceProperties: any | null;
  userProperties: any | null;
  refreshUserProperties: () => void;
}

const MiniKitContext = createContext<MiniKitContextType>({
  isWorldApp: false,
  isInitialized: false,
  deviceProperties: null,
  userProperties: null,
  refreshUserProperties: () => {},
});

export const useMiniKit = () => {
  const context = useContext(MiniKitContext);
  if (!context) {
    throw new Error("useMiniKit must be used within a MiniKitProvider");
  }
  return context;
};

export function MiniKitProvider({ children }: { children: ReactNode }) {
  const [isWorldAppEnv, setIsWorldAppEnv] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const [deviceProperties, setDeviceProperties] = useState<any | null>(null);
  const [userProperties, setUserProperties] = useState<any | null>(null);

  const refreshUserProperties = () => {
    const freshUserProps = getUserProperties();
    setUserProperties(freshUserProps);
  };

  useEffect(() => {
    let mounted = true;

    const checkWorldApp = () => {
      if (!mounted) return;
      
      const inWorldApp = isWorldApp();
      setIsWorldAppEnv(!!inWorldApp);

      if (inWorldApp) {
        // Initialize MiniKit
        const initialized = initializeMiniKit();
        if (mounted) {
          setIsInitialized(initialized);
        }

        // Get device and user properties
        const deviceProps = getDeviceProperties();
        const userProps = getUserProperties();
        
        if (mounted) {
          setDeviceProperties(deviceProps);
          setUserProperties(userProps);
        }

        // Apply safe area insets if available
        if (deviceProps?.safeAreaInsets) {
          const root = document.documentElement;
          root.style.setProperty('--safe-area-inset-top', `${deviceProps.safeAreaInsets.top}px`);
          root.style.setProperty('--safe-area-inset-right', `${deviceProps.safeAreaInsets.right}px`);
          root.style.setProperty('--safe-area-inset-bottom', `${deviceProps.safeAreaInsets.bottom}px`);
          root.style.setProperty('--safe-area-inset-left', `${deviceProps.safeAreaInsets.left}px`);
        }
      }
    };

    // Check immediately
    checkWorldApp();

    // Also check after a short delay in case World App loads asynchronously
    const timeout = setTimeout(checkWorldApp, 100);

    return () => {
      mounted = false;
      clearTimeout(timeout);
    };
  }, []);

  const value = {
    isWorldApp: isWorldAppEnv,
    isInitialized,
    deviceProperties,
    userProperties,
    refreshUserProperties,
  };

  return (
    <MiniKitContext.Provider value={value}>
      {children}
    </MiniKitContext.Provider>
  );
}
