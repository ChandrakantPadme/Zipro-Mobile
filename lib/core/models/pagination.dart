/// Spring-style page aligned with [zipro_website_new/lib/api/types.ts] PaginatedResponse.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
  });

  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final raw = json['content'];
    final list = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(parseItem).toList()
        : <T>[];
    return PaginatedResponse<T>(
      content: list,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? list.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? list.length,
      number: (json['number'] as num?)?.toInt() ?? 0,
    );
  }
}
