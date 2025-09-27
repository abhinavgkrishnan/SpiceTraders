import { http, createConfig } from "wagmi";
import { base } from "wagmi/chains";
import { getDefaultConfig } from "connectkit";

export const config = createConfig(
  getDefaultConfig({
    chains: [base],
    transports: {
      [base.id]: http(),
    },
    walletConnectProjectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "",
    appName: "Spice Traders",
    appDescription: "A space trading game on Base",
    appUrl: "https://spacetraders.game",
    appIcon: "https://spacetraders.game/icon.png",
  })
);