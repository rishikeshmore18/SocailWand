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
    const { text, languageId, languageName, previousOutputs } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return NextResponse.json({ error: "Text is required for translation" }, { status: 400 });
    }

    const targetLanguage =
      typeof languageName === "string" && languageName.trim().length > 0
        ? languageName.trim()
        : typeof languageId === "string" && languageId.trim().length > 0
        ? languageId.trim()
        : "the requested language";

    console.log("[translate] model:", MODEL_NAME, "target:", targetLanguage);

    const systemPrompt = `<system_role>
You are a translation expert. Translate text to the target language while preserving tone, intent, and formatting.
</system_role>

<input_parameters>
<target_language>${targetLanguage}</target_language>
<source_text>${text}</source_text>
${
  previousOutputs && Array.isArray(previousOutputs) && previousOutputs.length > 0
    ? `
<diversification status="mandatory">
User already saw these translations. Generate COMPLETELY DIFFERENT options:
${previousOutputs.map((msg: string, i: number) => `${i + 1}. "${msg}"`).join("\n")}
</diversification>
`
    : ""
}
</input_parameters>

<translation_rules>
- Preserve the original meaning exactly.
- Preserve tone and formality (casual stays casual, formal stays formal).
- Preserve punctuation and emojis when they fit naturally in the target language.
- Do not add new information.
- Do not remove important details.
- Keep the same perspective (first/second/third person).
- Output must be natural and fluent for a native speaker.
</translation_rules>

<output_format type="structured_json">
<instructions>
Return ONLY this JSON (no markdown, no preamble).
Use double quotes for all strings.
Ensure valid JSON syntax.
</instructions>
<json_structure>
{
  "alternatives": [
    "translation option 1",
    "translation option 2"
  ]
}
</json_structure>
</output_format>`;

    const completion = await openai.chat.completions.create({
      model: MODEL_NAME,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: `Translate the source text to ${targetLanguage}. Return two alternatives in JSON.`,
        },
      ],
      max_tokens: 400,
      temperature: 0.6,
    });

    const aiResponse = completion.choices[0]?.message?.content?.trim() || "";

    let alternatives: string[] = [];

    try {
      const cleanResponse = aiResponse.replace(/```json\n?|```\n?/g, "").trim();
      const parsed = JSON.parse(cleanResponse);
      if (Array.isArray(parsed.alternatives)) {
        alternatives = parsed.alternatives.filter((item) => typeof item === "string");
      }
    } catch (parseError) {
      console.error("[translate] JSON parse error:", parseError);
    }

    if (alternatives.length < 2) {
      return NextResponse.json(
        { error: "Translation failed to return two alternatives" },
        { status: 502 }
      );
    }

    return NextResponse.json({
      alternatives: alternatives.slice(0, 2),
    });
  } catch (err: any) {
    const { status, message, code } = extractOpenAIErrorDetails(err);

    console.error("OpenAI error (translate):", {
      status,
      code,
      message,
    });

    return NextResponse.json(
      { error: message || "AI service unavailable" },
      { status: status || 503 }
    );
  }
}
