// SSE (Server-Sent Events) handling
import type { SSEClient } from "./types";
import { sseClients, timerState } from "./state";

let clientIdCounter = 0;

// Create SSE response for /events endpoint
export function createSSEResponse(): Response {
  const stream = new ReadableStream({
    start(controller) {
      const clientId = `client-${++clientIdCounter}`;
      const client: SSEClient = { controller, id: clientId };

      // Add to active clients
      sseClients.add(client);
      console.log(`SSE client connected: ${clientId} (total: ${sseClients.size})`);

      // Immediately send current timer state
      sendSSEMessage(controller, {
        type: "update_timer",
        remaining_seconds: timerState.remaining_seconds,
        total_duration: timerState.total_duration,
        status: timerState.status,
      });

      // Handle client disconnect
      const interval = setInterval(() => {
        try {
          // Send keep-alive comment every 30 seconds
          controller.enqueue(`: keep-alive\n\n`);
        } catch (err) {
          // Client disconnected
          clearInterval(interval);
          sseClients.delete(client);
          console.log(`SSE client disconnected: ${clientId} (total: ${sseClients.size})`);
        }
      }, 30000);
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

// Send SSE message to a specific controller
function sendSSEMessage(
  controller: ReadableStreamDefaultController,
  data: Record<string, any>
): void {
  const message = `data: ${JSON.stringify(data)}\n\n`;
  controller.enqueue(message);
}

// Broadcast message to all connected SSE clients
export function broadcastSSE(data: Record<string, any>): void {
  const deadClients: SSEClient[] = [];

  for (const client of sseClients) {
    try {
      sendSSEMessage(client.controller, data);
    } catch (err) {
      // Client connection dead, mark for removal
      deadClients.push(client);
    }
  }

  // Clean up dead connections
  for (const client of deadClients) {
    sseClients.delete(client);
    console.log(`Removed dead SSE client: ${client.id}`);
  }
}
