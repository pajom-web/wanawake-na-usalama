class LiveLocationState {
  const LiveLocationState({
    required this.active,
    this.sessionId,
    this.sessionToken,
    this.lastError,
  });

  const LiveLocationState.idle() : this(active: false);

  final bool active;
  final int? sessionId;
  final String? sessionToken;
  final String? lastError;
}
