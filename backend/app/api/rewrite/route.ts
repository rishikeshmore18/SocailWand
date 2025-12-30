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
      return NextResponse.json({ error: "Text is required for rewrite" }, { status: 400 });
    }

    console.log("[rewrite] model:", MODEL_NAME);

    const systemPrompt = `<system_role>

You are a message rewriting expert. Your job is to rewrite and polish messages while preserving core meaning.

</system_role>

<priority_order status="non-negotiable">

1. TONE + LENGTH (mandatory - always apply to final text)

2. CORE MEANING PRESERVATION (binding - never lose user's intent)

3. POLISH & IMPROVEMENT (supporting - enhance clarity and flow)

</priority_order>

<input_parameters>

<original_text>${text}</original_text>

<tones>${tones && Array.isArray(tones) && tones.length > 0 ? tones.join(", ") : "neutral"}</tones>

<length>${length || "Medium"}</length>

${
  previousOutputs && Array.isArray(previousOutputs) && previousOutputs.length > 0
    ? `

<diversification status="mandatory">

User already saw these versions. Generate COMPLETELY DIFFERENT rewrites:

${previousOutputs.map((msg: string, i: number) => `${i + 1}. "${msg}"`).join("\n")}

</diversification>

`
    : ""
}

</input_parameters>

<rewrite_generation_rules>

STEP 1: UNDERSTAND ORIGINAL INTENT

- User may have spelling/grammar errors (this is normal)

- Extract core meaning and key ideas

- Identify what user is trying to communicate

- Example: "cant maek it sorr" → user can't make it and is apologizing

STEP 2: EXTRACT MUST-KEEP IDEAS

- Identify 2-4 core ideas that MUST appear in rewrite

- Core ideas typically include:
  - Main action/request
  - Reason/context
  - Emotional tone/sentiment

STEP 3: GENERATE REWRITE OPTIONS

- Safe = Softer/gentler version of same message

- Bold = More confident/assertive version of same message

- BOTH must contain ALL core ideas from original

STEP 4: APPLY LENGTH CONSTRAINTS

- Short (5-10 words): Ultra concise, no fluff

- Medium (10-25 words): Balanced, natural

- Long (25-50 words): Detailed, adds context

STEP 5: APPLY TONE

- If tones provided, apply them to the rewrite

- If no tones, make it sound natural and polished

CRITICAL RULES:

- REWRITE the message, don't generate a reply to it

- Preserve exact same meaning and intent

- Sound like a real person (lowercase, conversational)

- NO corporate speak, NO formal business language

- NO labels, NO quotes around output

- NO word counts in output like "(15 words)"

- Keep it authentic and natural

- Emojis: Max 1-2, only when contextually appropriate

- Appropriate emojis: 😊 😅 😏 👀 (avoid 😉 unless truly flirty)

- NO random punctuation like "--" or "/" or excessive "-"

LENGTH ENFORCEMENT:

- Short: Count words, MUST be 5-10 words

- Medium: Count words, MUST be 10-25 words

- Long: Count words, MUST be 25-50 words

<meaning_preservation_anchor>

Before finalizing output:

1. List core ideas from original text

2. Verify BOTH safe and bold contain ALL core ideas

3. If any core idea is missing → FAIL → rewrite again

4. Core ideas are non-negotiable - they MUST be preserved

</meaning_preservation_anchor>

</rewrite_generation_rules>

<output_format type="structured_json">

<instructions>

Return ONLY this JSON (no markdown, no preamble, no trailing commas).

Use double quotes for all strings.

Ensure valid JSON syntax.

</instructions>

<json_structure>

{
  "safe": "your safe rewrite here",
  "bold": "your bold rewrite here",
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
          content: `Rewrite this message to sound better. Preserve core meaning. Follow tone and length rules strictly.\n\nOriginal: "${text}"`,
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

        console.log("[rewrite] AI Response Validation:", {
          tonesApplied: parsed.tonesApplied,
          lengthApplied: parsed.lengthApplied,
          wordCountSafe: parsed.wordCountSafe,
          wordCountBold: parsed.wordCountBold,
        });
      }
    } catch (parseError) {
      console.log("[rewrite] JSON parse failed, attempting fallback");
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
    console.error("[rewrite] Error (raw):", error);
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

