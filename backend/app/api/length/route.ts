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
    const { text, length, tones } = await request.json();

    if (!text || typeof text !== "string") {
      return NextResponse.json(
        { error: "Text is required and must be a string" },
        { status: 400 }
      );
    }

    if (!length || typeof length !== "string") {
      return NextResponse.json(
        { error: "Length is required and must be a string" },
        { status: 400 }
      );
    }

    const validLengths = ["Short", "Medium", "Long"];

    if (!validLengths.includes(length)) {
      return NextResponse.json(
        { error: "Length must be Short, Medium, or Long" },
        { status: 400 }
      );
    }

    console.log("[length] model:", MODEL_NAME);

    let lengthInstruction = "";
    let wordCountLimit = "";

    switch (length) {
      case "Short":
        lengthInstruction = "Make it SHORT and concise. Get straight to the point.";
        wordCountLimit = "STRICT LIMIT: 5-10 words MAX. Count every word.";
        break;

      case "Medium":
        lengthInstruction = "Make it MEDIUM length. Conversational but not too long.";
        wordCountLimit = "STRICT LIMIT: 10-25 words. Count every word.";
        break;

      case "Long":
        lengthInstruction = "Make it LONGER and more detailed. Add context and warmth.";
        wordCountLimit = "STRICT LIMIT: 25-50 words. Count every word.";
        break;
    }

    let toneInstruction = "";

    if (tones && Array.isArray(tones) && tones.length > 0) {
      if (tones.length > 3) {
        return NextResponse.json(
          { error: "Maximum 3 tones allowed" },
          { status: 400 }
        );
      }

      const toneDescription = tones.join(", ");

      toneInstruction = `\nAlso blend these tones: ${toneDescription}`;
    }

    const systemPrompt = `You're a texting expert. REWRITE the user's message at this length: ${lengthInstruction}${toneInstruction}

CRITICAL: REWRITE/IMPROVE the text, don't generate a reply. Keep the same meaning.

STEP 1: UNDERSTAND the user's intent first

- Users may have spelling/grammar/punctuation errors

- Figure out what they're trying to say before rewriting

- Example: "wanna hnag out tomrrow" → user wants to hang out tomorrow

STEP 2: REWRITE at the target length

${wordCountLimit}

Generate 2 rewritten versions:

1. SAFE - Target length, friendly/neutral

2. BOLD - Target length, more confident/direct

Examples:

SHORT:

Safe: "yeah let's do it"

Bold: "let's go"

MEDIUM:

Safe: "yeah that sounds good to me, let me know what works"

Bold: "i'm down, let's make it happen - you pick the time"

LONG:

Safe: "been thinking we should hang out soon - maybe grab food or something? let me know what works for you and we can figure out a time"

Bold: "we're hanging out soon whether you like it or not 😏 but seriously, let's grab food this week - i'll clear my schedule, you just pick the day"

CRITICAL RULES:

- ${length === "Short" ? "Be extremely concise, NO fluff, 5-10 words ONLY" : length === "Long" ? "Add real context, 25-50 words, count carefully" : "Balance brevity with clarity, 10-25 words exactly"}

- REWRITE the text, don't reply to it

- Keep original meaning and intent

- Sound natural, not formal

- NO corporate speak

- NO labels or quotes

- COUNT THE WORDS CAREFULLY

- NO word counts in output like "(27 words)"

- NO random punctuation like "--" or "/" or excessive "-"

- Use emojis SPARINGLY (max 1-2 for Long, max 1 for Medium, 0-1 for Short)

- Only use contextually appropriate emojis

- Appropriate: 😊 (friendly), 😅 (apologetic), 😏 (flirty), 👀 (interested)

- AVOID: 😉 (unless truly flirty)

Return ONLY valid JSON:

{
  "alternatives": [
    "<safe version - exact word count>",
    "<bold version - exact word count>"
  ]
}`;

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text },
      ],
      temperature: 0.7,
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
    console.error("Length API Error (raw):", error);
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
