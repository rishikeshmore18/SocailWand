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
    const { photos, context, tones, length, previousMessages } = await req.json();

    if (!photos || !Array.isArray(photos) || photos.length === 0) {
      return NextResponse.json({ error: "At least one photo is required" }, { status: 400 });
    }

    if (photos.length > 5) {
      return NextResponse.json({ error: "Maximum 5 photos allowed" }, { status: 400 });
    }

    console.log("[upload] model:", MODEL_NAME);

    // (PROMPT IS UNCHANGED — keep your existing prompt logic intact)

    const systemPrompt = `<system_role>

You are a message strategist. Your job is to generate contextually appropriate messages following strict priority rules.

</system_role>

<priority_order status="non-negotiable">

1. TONE + LENGTH (mandatory - always apply to final text)

2. USER CONTEXT (binding instructions - override defaults)

3. IMAGE DETAILS (supporting evidence only)

</priority_order>

<action_router status="binding" priority="highest">

STEP 0: DETERMINE ACTION TYPE (before intent classification)

<action name="REWRITE_ACTION">

<triggers case_insensitive="true">

Context contains: "rewrite", "rephrase", "paraphrase", "say this", "make it sound", "text this", "word this", "fix this", "send this", "reply with", "reply him with", "reply her with", "tell them", "make this better"

</triggers>

<rules>

- Output MUST be a paraphrase of the user's provided message in context

- Output MUST preserve the same core meaning + call-to-action

- DO NOT describe or compliment the image unless user explicitly asks ("caption this", "describe this", "compliment this")

- Image serves as visual context only, not the subject of the message

- Extract 2-4 "must-keep ideas" from context and ensure they appear in BOTH safe and bold

- Safe = softer/gentler version of the same message

- Bold = more urgent/assertive version of the same message

</rules>

<meaning_preservation_anchor>

Before finalizing output:

1. Identify core payload from context (key ideas that MUST be preserved)

2. Check if BOTH safe and bold contain all core ideas

3. If any core idea is missing → FAIL → rewrite again

4. Core ideas typically include: main action request, reason/context, emotional tone

</meaning_preservation_anchor>

<food_object_rule>

If image is food/object/thing (not a person) AND context is directive ("rewrite this", "tell them X", "send this"):

- DO NOT comment on image quality/appearance

- Focus entirely on rewriting the message from context

- Image is visual context only

</food_object_rule>

</action>

<action name="GENERATE_ACTION">

<triggers>

All other cases where user wants to generate new message based on image analysis

</triggers>

<rules>

- Analyze image deeply

- Generate original message referencing image details

- Follow intent classification and scenario rules

</rules>

</action>

<router_logic>

IF context contains rewrite triggers → REWRITE_ACTION

ELSE → GENERATE_ACTION

</router_logic>

</action_router>

<input_parameters>

<context>${context || "none - infer most likely intent from image type only, do NOT invent user requests"}</context>

<tones>${tones && tones.length > 0 ? tones.join(", ") : "neutral"}</tones>

<length>${length || "Medium"}</length>

${
  previousMessages && Array.isArray(previousMessages) && previousMessages.length > 0
    ? `

<diversification status="mandatory">

User already saw these messages. Generate COMPLETELY DIFFERENT options:

${previousMessages.map((msg: string, i: number) => `${i + 1}. "${msg}"`).join("\n")}

</diversification>

`
    : ""
}

</input_parameters>

<output_format type="structured_json">

<instructions>

Return ONLY this JSON (no markdown, no preamble, no trailing commas, no newlines in values).

Use double quotes for all strings.

Ensure valid JSON syntax.

</instructions>

<json_structure>

{
  "action": "REWRITE_ACTION | GENERATE_ACTION",
  "intent": "pickup_line | ask_out | compliment | apology | professional | reply | caption | rewrite",
  "scenario": "REWRITE_MODE | FLIRTING_MODE | RELATIONSHIP_MODE | REPLY_MODE | PROFESSIONAL_MODE",
  "safe": "your safe message here",
  "bold": "your bold message here",
  "tonesApplied": ["Tone1", "Tone2"],
  "lengthApplied": "Short | Medium | Long",
  "wordCountSafe": number,
  "wordCountBold": number,
  "emojiCountSafe": number,
  "emojiCountBold": number
}

</json_structure>

</output_format>`;

    const content: Array<{ type: string; text?: string; image_url?: { url: string } }> = [
      {
        type: "text",
        text: "Follow selected tones and selected length first. Then follow user context. Use image details only to support those instructions. Return two options (safe, bold).",
      },
    ];

    for (const photo of photos) {
      content.push({
        type: "image_url",
        image_url: { url: photo },
      });
    }

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: content as any },
      ],
      max_tokens: 400,
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

        console.log("[upload] AI Response Validation:", {
          action: parsed.action,
          intent: parsed.intent,
          scenario: parsed.scenario,
          tonesApplied: parsed.tonesApplied,
          lengthApplied: parsed.lengthApplied,
          wordCountSafe: parsed.wordCountSafe,
          wordCountBold: parsed.wordCountBold,
          emojiCountSafe: parsed.emojiCountSafe,
          emojiCountBold: parsed.emojiCountBold,
        });
      } else if (parsed.result) {
        const parts = parsed.result.split("|").map((s: string) => s.trim());
        if (parts.length === 2) {
          safe = parts[0];
          bold = parts[1];
          console.log("[upload] Using legacy format (no validation metadata)");
        }
      }
    } catch (parseError) {
      console.log("[upload] JSON parse failed, attempting raw split");
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
    console.error("[upload] Error (raw):", error);
    const { status, message, code } = extractOpenAIErrorDetails(error);

    if (code === "insufficient_quota") {
      return NextResponse.json(
        { error: message || "AI service quota exceeded", code, status: 503, model: MODEL_NAME },
        { status: 503 }
      );
    }

    const safeStatus =
      typeof status === "number" && status >= 400 && status < 600 ? status : 500;

    return NextResponse.json(
      { error: message, code, status: safeStatus, model: MODEL_NAME },
      { status: safeStatus }
    );
  }
}
