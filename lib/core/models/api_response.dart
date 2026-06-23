/// Generic API Response Model
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final dynamic error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
    this.statusCode,
  });

  bool get isUnauthorized => statusCode == 401;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? fromJsonT, {
    int? statusCode,
  }) {
    // If the API places the actual payload under `data`, use that.
    // Some endpoints (e.g. auth verify) return important fields like `token`,
    // `user` and `device` at the root of the response. In that case we want
    // to pass the whole response object as `data` so callers can access those
    // root-level fields without losing them.
    final dynamic rawData = json.containsKey('data') && json['data'] != null
        ? json['data']
        : json;
    final T? parsedData = rawData != null && fromJsonT != null
        ? fromJsonT(rawData)
        : rawData as T?;

    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: parsedData,
      error: json['error'],
      statusCode: statusCode,
    );
  }
}
