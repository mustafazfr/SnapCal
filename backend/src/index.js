/**
 * CalorieLens — Cloudflare Worker API Proxy
 *
 * Endpoints:
 *   POST /api/analyze  — food image analysis (Claude Sonnet, vision)
 *   POST /api/chat     — health chatbox (Claude Haiku, text)
 *   POST /api/report   — weekly nutrition report (Claude Haiku, text)
 *
 * Required secrets (set via `wrangler secret put`):
 *   ANTHROPIC_API_KEY  — your Anthropic API key
 *   APP_SECRET         — shared secret sent by the Flutter app in x-app-secret header
 */

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const SONNET_MODEL = 'claude-sonnet-4-5-20250929';
const HAIKU_MODEL = 'claude-haiku-4-5-20251001';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-app-secret',
};

// ─── Main handler ─────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== 'POST') {
      return jsonError('Method not allowed', 405);
    }

    // Auth check
    const appSecret = request.headers.get('x-app-secret');
    if (!env.APP_SECRET || appSecret !== env.APP_SECRET) {
      return jsonError('Unauthorized', 401);
    }

    const url = new URL(request.url);

    try {
      if (url.pathname === '/api/analyze') return handleAnalyze(request, env);
      if (url.pathname === '/api/chat')    return handleChat(request, env);
      if (url.pathname === '/api/report')  return handleReport(request, env);
      return jsonError('Not found', 404);
    } catch (e) {
      return jsonError(`Internal error: ${e.message}`, 500);
    }
  },
};

// ─── /api/analyze ─────────────────────────────────────────────────────────────

async function handleAnalyze(request, env) {
  const { image_base64, media_type = 'image/jpeg', correction, lang = 'en' } =
    await request.json();

  if (!image_base64) return jsonError('image_base64 is required', 400);

  const langName = lang === 'tr' ? 'Turkish' : 'English';
  const langInstruction = `\n\nLANGUAGE REQUIREMENT: You MUST respond with the "foodName" and "notes" fields in ${langName}. The nutritional data fields remain as numbers.`;

  const basePrompt = `You are a professional nutritionist AI analyzing a food photo.

CRITICAL RULES:
- ONLY identify foods you can clearly see in the image. Do NOT assume, infer, or hallucinate items that are not visible.
- Do NOT complete a "typical meal" — only report what is actually on the plate/in the photo.
- If you see meat, identify it precisely (e.g. meatball/köfte, not sausage) based on shape, color, and texture.
- Be conservative with portion estimates. Estimate weight based on visual plate size.
- For salads and raw vegetables, keep carb estimates low (leafy greens and raw veggies are low-carb).
- When uncertain about a specific food item, say so in the notes field.

TEXTURE & SHAPE AWARENESS:
- Pay close attention to textures. Differentiate between shredded/grated vegetables vs thick wedges, cubes, or slices.
- Thin, stringy, shredded orange items are most likely grated carrots, NOT sweet potato wedges.
- Thin purple shreds are red/purple cabbage slaw, NOT cooked vegetables.

CULTURAL CONTEXT:
- Consider Mediterranean/Turkish cuisine context: shredded carrots, red cabbage slaw, lettuce, tomato, and lemon wedges are standard salad garnishes alongside grilled meats (köfte, kebab).
- Small round/oval grilled meat pieces are likely köfte (Turkish meatballs), not sausages.

Respond ONLY with a valid JSON object. No markdown, no code fences, no explanation — raw JSON only:
{
  "foodName": "string (name of the main dish or a brief description of all visible items)",
  "portionSize": "string (e.g. 250g or 1 cup — be conservative)",
  "calories": number,
  "protein": number (grams),
  "carbs": number (grams),
  "fat": number (grams),
  "confidence": "high|medium|low",
  "notes": "string (list ONLY items you can actually see, mention any uncertainty)"
}
If you cannot identify food in the image, set foodName to "Unknown" and confidence to "low".`;

  const correctionNote = correction
    ? `\n\nIMPORTANT CORRECTION FROM USER: Your previous analysis was wrong. The user says this food is actually: "${correction}". Please re-analyze with this correction in mind and provide accurate nutritional values for what the user described.`
    : '';

  const promptText = basePrompt + langInstruction + correctionNote;

  const anthropicRes = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: SONNET_MODEL,
      max_tokens: 1024,
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type, data: image_base64 } },
          { type: 'text', text: promptText },
        ],
      }],
    }),
  });

  const data = await anthropicRes.json();
  return jsonResponse(data, anthropicRes.status);
}

// ─── /api/chat ────────────────────────────────────────────────────────────────

async function handleChat(request, env) {
  const { messages, lang = 'en', calorie_goal, today_calories } =
    await request.json();

  if (!messages || !Array.isArray(messages)) {
    return jsonError('messages array is required', 400);
  }

  const langName = lang === 'tr' ? 'Türkçe' : 'English';
  const systemPrompt = `You are the health assistant of the CalorieLens app.

RULES:
- ONLY answer questions about health, nutrition, diet, fitness, exercise, and wellness.
- For unrelated questions, politely say "I can only help with health topics."
- Do NOT make medical diagnoses. Recommend consulting a doctor when appropriate.
- Keep answers concise (max 3-4 paragraphs).
- Always respond in ${langName}.

USER PROFILE:
- Daily calorie goal: ${calorie_goal ?? 'unknown'} kcal
- Today's calorie intake: ${today_calories ?? 'unknown'} kcal`;

  const anthropicRes = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: HAIKU_MODEL,
      max_tokens: 1024,
      system: systemPrompt,
      messages: messages.slice(-15), // Last 15 messages for context window
    }),
  });

  const data = await anthropicRes.json();
  return jsonResponse(data, anthropicRes.status);
}

// ─── /api/report ──────────────────────────────────────────────────────────────

async function handleReport(request, env) {
  const {
    lang = 'en',
    calorie_goal,
    start_date,
    end_date,
    total_days,
    logged_days,
    avg_calories,
    avg_protein,
    avg_carbs,
    avg_fat,
    top_foods,
    under_goal_days,
    over_goal_days,
  } = await request.json();

  const langName = lang === 'tr' ? 'Türkçe' : 'English';

  const prompt = `You are a professional nutritionist. Analyze the following nutrition data and provide personalized advice.

USER PROFILE:
- Daily calorie goal: ${calorie_goal} kcal
- Period: ${start_date} – ${end_date}

DATA:
- Total days: ${total_days}
- Days logged: ${logged_days}
- Average daily calories: ${avg_calories} kcal
- Average protein: ${avg_protein}g | Carbs: ${avg_carbs}g | Fat: ${avg_fat}g
- Most eaten foods: ${top_foods}
- Days under goal: ${under_goal_days}
- Days over goal: ${over_goal_days}

TASK:
1. Overall assessment (2-3 sentences)
2. Strengths (2-3 points)
3. Areas for improvement (2-3 points)
4. Concrete suggestions (3-4 points)

Be concise, motivating, and constructive. Respond in ${langName}.`;

  const anthropicRes = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: HAIKU_MODEL,
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    }),
  });

  const data = await anthropicRes.json();
  return jsonResponse(data, anthropicRes.status);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function jsonError(message, status = 400) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
