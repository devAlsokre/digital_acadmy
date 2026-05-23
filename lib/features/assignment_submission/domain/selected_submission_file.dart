class SelectedSubmissionFile {
  const SelectedSubmissionFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.extension,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final String? extension;

  String get displaySize {
    final double sizeInMb = sizeBytes / (1024 * 1024);

    if (sizeInMb >= 1) {
      return '${sizeInMb.toStringAsFixed(1)} MB';
    }

    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}
