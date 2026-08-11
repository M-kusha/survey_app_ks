const maximumProfileImageRevision = 2147483647;

/// Returns zero for a new profile, a validated existing revision, or null when
/// stored state is malformed and therefore unsafe for an optimistic update.
int? validatedProfileImageRevision(Object? value) => value == null
    ? 0
    : value is int && value >= 0 && value <= maximumProfileImageRevision
    ? value
    : null;

int readProfileImageRevision(Object? value) =>
    validatedProfileImageRevision(value) ?? 0;
