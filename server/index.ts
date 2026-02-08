// Server entry point
import { handleRequest } from "./routes";

const PORT = parseInt(process.env.PORT || "8080", 10);

console.log(`Starting timer server on port ${PORT}...`);

let server;
try {
  server = Bun.serve({
    port: PORT,
    fetch: handleRequest,
  });
  console.log(`Server running on :${server.port}`);
} catch (error) {
  if (error instanceof Error && error.message.includes("EADDRINUSE")) {
    console.error(`Error: Port ${PORT} is already in use.`);
    console.error(`Please specify a different port using the PORT environment variable.`);
    console.error(`Example: PORT=3000 bun run server`);
    process.exit(1);
  }
  throw error;
}

// Import timer manager for cleanup
import { spawnCoreProcess, terminateCoreProcess } from "./timer-manager";
import { sseClients } from "./state";

// Spawn Core process on startup
await spawnCoreProcess();

// Graceful shutdown handling
async function shutdown() {
  console.log("\nShutting down server...");

  // Close all SSE connections
  for (const client of sseClients) {
    try {
      client.controller.close();
    } catch (err) {
      // Ignore errors during cleanup
    }
  }
  sseClients.clear();

  // Terminate Core process (5 second timeout)
  await terminateCoreProcess(5000);

  // Stop HTTP server
  if (server) {
    server.stop();
  }

  console.log("Server shut down successfully");
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
