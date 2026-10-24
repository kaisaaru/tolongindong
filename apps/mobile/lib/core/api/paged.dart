/// Satu halaman daftar dari paginator Laravel:
/// `{"current_page": 1, "data": [...], "last_page": 3, ...}`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<T> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) item,
  ) => Paged(
    items: [
      for (final e in json['data'] as List? ?? const [])
        item((e as Map).cast<String, dynamic>()),
    ],
    page: (json['current_page'] as num?)?.toInt() ?? 1,
    lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
  );
}
