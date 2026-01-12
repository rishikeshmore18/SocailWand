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
      return NextResponse.json(
        { error: "Text is required for email rewrite" },
        { status: 400 }
      );
    }

    console.log("[email/write] model:", MODEL_NAME);

    const systemPrompt = `<system_role>

You are an email rewriting expert. Your job is to rewrite emails while preserving the original meaning, intent, and tone.

</system_role>

<priority_order status="non-negotiable">

1. TONE + LENGTH (mandatory - always apply to final text)

2. CORE MEANING PRESERVATION (binding - never lose user's intent)

3. EMAIL POLISH (supporting - clarity, structure, professionalism)

</priority_order>

<input_parameters>

<original_email>${text}</original_email>

<tones>${
      tones && Array.isArray(tones) && tones.length > 0
        ? tones.join(", ")
        : "neutral"
    }</tones>

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

STEP 1: UNDERSTAND ORIGINAL EMAIL

- Extract the main request or message
- Note greeting/closing if present
- Identify audience and level of formality

STEP 2: GENERATE TWO OPTIONS

- Safe = clear, friendly, low risk
- Bold = confident, more direct, still appropriate

STEP 3: APPLY LENGTH CONSTRAINTS

- Short (5-20 words): concise email
- Medium (20-60 words): balanced and natural
- Long (60-140 words): detailed, full context

STEP 4: APPLY TONE

- If tones provided, apply them naturally
- Keep the original voice and intent

CRITICAL RULES:

- Rewrite the email, do NOT reply to it
- Preserve meaning and key details
- Keep any greetings/sign-offs if present
- No subject line unless one was provided
- No quotes, no labels, no extra commentary
- No corporate fluff or robotic phrasing
- Emojis only if the original tone supports it (max 1)

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
          content: `Rewrite this email. Follow tone and length rules strictly.\n\nEmail: "${text}"`,
        },
      ],
      max_tokens: 400,
      temperature: 0.8,
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

        console.log("[email/write] AI Response Validation:", {
          tonesApplied: parsed.tonesApplied,
          lengthApplied: parsed.lengthApplied,
          wordCountSafe: parsed.wordCountSafe,
          wordCountBold: parsed.wordCountBold,
        });
      }
    } catch (parseError) {
      console.error("[email/write] Failed to parse JSON, using fallback.");
      safe = aiResponse;
      bold = aiResponse;
    }

    return NextResponse.json({
      safe,
      bold,
      alternatives: [safe, bold],
    });
  } catch (err: any) {
    const { status, message } = extractOpenAIErrorDetails(err);
    console.error("[email/write] error:", message);

    return NextResponse.json(
      { error: message },
      { status: status || 500 }
    );
  }
}
