/// A functional [Result] type that wraps either a success value [T]
/// or a typed [Failure].
///
/// This is the single return type used across the entire domain and
/// data layer, ensuring that no raw exceptions leak across boundaries.
///
/// Usage:
/// ```dart
/// final result = await newsService.fetchNews('Taylor Swift');
/// switch (result) {
///   case Success(:final value): // handle List<MediaItem>
///   case Error(:final failure): // handle Failure subtype
/// }
/// ```
library;

import 'failures.dart';

/// Sealed result type — either [Success] or [Error].
sealed class Result<T> {
  const Result();

  /// Convenience getter — returns `true` when this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Convenience getter — returns `true` when this is an [Error].
  bool get isError => this is Error<T>;

  /// Map the success value, leaving errors untouched.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Error(:final failure) => Error(failure),
    };
  }

  /// Flat-map for chaining async operations.
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    return switch (this) {
      Success(:final value) => transform(value),
      Error(:final failure) => Error<R>(failure),
    };
  }

  /// Unwrap the success value or return a fallback.
  T getOrElse(T Function() fallback) {
    return switch (this) {
      Success(:final value) => value,
      Error() => fallback(),
    };
  }
}

/// Represents a successful result containing [value].
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

/// Represents a failed result containing a typed [failure].
final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
