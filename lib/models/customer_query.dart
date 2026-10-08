class CustomerQuery {
  final String search;
  final String? cardLevel;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const CustomerQuery({
    this.search = '',
    this.cardLevel,
    this.sortField = 'fullName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  CustomerQuery copyWith({
    String? search,
    Object? cardLevel = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return CustomerQuery(
      search: search ?? this.search,
      cardLevel: cardLevel == _unset ? this.cardLevel : cardLevel as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();
}
