import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.2";

type StatusRequest = {
  jobId?: string;
};

type StatusResponse = {
  status: "pending" | "in_progress" | "completed" | "failed";
  plan?: unknown;
  error?: string | null;
  updatedAt: string;
  responseId?: string | null;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceKey) {
  console.error("Supabase environment variables are missing for plan-status function.");
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ message: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  let payload: StatusRequest;
  try {
    payload = (await req.json()) as StatusRequest;
  } catch {
    return new Response(
      JSON.stringify({ message: "Invalid JSON payload" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const jobId = payload.jobId?.trim();
  if (!jobId) {
    return new Response(
      JSON.stringify({ message: "jobId is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const { data, error } = await supabase
    .from("ai_generation_jobs")
    .select("status, result, error, updated_at, response_id")
    .eq("id", jobId)
    .maybeSingle();

  if (error) {
    console.error("Failed to fetch job status", error);
    return new Response(
      JSON.stringify({ message: "Failed to fetch job status" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  if (!data) {
    return new Response(
      JSON.stringify({ message: "Job not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } }
    );
  }

  const response: StatusResponse = {
    status: data.status as StatusResponse["status"],
    plan: data.result ?? undefined,
    error: data.error ?? null,
    updatedAt: data.updated_at,
    responseId: data.response_id ?? null
  };

  const statusCode = data.status === "completed" || data.status === "failed" ? 200 : 202;

  return new Response(JSON.stringify(response), {
    status: statusCode,
    headers: { "Content-Type": "application/json" }
  });
});
