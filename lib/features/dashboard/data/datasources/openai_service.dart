library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_keys.dart';
import '../../../../core/domain/models/celebrity.dart';
import '../../../../core/domain/models/sentiment_data.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';

class OpenAiService {
  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _model = 'llama-3.3-70b-versatile';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
      };

  // ── Biography ──────────────────────────────────────────────────────

  Future<Result<Biography>> fetchBiography(String celebrityName) async {
    try {
      final prompt = '''You are a celebrity biography expert. Return ONLY valid JSON with this exact structure:
{
  "profession": "string — their primary profession/title",
  "summary": "string — 2-3 sentence overview of who they are",
  "background": "string — 2-3 paragraphs covering early life, career trajectory, and current status",
  "notableWorks": ["string array — 5-8 most notable achievements, albums, films, companies, etc."],
  "controversies": ["string array — 0-5 notable controversies or issues, empty array if none"]
}
Do not include any text outside the JSON object. Do not wrap in markdown code blocks.

Generate a comprehensive biography for: $celebrityName''';

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.4,
        'response_format': {'type': 'json_object'},
      });

      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: body,
      );

      debugPrint('Groq biography status: ${response.statusCode}');
      return _handleBiographyResponse(response);
    } on http.ClientException {
      return const Error(NetworkFailure());
    } catch (e, st) {
      return Error(ParseFailure(
        message: 'Biography generation failed: ${e.toString()}',
        stackTrace: st,
      ));
    }
  }

  // ── Sentiment ──────────────────────────────────────────────────────

  Future<Result<SentimentData>> analyzeSentiment(
    String celebrityName,
    List<String> headlines,
  ) async {
    if (headlines.isEmpty) {
      return Success(SentimentData(
        overallScore: 50.0,
        positiveRatio: 0.33,
        negativeRatio: 0.33,
        neutralRatio: 0.34,
        trendDirection: 'stable',
        explanation: 'No recent headlines available for sentiment analysis.',
        trendData: _generateDefaultTrend(),
        dominantEmotion: 'neutral',
      ));
    }

    try {
      final headlineList = headlines
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');

      final prompt =
          '''You are a sentiment analysis expert specializing in celebrity media coverage.
Analyze the provided headlines and return ONLY valid JSON with no markdown or code blocks:
{
  "positiveRatio": 0.0,
  "negativeRatio": 0.0,
  "neutralRatio": 0.0,
  "overallScore": 0,
  "trendDirection": "up",
  "dominantEmotion": "string",
  "trendData": [
    {"day": "Mon", "score": 0},
    {"day": "Tue", "score": 0},
    {"day": "Wed", "score": 0},
    {"day": "Thu", "score": 0},
    {"day": "Fri", "score": 0},
    {"day": "Sat", "score": 0},
    {"day": "Sun", "score": 0}
  ],
  "explanation": "string — 2-3 paragraphs explaining the sentiment trend"
}
Rules: ratios must sum to 1.0. overallScore is 0-100 (0=very negative, 100=very positive).
trendDirection is one of: "up", "down", "stable".

Analyze sentiment for $celebrityName based on these recent headlines:

$headlineList''';

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      });

      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: body,
      );

      debugPrint('Groq sentiment status: ${response.statusCode}');
      return _handleSentimentResponse(response);
    } on http.ClientException {
      return const Error(NetworkFailure());
    } catch (e, st) {
      return Error(ParseFailure(
        message: 'Sentiment analysis failed: ${e.toString()}',
        stackTrace: st,
      ));
    }
  }

  // ── Response Handlers ──────────────────────────────────────────────

  Result<Biography> _handleBiographyResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final content = json['choices'][0]['message']['content'] as String;

          final cleaned = content
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();

          final bioJson = jsonDecode(cleaned) as Map<String, dynamic>;
          return Success(Biography.fromMap(bioJson));
        } catch (e, st) {
          return Error(ParseFailure(
            message: 'Failed to parse biography JSON: ${e.toString()}',
            stackTrace: st,
          ));
        }
      case 401:
        return const Error(ApiKeyFailure(
          serviceName: 'Groq',
          message: 'Invalid Groq API key. Check your api_keys.dart.',
        ));
      case 429:
        return const Error(RateLimitFailure());
      default:
        debugPrint('Groq biography error body: ${response.body}');
        return Error(ServerFailure(
          message: 'Groq returned HTTP ${response.statusCode}',
        ));
    }
  }

  Result<SentimentData> _handleSentimentResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final content = json['choices'][0]['message']['content'] as String;

          final cleaned = content
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();

          final sentimentJson = jsonDecode(cleaned) as Map<String, dynamic>;

          final trendData = (sentimentJson['trendData'] as List<dynamic>?)
                  ?.asMap()
                  .entries
                  .map((e) {
                    final item = e.value as Map<String, dynamic>;
                    return SentimentSnapshot(
                      date: item['day'] as String? ?? 'Day ${e.key + 1}',
                      positiveCount: 0,
                      negativeCount: 0,
                      neutralCount: 0,
                      totalMentions: 0,
                      dominantEmotion:
                          sentimentJson['dominantEmotion'] as String? ?? 'neutral',
                      score: (item['score'] as num?)?.toDouble() ?? 50.0,
                    );
                  }).toList() ??
              _generateDefaultTrend();

          return Success(SentimentData(
            overallScore:
                (sentimentJson['overallScore'] as num?)?.toDouble() ?? 50.0,
            positiveRatio:
                (sentimentJson['positiveRatio'] as num?)?.toDouble() ?? 0.33,
            negativeRatio:
                (sentimentJson['negativeRatio'] as num?)?.toDouble() ?? 0.33,
            neutralRatio:
                (sentimentJson['neutralRatio'] as num?)?.toDouble() ?? 0.34,
            trendDirection:
                sentimentJson['trendDirection'] as String? ?? 'stable',
            explanation: sentimentJson['explanation'] as String? ?? '',
            trendData: trendData,
            dominantEmotion:
                sentimentJson['dominantEmotion'] as String? ?? 'neutral',
          ));
        } catch (e, st) {
          return Error(ParseFailure(
            message: 'Failed to parse sentiment JSON: ${e.toString()}',
            stackTrace: st,
          ));
        }
      case 401:
        return const Error(ApiKeyFailure(
          serviceName: 'Groq',
          message: 'Invalid Groq API key. Check your api_keys.dart.',
        ));
      case 429:
        return const Error(RateLimitFailure());
      default:
        debugPrint('Groq sentiment error body: ${response.body}');
        return Error(ServerFailure(
          message: 'Groq returned HTTP ${response.statusCode}',
        ));
    }
  }

  List<SentimentSnapshot> _generateDefaultTrend() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days
        .map((day) => SentimentSnapshot(
              date: day,
              positiveCount: 0,
              negativeCount: 0,
              neutralCount: 0,
              totalMentions: 0,
              dominantEmotion: 'neutral',
              score: 50.0,
            ))
        .toList();
  }

  void dispose() => _client.close();
}