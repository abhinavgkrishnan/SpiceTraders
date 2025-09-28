import { MiniKit } from "@worldcoin/minikit-js";

// Check if we're running inside World App
export const isWorldApp = () => {
  if (typeof window === "undefined") return false;
  
  // Check for various World App indicators
  const checks = {
    windowWorldApp: !!window.WorldApp,
    windowMiniApp: !!(window as any).miniApp,
    isIframe: window.parent !== window,
    hasWorldInUserAgent: typeof navigator !== "undefined" && navigator.userAgent.includes('World'),
    hasWorldInReferrer: typeof document !== "undefined" && (
      document.referrer.includes('world.app') || 
      document.referrer.includes('world.org') ||
      document.referrer.includes('world')
    ),
    hasWorldInUrl: typeof window !== "undefined" && (
      window.location.href.includes('world.app') ||
      window.location.href.includes('world.org') ||
      window.location.href.includes('world')
    )
  };
  
  const hasWorldApp = Object.values(checks).some(check => check);
  
  
  return hasWorldApp;
};

// Initialize MiniKit if in World App
export const initializeMiniKit = () => {
  if (isWorldApp()) {
    MiniKit.install();
    return true;
  }
  return false;
};

// Get device properties from World App
export const getDeviceProperties = () => {
  if (isWorldApp() && window.WorldApp) {
    return window.WorldApp.deviceProperties;
  }
  return null;
};

// Get user properties from World App
export const getUserProperties = () => {
  if (isWorldApp()) {
    // First try MiniKit.user (after wallet auth)
    if (MiniKit.user) {
      return MiniKit.user;
    }
    
    // Fallback to window.WorldApp.user
    if (window.WorldApp?.user) {
      return window.WorldApp.user;
    }
  }
  return null;
};

// Check if MiniKit is available
export const isMiniKitAvailable = () => {
  return isWorldApp() && MiniKit.isInstalled();
};

// World ID verification
export const verifyWorldID = async (action: string, signal?: string) => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  const { finalPayload } = await MiniKit.commandsAsync.verify({
    action,
    signal,
    verification_level: "orb" as any,
  });

  return finalPayload;
};

// Payment command
export const makePayment = async (amount: string, token: string, reference: string, to: string, description: string) => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  const { finalPayload } = await MiniKit.commandsAsync.pay({
    reference: reference,
    to: to,
    tokens: [{
      symbol: token as any,
      token_amount: amount,
    }],
    description: description,
  });

  return finalPayload;
};

// Wallet authentication
export const authenticateWallet = async () => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  // Generate a nonce for wallet authentication
  const nonce = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);

  const { finalPayload } = await MiniKit.commandsAsync.walletAuth({
    nonce: nonce,
  });

  return finalPayload;
};

// Send transaction
export const sendTransaction = async (transaction: any) => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  const { finalPayload } = await MiniKit.commandsAsync.sendTransaction({
    transaction,
  });

  return finalPayload;
};

// Sign message
export const signMessage = async (message: string) => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  const { finalPayload } = await MiniKit.commandsAsync.signMessage({
    message,
  });

  return finalPayload;
};

// Share content
export const shareContent = async (title: string, text: string, url: string) => {
  if (!isMiniKitAvailable()) {
    throw new Error("MiniKit not available");
  }

  const { finalPayload } = await MiniKit.commandsAsync.share({
    title,
    text,
    url,
  });

  return finalPayload;
};

// Declare global types for World App
declare global {
  interface Window {
    WorldApp?: {
      deviceProperties: {
        safeAreaInsets: {
          top: number;
          right: number;
          bottom: number;
          left: number;
        };
        deviceOS: string;
        worldAppVersion: number;
      };
      user: {
        optedIntoOptionalAnalytics: boolean;
      };
    };
  }
}
