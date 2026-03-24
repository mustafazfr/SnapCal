import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/meal.dart';

class ClaudeException implements Exception {
  final ClaudeError kind;
  final String message;
  const ClaudeException(this.kind, this.message);

  @override
  String toString() => message;
}

enum ClaudeError {
  noApiKey,
  invalidApiKey,
  noInternet,
  unrecognizedFood,
  rateLimited,
  insufficientCredits,
  unknown,
}

class ClaudeService {
  static const _directApiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-5-20250929';

  /// If BACKEND_URL is set in .env, requests go through the proxy.
  /// Otherwise falls back to direct Anthropic API (dev mode).
  static String? get _backendUrl => dotenv.env['BACKEND_URL'];
  static bool get _useProxy => _backendUrl != null && _backendUrl!.isNotEmpty;

  static const _prompt = '''
You are a professional nutritionist AI analyzing a food photo.

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
If you cannot identify food in the image, set foodName to "Unknown" and confidence to "low".
''';

  /// Returns a language instruction to append to the prompt.
  static String _languageInstruction(String langCode) {
    final langName = langCode == 'tr' ? 'Turkish' : 'English';
    return '\n\nLANGUAGE REQUIREMENT: You MUST respond with the "foodName" and "notes" fields in $langName. The nutritional data fields remain as numbers. For example, if the language is Turkish, write "Izgara Köfte" instead of "Grilled Meatballs".';
  }

  /// Analyzes a food image. If [correction] is provided, it's sent as
  /// user feedback so the model can correct its previous analysis.
  /// Routes through backend proxy if BACKEND_URL is set in .env.
  Future<Map<String, dynamic>> analyzeImage(
    File imageFile, {
    String? correction,
    String langCode = 'en',
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final http.Response response;

      if (_useProxy) {
        // ── Proxy mode ─────────────────────────────────────────────────────
        final appSecret = dotenv.env['APP_SECRET'] ?? '';
        response = await http.post(
          Uri.parse('$_backendUrl/api/analyze'),
          headers: {
            'Content-Type': 'application/json',
            'x-app-secret': appSecret,
          },
          body: jsonEncode({
            'image_base64': base64Image,
            'media_type': 'image/jpeg',
            'correction': correction,
            'lang': langCode,
          }),
        );
      } else {
        // ── Direct API mode (development) ──────────────────────────────────
        final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
        if (apiKey.isEmpty || apiKey == 'your_key_here') {
          throw const ClaudeException(
            ClaudeError.noApiKey,
            'No API key found. Add your Claude key to the .env file: CLAUDE_API_KEY=sk-ant-…',
          );
        }

        final langInst = _languageInstruction(langCode);
        final promptText = correction != null
            ? '$_prompt$langInst\n\nIMPORTANT CORRECTION FROM USER: Your previous analysis was wrong. The user says this food is actually: "$correction". Please re-analyze with this correction in mind and provide accurate nutritional values for what the user described.'
            : '$_prompt$langInst';

        response = await http.post(
          Uri.parse(_directApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 1024,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/jpeg',
                      'data': base64Image,
                    },
                  },
                  {'type': 'text', 'text': promptText},
                ],
              },
            ],
          }),
        );
      }

      return _parseAnthropicResponse(response);
    } on ClaudeException {
      rethrow;
    } on SocketException {
      throw const ClaudeException(
        ClaudeError.noInternet,
        'No internet connection. Please check your network and try again.',
      );
    } on FormatException {
      throw const ClaudeException(
        ClaudeError.unrecognizedFood,
        'Could not parse the nutritional data. Try a different photo.',
      );
    } catch (e) {
      throw ClaudeException(
          ClaudeError.unknown, 'Unexpected error: ${e.toString()}');
    }
  }

  Map<String, dynamic> _parseAnthropicResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw const ClaudeException(
        ClaudeError.invalidApiKey,
        'Invalid API key. Please check the CLAUDE_API_KEY value in your .env file.',
      );
    }
    if (response.statusCode == 429) {
      throw const ClaudeException(
        ClaudeError.rateLimited,
        'API rate limit reached. Please wait a moment and try again.',
      );
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg = body['error']?['message'] ?? 'Unknown error';
      final errorType = body['error']?['type'] ?? '';
      if (errorMsg.toLowerCase().contains('credit') ||
          errorMsg.toLowerCase().contains('billing')) {
        throw const ClaudeException(
          ClaudeError.insufficientCredits,
          'Insufficient API credits.',
        );
      }
      throw ClaudeException(
        ClaudeError.unknown,
        '[${response.statusCode}] $errorType: $errorMsg',
      );
    }

    final body = jsonDecode(response.body);
    final content = body['content'] as List<dynamic>;
    final text = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join();

    if (text.trim().isEmpty) {
      throw const ClaudeException(
        ClaudeError.unrecognizedFood,
        'The model returned an empty response. Try a clearer photo.',
      );
    }

    final clean = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final json = jsonDecode(clean) as Map<String, dynamic>;

    return {
      'foodName': json['foodName']?.toString() ?? 'Unknown',
      'portionSize': json['portionSize']?.toString() ?? '',
      'calories': _toInt(json['calories']),
      'protein': _toDouble(json['protein']),
      'carbs': _toDouble(json['carbs']),
      'fat': _toDouble(json['fat']),
      'confidence': json['confidence']?.toString() ?? 'medium',
      'notes': json['notes']?.toString() ?? '',
    };
  }

  /// Builds a [Meal] from the JSON returned by [analyzeImage].
  static Meal mealFromJson(Map<String, dynamic> json, String? imagePath) {
    return Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodName: json['foodName'] as String,
      portionSize: json['portionSize'] as String,
      calories: json['calories'] as int,
      protein: json['protein'] as double,
      carbs: json['carbs'] as double,
      fat: json['fat'] as double,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      confidence: json['confidence'] as String,
      notes: json['notes'] as String,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Generates a weekly/monthly nutrition report from meal stats.
  /// Routes through /api/report proxy if BACKEND_URL set, otherwise direct Haiku.
  Future<String> generateNutritionReport({
    required Map<String, dynamic> stats,
    required String langCode,
  }) async {
    try {
      final http.Response response;

      if (_useProxy) {
        final appSecret = dotenv.env['APP_SECRET'] ?? '';
        response = await http.post(
          Uri.parse('$_backendUrl/api/report'),
          headers: {
            'Content-Type': 'application/json',
            'x-app-secret': appSecret,
          },
          body: jsonEncode({...stats, 'lang': langCode}),
        );
      } else {
        final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
        if (apiKey.isEmpty || apiKey == 'your_key_here') {
          throw const ClaudeException(ClaudeError.noApiKey, 'No API key found.');
        }
        final langName = langCode == 'tr' ? 'Türkçe' : 'English';
        final prompt = _buildReportPrompt(stats, langName);
        response = await http.post(
          Uri.parse(_directApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 1024,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        );
      }

      if (response.statusCode != 200) {
        throw ClaudeException(
            ClaudeError.unknown, 'Report error: ${response.statusCode}');
      }
      final body = jsonDecode(response.body);
      final content = body['content'] as List<dynamic>;
      return content
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String)
          .join()
          .trim();
    } on ClaudeException {
      rethrow;
    } on SocketException {
      throw const ClaudeException(ClaudeError.noInternet, 'No internet connection.');
    } catch (e) {
      throw ClaudeException(ClaudeError.unknown, 'Report error: ${e.toString()}');
    }
  }

  static String _buildReportPrompt(Map<String, dynamic> s, String langName) {
    return '''You are a professional nutritionist. Analyze the following nutrition data and provide personalized advice.

USER PROFILE:
- Daily calorie goal: ${s['calorie_goal']} kcal
- Period: ${s['start_date']} – ${s['end_date']}

DATA:
- Total days: ${s['total_days']}
- Days logged: ${s['logged_days']}
- Average daily calories: ${s['avg_calories']} kcal
- Average protein: ${s['avg_protein']}g | Carbs: ${s['avg_carbs']}g | Fat: ${s['avg_fat']}g
- Most eaten foods: ${s['top_foods']}
- Days under goal: ${s['under_goal_days']}
- Days over goal: ${s['over_goal_days']}

TASK:
1. Overall assessment (2-3 sentences)
2. Strengths (2-3 points)
3. Areas for improvement (2-3 points)
4. Concrete suggestions (3-4 points)

Be concise, motivating, and constructive. Respond in $langName.''';
  }
}
