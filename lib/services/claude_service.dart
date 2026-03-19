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
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-5-20250929';

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
  Future<Map<String, dynamic>> analyzeImage(
    File imageFile, {
    String? correction,
    String langCode = 'en',
  }) async {
    final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';

    if (apiKey.isEmpty || apiKey == 'your_key_here') {
      throw const ClaudeException(
        ClaudeError.noApiKey,
        'No API key found. Add your Claude key to the .env file: CLAUDE_API_KEY=sk-ant-…',
      );
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final langInst = _languageInstruction(langCode);
      final promptText = correction != null
          ? '$_prompt$langInst\n\nIMPORTANT CORRECTION FROM USER: Your previous analysis was wrong. The user says this food is actually: "$correction". Please re-analyze with this correction in mind and provide accurate nutritional values for what the user described.'
          : '$_prompt$langInst';

      final response = await http.post(
        Uri.parse(_apiUrl),
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
                {
                  'type': 'text',
                  'text': promptText,
                },
              ],
            },
          ],
        }),
      );

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

        // Detect insufficient credits
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

      // Strip optional markdown fences just in case
      final clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final json = jsonDecode(clean) as Map<String, dynamic>;

      // Normalise types — model sometimes returns strings for numbers
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
}
