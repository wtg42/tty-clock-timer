// REST API routes
import { timerState, resetTimerState } from "./state";
import { createSSEResponse } from "./sse";
import { sendCommandToCore } from "./timer-manager";
import { broadcastSSE } from "./sse";

export async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);

  // CORS headers (will be enhanced in task 2.3)
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };

  // Handle OPTIONS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }

  // SSE endpoint
  if (url.pathname === "/events" && req.method === "GET") {
    return createSSEResponse();
  }

  // REST API endpoints
  if (url.pathname === "/start" && req.method === "POST") {
    try {
      const body = await req.json();

      if (typeof body.duration_seconds !== "number") {
        return new Response(JSON.stringify({ error: "Missing duration_seconds" }), {
          status: 400,
          headers: { ...headers, "Content-Type": "application/json" },
        });
      }

      if (timerState.status === "running") {
        return new Response(JSON.stringify({ error: "Timer already running" }), {
          status: 409,
          headers: { ...headers, "Content-Type": "application/json" },
        });
      }

      sendCommandToCore({ cmd: "start", duration: body.duration_seconds });

      return new Response(
        JSON.stringify({ status: "started", duration: body.duration_seconds }),
        {
          headers: { ...headers, "Content-Type": "application/json" },
        }
      );
    } catch (err) {
      return new Response(JSON.stringify({ error: "Invalid JSON" }), {
        status: 400,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
  }

  if (url.pathname === "/pause" && req.method === "POST") {
    if (timerState.status !== "running") {
      return new Response(JSON.stringify({ error: "Timer not running" }), {
        status: 400,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    sendCommandToCore({ cmd: "pause" });

    return new Response(JSON.stringify({ status: "paused" }), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }

  if (url.pathname === "/resume" && req.method === "POST") {
    if (timerState.status !== "paused") {
      return new Response(JSON.stringify({ error: "Timer not paused" }), {
        status: 400,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    sendCommandToCore({ cmd: "resume" });

    return new Response(JSON.stringify({ status: "running" }), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }

  if (url.pathname === "/reset" && req.method === "POST") {
    sendCommandToCore({ cmd: "reset" });
    resetTimerState();
    broadcastSSE({ type: "update_timer", ...timerState });

    return new Response(JSON.stringify({ status: "idle" }), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }

  if (url.pathname === "/stop" && req.method === "POST") {
    sendCommandToCore({ cmd: "exit" });

    // Trigger server shutdown (will be handled by shutdown handler)
    setTimeout(() => process.kill(process.pid, "SIGINT"), 100);

    return new Response(JSON.stringify({ status: "stopping" }), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }

  if (url.pathname === "/status" && req.method === "GET") {
    return new Response(JSON.stringify(timerState), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }

  // 404 for unknown routes
  return new Response(JSON.stringify({ error: "Not found" }), {
    status: 404,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
