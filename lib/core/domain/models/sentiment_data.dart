/// Domain models for sentiment analysis results.
///
/// [SentimentData] represents the aggregated analysis returned by
/// OpenAI from news headlines — including ratios, trend direction,
/// and the natural-language explanation paragraph.
///
/// [SentimentSnapshot] represents a single day in the 7-day trend,
/// stored in the `sentiment_snapshots` Firestore sub-collection.
library;

import 'package:equatable/equatable.dart';

/// Aggregated sentiment analysis for a celebrity.
class SentimentData extends Equatable {
  const SentimentData({
    required this.overallScore,
    required this.positiveRatio,
    required this.negativeRatio,
    required this.neutralRatio,
    required this.trendDirection,
    required this.explanation,
    required this.trendData,
    required this.dominantEmotion,
  });

  /// Overall sentiment score on a 0–100 scale.
  /// Computed as: positiveRatio × 100, adjusted by trend.
  final double overallScore;

  /// Proportion of positive headlines (0.0–1.0).
  final double positiveRatio;

  /// Proportion of negative headlines (0.0–1.0).
  final double negativeRatio;

  /// Proportion of neutral headlines (0.0–1.0).
  final double neutralRatio;

  /// Trend direction: "up", "down", or "stable".
  final String trendDirection;

  /// AI-generated 2–3 paragraph explanation of why sentiment
  /// is trending this way. Rendered with typewriter animation.
  final String explanation;

  /// 7-day trend data for the line chart.
  final List<SentimentSnapshot> trendData;

  /// Dominant emotional tone: "joy", "anger", "surprise", etc.
  final String dominantEmotion;

  @override
  List<Object?> get props => [
        overallScore,
        positiveRatio,
        negativeRatio,
        neutralRatio,
        trendDirection,
      ];

  Map<String, dynamic> toMap() => {
        'overallScore': overallScore,
        'positiveRatio': positiveRatio,
        'negativeRatio': negativeRatio,
        'neutralRatio': neutralRatio,
        'trendDirection': trendDirection,
        'explanation': explanation,
        'dominantEmotion': dominantEmotion,
        'trendData': trendData.map((s) => s.toFirestore()).toList(),
      };

  factory SentimentData.fromMap(Map<String, dynamic> map) {
    return SentimentData(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 50.0,
      positiveRatio: (map['positiveRatio'] as num?)?.toDouble() ?? 0.33,
      negativeRatio: (map['negativeRatio'] as num?)?.toDouble() ?? 0.33,
      neutralRatio: (map['neutralRatio'] as num?)?.toDouble() ?? 0.34,
      trendDirection: map['trendDirection'] as String? ?? 'stable',
      explanation: map['explanation'] as String? ?? '',
      dominantEmotion: map['dominantEmotion'] as String? ?? 'neutral',
      trendData: (map['trendData'] as List<dynamic>?)
              ?.map((e) =>
                  SentimentSnapshot.fromFirestore(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A single day's sentiment snapshot for trend charting.
///
/// Stored in `celebrities/{slug}/sentiment_snapshots/{date}`.
class SentimentSnapshot extends Equatable {
  const SentimentSnapshot({
    required this.date,
    required this.positiveCount,
    required this.negativeCount,
    required this.neutralCount,
    required this.totalMentions,
    required this.dominantEmotion,
    required this.score,
  });

  /// The date this snapshot represents (YYYY-MM-DD).
  final String date;

  final int positiveCount;
  final int negativeCount;
  final int neutralCount;
  final int totalMentions;
  final String dominantEmotion;

  /// Sentiment score for this day (0–100).
  final double score;

  @override
  List<Object?> get props => [date, score];

  Map<String, dynamic> toFirestore() => {
        'date': date,
        'positiveCount': positiveCount,
        'negativeCount': negativeCount,
        'neutralCount': neutralCount,
        'totalMentions': totalMentions,
        'dominantEmotion': dominantEmotion,
        'score': score,
        'timestamp': DateTime.now().toIso8601String(),
      };

  factory SentimentSnapshot.fromFirestore(Map<String, dynamic> data) {
    return SentimentSnapshot(
      date: data['date'] as String? ?? '',
      positiveCount: data['positiveCount'] as int? ?? 0,
      negativeCount: data['negativeCount'] as int? ?? 0,
      neutralCount: data['neutralCount'] as int? ?? 0,
      totalMentions: data['totalMentions'] as int? ?? 0,
      dominantEmotion: data['dominantEmotion'] as String? ?? 'neutral',
      score: (data['score'] as num?)?.toDouble() ?? 50.0,
    );
  }
}
