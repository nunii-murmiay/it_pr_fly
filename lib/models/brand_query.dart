class BrandQuery {
  final String search;
  final String? country;
  final String? supplierId;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const BrandQuery({
    this.search = '',
    this.country,
    this.supplierId,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  BrandQuery copyWith({
    String? search,
    Object? country = _unset,
    Object? supplierId = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return BrandQuery(
      search: search ?? this.search,
      country: country == _unset ? this.country : country as String?,
      supplierId:
          supplierId == _unset ? this.supplierId : supplierId as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();
}
