import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const PLANTNET_BASE = "https://my-api.plantnet.org/v2/identify/all";
const TREFLE_BASE = "https://trefle.io/api/v1";
const GBIF_BASE = "https://api.gbif.org/v1/species/match";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export default {
  fetch: withSupabase({ auth: ["publishable", "secret"] }, async (req) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: cors });
    }

    const url = new URL(req.url);
    const action = url.searchParams.get("action");

    // ── Trefle: species search ─────────────────────────────────────────────
    if (action === "trefle-search") {
      const name = url.searchParams.get("name") ?? "";
      const key = Deno.env.get("TREFLE_API_KEY") ?? "";
      const trefleUrl = `${TREFLE_BASE}/species/search?q=${encodeURIComponent(name)}&token=${key}`;
      const res = await fetch(trefleUrl, { signal: AbortSignal.timeout(10_000) });
      const data = await res.json();
      return Response.json(data, { status: res.status, headers: cors });
    }

    // ── Trefle: species detail ─────────────────────────────────────────────
    if (action === "trefle-detail") {
      const id = url.searchParams.get("id") ?? "";
      const key = Deno.env.get("TREFLE_API_KEY") ?? "";
      const trefleUrl = `${TREFLE_BASE}/species/${id}?token=${key}`;
      const res = await fetch(trefleUrl, { signal: AbortSignal.timeout(10_000) });
      const data = await res.json();
      return Response.json(data, { status: res.status, headers: cors });
    }

    // ── GBIF: canonical name lookup (no key needed, but proxy avoids CORS) ─
    if (action === "gbif") {
      const name = url.searchParams.get("name") ?? "";
      const gbifUrl = `${GBIF_BASE}?name=${encodeURIComponent(name)}&strict=false`;
      const res = await fetch(gbifUrl, { signal: AbortSignal.timeout(8_000) });
      const data = await res.json();
      return Response.json(data, { status: res.status, headers: cors });
    }

    // ── PlantNet: identify from image (default POST route) ─────────────────
    if (req.method !== "POST") {
      return Response.json({ error: "POST required" }, { status: 405, headers: cors });
    }

    const plantnetKey = Deno.env.get("PLANTNET_API_KEY") ?? "";
    const lang = url.searchParams.get("lang") ?? "en";

    let formData: FormData;
    try {
      formData = await req.formData();
    } catch {
      return Response.json({ error: "Invalid multipart form" }, { status: 400, headers: cors });
    }

    const imageFile = formData.get("images");
    if (!imageFile || !(imageFile instanceof File)) {
      return Response.json({ error: "Missing 'images' file field" }, { status: 400, headers: cors });
    }

    const plantnetForm = new FormData();
    plantnetForm.append("images", imageFile);
    plantnetForm.append("organs", "auto");

    const plantnetUrl =
      `${PLANTNET_BASE}?api-key=${plantnetKey}&lang=${lang}&include-related-images=true`;

    const plantnetRes = await fetch(plantnetUrl, {
      method: "POST",
      body: plantnetForm,
      signal: AbortSignal.timeout(30_000),
    });

    const data = await plantnetRes.json();
    return Response.json(data, { status: plantnetRes.status, headers: cors });
  }),
};
