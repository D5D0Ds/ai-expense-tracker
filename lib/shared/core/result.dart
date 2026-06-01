/// A typed success/failure result for repository and service boundaries.
sealed class Result<T> {
  /// Creates a result.
  const Result();

  /// Returns true when this result contains a value.
  bool get isSuccess => this is Success<T>;

  /// Folds this result into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Failure<T>(:final failure) => onFailure(failure),
    };
  }
}

/// A successful result.
final class Success<T> extends Result<T> {
  /// Creates a successful result.
  const Success(this.value);

  /// Successful value.
  final T value;
}

/// A failed result.
final class Failure<T> extends Result<T> {
  /// Creates a failed result.
  const Failure(this.failure);

  /// Failure payload.
  final AppFailure failure;
}

/// A user-safe failure object.
final class AppFailure {
  /// Creates a failure.
  const AppFailure(this.message, {this.cause});

  /// User-safe message.
  final String message;

  /// Optional technical cause for logs/tests.
  final Object? cause;

  @override
  String toString() => message;
}
