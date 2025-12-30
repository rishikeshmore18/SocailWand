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

export async function POST(req: NextRequest) {
  try {
    const { text, tones, length, previousOutputs } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return NextResponse.json({ error: "Text is required for reply generation" }, { status: 400 });
    }

    console.log("[reply] model:", MODEL_NAME);

    const systemPrompt = `<system_role>

You are a reply generation expert. Your job is to generate contextually appropriate replies to incoming messages.

</system_role>

<priority_order status="non-negotiable">

1. TONE + LENGTH (mandatory - always apply to final text)

2. INCOMING MESSAGE ANALYSIS (binding - understand context deeply)

3. REPLY GENERATION (supporting - craft natural response)

</priority_order>

<input_parameters>

<incoming_message>${text}</incoming_message>

<tones>${tones && Array.isArray(tones) && tones.length > 0 ? tones.join(", ") : "neutral"}</tones>

<length>${length || "Medium"}</length>

${
  previousOutputs && Array.isArray(previousOutputs) && previousOutputs.length > 0
    ? `

<diversification status="mandatory">

User already saw these replies. Generate COMPLETELY DIFFERENT options:

${previousOutputs.map((msg: string, i: number) => `${i + 1}. "${msg}"`).join("\n")}

</diversification>

`
    : ""
}

</input_parameters>

<reply_generation_rules>

STEP 1: ANALYZE INCOMING MESSAGE

- Extract intent (asking question, making statement, suggesting plans, etc.)

- Identify emotional tone (excited, casual, formal, flirty, etc.)

- Note key details to reference

STEP 2: GENERATE REPLY OPTIONS

- Safe = Friendly, matches their energy, low risk

- Bold = Confident, shows interest/personality, engaging

STEP 3: APPLY LENGTH CONSTRAINTS

- Short (5-10 words): Direct, concise

- Medium (10-25 words): Balanced, conversational

- Long (25-50 words): Detailed, adds context

STEP 4: APPLY TONE

- If tones provided, apply them naturally

- If no tones, match incoming message energy

CRITICAL RULES:

- Reference something from their message (show you read it)

- Sound like a real person (lowercase, natural)

- NO corporate speak, NO formal business language

- NO labels, NO quotes around reply

- NO word counts in output like "(10 words)"

- Keep it conversational and authentic

- Emojis: Max 1-2, only when contextually appropriate

- Appropriate emojis: 😊 😅 😏 👀 (avoid 😉 unless truly flirty)

LENGTH ENFORCEMENT:

- Short: Count words, MUST be 5-10 words

- Medium: Count words, MUST be 10-25 words

- Long: Count words, MUST be 25-50 words

</reply_generation_rules>

<output_format type="structured_json">

<instructions>

Return ONLY this JSON (no markdown, no preamble, no trailing commas).

Use double quotes for all strings.

Ensure valid JSON syntax.

</instructions>

<json_structure>

{
  "safe": "your safe reply here",
  "bold": "your bold reply here",
  "tonesApplied": ["Tone1", "Tone2"],
  "lengthApplied": "Short | Medium | Long",
  "wordCountSafe": number,
  "wordCountBold": number
}

</json_structure>

</output_format>`;

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: `Generate a reply to this message. Follow tone and length rules strictly.\n\nIncoming message: "${text}"`,
        },
      ],
      max_tokens: 300,
      temperature: 0.85,
    });

    const aiResponse = completion.choices[0]?.message?.content?.trim() || "";

    let safe = "";
    let bold = "";

    try {
      const cleanResponse = aiResponse.replace(/```json\n?|```\n?/g, "").trim();
      const parsed = JSON.parse(cleanResponse);

      if (parsed.safe && parsed.bold) {
        safe = parsed.safe;
        bold = parsed.bold;

        console.log("[reply] AI Response Validation:", {
          tonesApplied: parsed.tonesApplied,
          lengthApplied: parsed.lengthApplied,
          wordCountSafe: parsed.wordCountSafe,
          wordCountBold: parsed.wordCountBold,
        });
      }
    } catch (parseError) {
      console.log("[reply] JSON parse failed, attempting fallback");
      const parts = aiResponse.split("|").map((s) => s.trim());
      if (parts.length === 2) {
        safe = parts[0];
        bold = parts[1];
      }
    }

    if (safe && bold) {
      return NextResponse.json({
        result: safe,
        alternatives: [safe, bold],
      });
    }

    return NextResponse.json({ error: "Failed to parse AI response format" }, { status: 500 });
  } catch (error: any) {
    console.error("[reply] Error (raw):", error);
    const { status, message, code } = extractOpenAIErrorDetails(error);

    if (code === "insufficient_quota") {
      return NextResponse.json(
        { error: message || "AI service quota exceeded", code, status: 503, model: MODEL_NAME },
        { status: 503 }
      );
    }

    const safeStatus = typeof status === "number" && status >= 400 && status < 600 ? status : 500;

    return NextResponse.json(
      { error: message, code, status: safeStatus, model: MODEL_NAME },
      { status: safeStatus }
    );
  }
}

