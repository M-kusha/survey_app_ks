const maximumProfileImageRevision = 2147483647;

int readProfileImageRevision(Object? value) =>
    value is int && value >= 0 && value <= maximumProfileImageRevision
    ? value
    : 0;
