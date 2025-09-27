# Space Traders Frontend

Mobile-first space trading game built on Base blockchain.

## Setup

1. Install dependencies:
```bash
yarn install
```

2. Create `.env.local` file:
```bash
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here
```

Get your WalletConnect project ID from: https://cloud.walletconnect.com/

3. Run development server:
```bash
yarn dev
```

## Features

- **HUD**: Displays ship status, location, Solaris balance, and resource inventory
- **Mining**: Mine resources with 60s cooldown and animated rewards
- **Travel**: Travel between 5 planets with spice fuel costs
- **Market**: Trade resources for Solaris with real-time quotes
- **Onboarding**: New players receive starter ship + 1,500 Solaris

## Architecture

- **Next.js 15** with App Router
- **wagmi + ConnectKit** for wallet connections
- **shadcn/ui** with amber theme
- **Base mainnet** contracts
- **Framer Motion** for animations

## Contracts (Base Mainnet)

All contract addresses are configured in `constants/contracts.ts`

## Design

Mobile-first with amber theme inspired by the Dune universe. All components use shadcn primitives for consistency.