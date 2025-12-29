import { NextRequest, NextResponse } from "next/server";

import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const MODEL_NAME = process.env.OPENAI_MODEL || "gpt-4o-mini";

function extractOpenAIErrorDetails(err: any) {
  const status =
    typeof err?.status === "number"
      ? err.status
      : typeof err?.response?.status === "number"
      ? err.response.status
      : undefined;

  const message =
    err?.message ||
    err?.error?.message ||
    err?.response?.data?.error?.message ||
    err?.response?.data?.message ||
    "AI service unavailable";

  const code = err?.code || err?.error?.code;

  return { status, message, code };
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const { incoming, reply, traits = [], previousOutputs = [] } = body;

    if (!reply) {
      return NextResponse.json({ error: "Missing required field: reply" }, { status: 400 });
    }

    console.log("[rate] model:", MODEL_NAME);

    const traitText =
      traits && traits.length > 0
        ? ` The user wants replies that are ${traits.join(", ").toLowerCase()}.`
        : "";

    const hasIncoming = incoming && incoming.trim() !== "";

    let systemPrompt: string;

    let userPrompt: string;

    if (hasIncoming) {
      systemPrompt = `You're a texting expert who helps guys reply naturally.

She said: "${incoming}"

User wants to say: "${reply}"

${traitText}

Generate 2 DIFFERENT reply options:

1. SAFE - Friendly, matches her energy, low risk

2. BOLD - Confident, playful, shows interest

${previousOutputs.length > 0 ? `CRITICAL: User already saw these replies, so generate COMPLETELY DIFFERENT ones:\n${previousOutputs.map((o: string) => `- "${o}"`).join("\n")}\n` : ""}

STRICT RULES:

- Reference something she said

- Sound natural (lowercase, conversational)

- NO corporate speak

- SHORT: 5-20 words MAX

- NO labels or quotes

- NO word counts in output like "(10 words)"

Return ONLY valid JSON:

{
  "alternatives": [
    "<safe reply - 5-20 words>",
    "<bold reply - 5-20 words>"
  ]
}`;

      userPrompt = `Incoming: "${incoming}"

User replied: "${reply}"

Provide 2 better alternatives.`;
    } else {
      systemPrompt = `You're a texting expert who helps REWRITE and FIX messages to sound better.

CRITICAL: Your job is to REWRITE/IMPROVE the user's text, NOT generate a reply to it.

User typed: "${reply}"

${traitText}

Generate 2 DIFFERENT rewritten versions:

1. SAFE - Friendly, clear, low risk

2. BOLD - Confident, direct, shows interest

${previousOutputs.length > 0 ? `CRITICAL: User already saw these suggestions, so generate COMPLETELY DIFFERENT ones:\n${previousOutputs.map((o: string) => `- "${o}"`).join("\n")}\n` : ""}

STRICT RULES:

- REWRITE the user's text, DON'T generate a reply to it

- Keep the same intent and meaning

- Sound like a real person (lowercase, natural)

- NO corporate speak

- SHORT: Keep it 5-15 words MAX

- NO explanations, NO labels

- NO word counts in output

Return ONLY valid JSON:

{
  "alternatives": [
    "<safe rewrite - 5-15 words>",
    "<bold rewrite - 5-15 words>"
  ]
}`;

      userPrompt = `Text to improve: "${reply}"

Provide 2 improved versions.`;
    }

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 400,
      response_format: { type: "json_object" },
    });

    const aiResponse = completion.choices[0]?.message?.content || "{}";

    let parsed: any;

    try {
      parsed = JSON.parse(aiResponse);
    } catch {
      throw new Error("Invalid JSON from AI");
    }

    if (!Array.isArray(parsed.alternatives) || parsed.alternatives.length < 2) {
      parsed.alternatives = [
        "I feel the same way. Let's give this a fresh start.",
        "I've noticed that too. Any ideas on how we can improve?",
      ];
    }

    const cleanAlternatives = parsed.alternatives.slice(0, 2).map((alt: string) => {
      return alt
        .replace(/\s*\(\d+\s*words?\)\s*$/i, "")
        .replace(/\s*\(\d+\)\s*$/i, "")
        .replace(/\s*-\s*\d+\s*words?\s*$/i, "")
        .replace(/\s*--+\s*/g, " ")
        .replace(/\s*\/\s*/g, " ")
        .replace(/\s+-\s+/g, " - ")
        .replace(/\s{2,}/g, " ")
        .trim();
    });

    const randomScore = Math.floor(Math.random() * 3) + 3;

    const response = {
      displayScoreText: `${randomScore}/10`,
      headlineOverride: "You have poor social skills 😭",
      subline: "You scored lower than most people...",
      alternatives: cleanAlternatives,
    };

    console.log(`[rate] Score: ${randomScore}/10`);

    return NextResponse.json(response, { status: 200 });
  } catch (error: any) {
    console.error("[rate] Error (raw):", error);
    const { status, message, code } = extractOpenAIErrorDetails(error);

    const safeStatus =
      typeof status === "number" && status >= 400 && status < 600 ? status : 500;

    return NextResponse.json(
      { error: message, code, status: safeStatus, model: MODEL_NAME },
      { status: safeStatus }
    );
  }
}

export async function GET() {
  return NextResponse.json({
    status: "ok",
    message: "API is running",
  });
}
