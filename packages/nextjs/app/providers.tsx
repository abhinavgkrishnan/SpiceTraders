"use client";

import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider } from "connectkit";
import { config } from "@/lib/wagmi";

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ConnectKitProvider
          mode="dark"
          customTheme={{
            "--ck-connectbutton-font-size": "14px",
            "--ck-connectbutton-border-radius": "8px",
            "--ck-connectbutton-color": "#f59e0b",
            "--ck-connectbutton-background": "rgba(180, 83, 9, 0.2)",
            "--ck-connectbutton-box-shadow": "none",
            "--ck-connectbutton-hover-background": "rgba(180, 83, 9, 0.3)",
            "--ck-connectbutton-active-background": "rgba(180, 83, 9, 0.4)",
            "--ck-primary-button-border-radius": "8px",
            "--ck-primary-button-color": "#78350f",
            "--ck-primary-button-background": "#f59e0b",
            "--ck-primary-button-hover-background": "#d97706",
            "--ck-secondary-button-border-radius": "8px",
            "--ck-secondary-button-color": "#fbbf24",
            "--ck-secondary-button-background": "rgba(180, 83, 9, 0.2)",
            "--ck-secondary-button-hover-background": "rgba(180, 83, 9, 0.3)",
            "--ck-overlay-background": "rgba(0, 0, 0, 0.8)",
            "--ck-body-background": "hsl(0, 0%, 6%)",
            "--ck-body-background-secondary": "hsl(0, 0%, 8%)",
            "--ck-body-color": "#fbbf24",
            "--ck-body-color-muted": "rgba(251, 191, 36, 0.6)",
            "--ck-border-radius": "8px",
          }}
        >
          {children}
        </ConnectKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}