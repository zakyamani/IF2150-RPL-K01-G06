class ApiError implements Exception {
  final String code, message;
  final Map<String, List<String>> fieldErrors;
  final int? status;
  const ApiError(
    this.code,
    this.message, {
    this.fieldErrors = const {},
    this.status,
  });
  @override
  String toString() => message;
}
