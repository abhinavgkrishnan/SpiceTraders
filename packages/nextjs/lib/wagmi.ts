import { http, createConfig } from "wagmi";
import { base } from "wagmi/chains";
import { getDefaultConfig } from "connectkit";

// Define World Chain configuration
const worldChain = {
  id: 480,
  name: "World Chain",
  nativeCurrency: {
    decimals: 18,
    name: "World",
    symbol: "WLD",
  },
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_WORLD_RPC_URL || "https://worldchain-mainnet.g.alchemy.com/public"],
    },
    public: {
      http: [process.env.NEXT_PUBLIC_WORLD_RPC_URL || "https://worldchain-mainnet.g.alchemy.com/public"],
    },
  },
  blockExplorers: {
    default: { name: "WorldScan", url: "https://worldscan.org" },
  },
} as const;

// Create a more robust HTTP transport with retry logic
const createHttpTransport = (url: string) => {
  return http(url, {
    batch: true, // Enable request batching
    retryCount: 3, // Retry failed requests
    timeout: 10000, // 10 second timeout
  });
};

// Get Base RPC URL
const getBaseRpcUrl = () => {
  const customRpc = process.env.NEXT_PUBLIC_BASE_RPC_URL;
  if (customRpc) return customRpc;
  
  // Use Alchemy's public endpoint as fallback (has better rate limits)
  return "https://base-mainnet.g.alchemy.com/v2/demo";
};

// Get World RPC URL
const getWorldRpcUrl = () => {
  const customRpc = process.env.NEXT_PUBLIC_WORLD_RPC_URL;
  if (customRpc) return customRpc;
  
  // Use Alchemy's public World Chain endpoint
  return "https://worldchain-mainnet.g.alchemy.com/public";
};

export const config = createConfig(
  getDefaultConfig({
    chains: [base, worldChain],
    transports: {
      [base.id]: createHttpTransport(getBaseRpcUrl()),
      [worldChain.id]: createHttpTransport(getWorldRpcUrl()),
    },
    walletConnectProjectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "",
    appName: "Spice Traders",
    appDescription: "A space trading game on Base with World ID integration",
    appUrl: "https://spacetraders.game",
    appIcon: "https://spacetraders.game/icon.png",
  })
);