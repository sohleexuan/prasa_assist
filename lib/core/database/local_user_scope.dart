class LocalUserScope {
  LocalUserScope(String authenticatedUserId)
    : ownerUserId = authenticatedUserId.trim() {
    if (!_uuidPattern.hasMatch(ownerUserId)) {
      throw ArgumentError.value(
        authenticatedUserId,
        'authenticatedUserId',
        'must be a non-blank Supabase user UUID',
      );
    }
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final String ownerUserId;

  @override
  bool operator ==(Object other) {
    return other is LocalUserScope && other.ownerUserId == ownerUserId;
  }

  @override
  int get hashCode => ownerUserId.hashCode;
}
