import OpenAI from "openai";

import { NextResponse } from "next/server";

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

export async function POST(request: Request) {
  try {
    const { text, tones } = await request.json();

    if (!text || typeof text !== "string") {
      return NextResponse.json(
        { error: "Text is required and must be a string" },
        { status: 400 }
      );
    }

    if (!tones || !Array.isArray(tones) || tones.length === 0) {
      return NextResponse.json(
        { error: "At least one tone must be selected" },
        { status: 400 }
      );
    }

    if (tones.length > 3) {
      return NextResponse.json(
        { error: "Maximum 3 tones allowed" },
        { status: 400 }
      );
    }

    console.log("[tone] model:", MODEL_NAME);

    const toneDescription = tones.join(", ");

    const systemPrompt = `You're a texting expert. REWRITE the user's message with these tones: ${toneDescription}

CRITICAL: REWRITE/IMPROVE the text, don't generate a reply to it. Keep the same meaning.

STEP 1: UNDERSTAND the user's intent first

- Users may have spelling/grammar errors - that's normal

- Figure out what they're trying to say

- Example: "cant maek it sorr" → user can't make it and is apologizing

STEP 2: REWRITE with the requested tone

Original text: "${text}"

Generate 2 rewritten versions:

1. SAFE - Applies tones but stays friendly/neutral

2. BOLD - Applies tones with more confidence/directness

STRICT LENGTH RULE:

- If original is under 10 words: Keep under 15 words

- If original is 10-20 words: Keep under 25 words

- If original is over 20 words: Keep under 35 words

Tone guides:

CONFIDENT: Direct, no hedging

Safe: "let's do this"

Bold: "we're doing this"

PLAYFUL: Light teasing, fun

Safe: "you gonna make me wait? 😊"

Bold: "keeping me waiting huh 👀"

FLIRTATIOUS: Shows interest, subtle compliments

Safe: "i like your style"

Bold: "you got my attention 😏"

CASUAL: Lowercase, relaxed

Safe: "yeah sounds good"

Bold: "bet, let's go"

PROFESSIONAL: Proper grammar, clear

Safe: "Let's schedule a call"

Bold: "I'll set up a call for us"

EMPATHETIC: Understanding, warm

Safe: "that sounds rough, here if you need anything"

Bold: "i got you, seriously"

ASSERTIVE: Clear, direct

Safe: "I need this by Friday"

Bold: "Friday deadline, no exceptions"

CRITICAL RULES:

- REWRITE the text, don't reply to it

- Sound like a human

- NO corporate speak

- NO labels or quotes

- NO word counts in output

- NO random punctuation like "--" or "/" or excessive "-"

- Use emojis SPARINGLY (max 1 per message)

- Only use contextually appropriate emojis

- Appropriate: 😊 (friendly), 😅 (apologetic), 😏 (flirty), 👀 (interested)

- AVOID: 😉 (unless truly flirty context)

Return ONLY valid JSON:

{
  "alternatives": [
    "<safe version>",
    "<bold version>"
  ]
}`;

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text },
      ],
      temperature: 0.75,
      max_tokens: 200,
      response_format: { type: "json_object" },
    });

    const aiResponse = completion.choices[0]?.message?.content?.trim();

    if (!aiResponse) {
      throw new Error("No response from AI");
    }

    let parsed: any;

    try {
      parsed = JSON.parse(aiResponse);
    } catch {
      const cleanResult = aiResponse.replace(/^["']|["']$/g, "");
      return NextResponse.json({ alternatives: [cleanResult, cleanResult] });
    }

    if (!Array.isArray(parsed.alternatives) || parsed.alternatives.length < 2) {
      throw new Error("Invalid response structure");
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

    return NextResponse.json({ alternatives: cleanAlternatives });
  } catch (error: any) {
    console.error("Tone API Error (raw):", error);
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
