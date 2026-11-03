import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { WagmiProvider } from "wagmi";
import App from "./App.tsx";
import "./index.css";
import { config } from "./wagmi.ts";

// wagmi stores every read in this cache: it deduplicates identical requests and refetches them.
const queryClient = new QueryClient();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </StrictMode>,
);
