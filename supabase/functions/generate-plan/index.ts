import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.2";

type RequestPayload = {
  prompt?: string;
  userId?: string;
  agent?: string;
  model?: string;
  purpose?: string;
  familiarity?: string;
};

type JobResponse = {
  jobId: string;
  status: string;
  queuedAt: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceKey) {
  console.error("Supabase environment variables are missing for generate-plan function.");
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

  let payload: RequestPayload;
  try {
    payload = (await req.json()) as RequestPayload;
  } catch {
    return new Response(
      JSON.stringify({ message: "Invalid JSON payload" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const prompt = payload.prompt?.trim();
  if (!prompt) {
    return new Response(
      JSON.stringify({ message: "Prompt is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const { data, error } = await supabase
    .from("ai_generation_jobs")
    .insert({
      prompt,
      status: "pending",
      user_id: payload.userId ?? null,
      agent: payload.agent ?? null,
      model: payload.model ?? null,
      purpose: payload.purpose ?? null,
      familiarity: payload.familiarity ?? null
    })
    .select("id, status, created_at")
    .single();

  if (error || !data) {
    console.error("Failed to enqueue AI generation job", error);
    return new Response(
      JSON.stringify({ message: "Failed to enqueue AI generation job" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  const response: JobResponse = {
    jobId: data.id,
    status: data.status,
    queuedAt: data.created_at
  };

  return new Response(JSON.stringify(response), {
    status: 202,
    headers: { "Content-Type": "application/json" }
  });
});
