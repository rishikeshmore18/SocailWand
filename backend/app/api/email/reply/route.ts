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
    const { incoming, draft, tones, length, previousOutputs } = await req.json();

    if (!draft || typeof draft !== "string" || draft.trim().length === 0) {
      return NextResponse.json(
        { error: "Draft reply is required for email reply" },
        { status: 400 }
      );
    }

    console.log("[email/reply] model:", MODEL_NAME);

    const systemPrompt = `<system_role>

You are an email reply polishing expert. You refine a user's draft reply to sound better while respecting the incoming email context.

</system_role>

<priority_order status="non-negotiable">

1. TONE + LENGTH (mandatory - always apply to final text)

2. USER DRAFT PRESERVATION (binding - keep intent and key points)

3. CONTEXT ALIGNMENT (supporting - stay relevant to incoming email)

</priority_order>

<input_parameters>

<incoming_email>${incoming || ""}</incoming_email>

<draft_reply>${draft}</draft_reply>

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

<reply_generation_rules>

STEP 1: UNDERSTAND CONTEXT

- Review incoming email for topic and tone
- Preserve any specific details from the user's draft

STEP 2: POLISH THE DRAFT

- Safe = clear, friendly, professional
- Bold = confident, direct, still email-appropriate

STEP 3: APPLY LENGTH CONSTRAINTS

- Short (5-20 words): concise reply
- Medium (20-60 words): balanced reply
- Long (60-140 words): detailed reply

STEP 4: APPLY TONE

- If tones provided, apply them naturally
- Keep the user's intent and voice

CRITICAL RULES:

- Do NOT invent new facts
- Do NOT answer the incoming email yourself
- Keep the reply aligned with the user's draft
- Preserve greetings/sign-offs if present
- No subject line unless provided
- No quotes, no labels, no extra commentary
- Emojis only if the original tone supports it (max 1)

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
          content: `Polish this email reply draft. Follow tone and length rules strictly.\n\nIncoming email: "${incoming || ""}"\n\nDraft reply: "${draft}"`,
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

        console.log("[email/reply] AI Response Validation: ", {
          tonesApplied: parsed.tonesApplied,
          lengthApplied: parsed.lengthApplied,
          wordCountSafe: parsed.wordCountSafe,
          wordCountBold: parsed.wordCountBold,
        });
      }
    } catch (parseError) {
      console.error("[email/reply] Failed to parse JSON, using fallback.");
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
    console.error("[email/reply] error:", message);

    return NextResponse.json(
      { error: message },
      { status: status || 500 }
    );
  }
}
