const maximumProfileImageRevision = 2147483647;

int? validatedProfileImageRevision(Object? value) => value == null
    ? 0
    : value is int && value >= 0 && value <= maximumProfileImageRevision
    ? value
    : null;

int readProfileImageRevision(Object? value) =>
    validatedProfileImageRevision(value) ?? 0;
