enum ImportDecision { allow, warn, reject }

class ImportPolicyResult {
  const ImportPolicyResult({
    required this.decision,
    required this.message,
  });

  final ImportDecision decision;
  final String message;

  bool get canImport => decision != ImportDecision.reject;
}

class ImportPolicy {
  static const recommendedMaxBytes = 1024 * 1024;
  static const hardMaxBytes = 20 * 1024 * 1024;

  const ImportPolicy();

  ImportPolicyResult evaluate(int fileSizeBytes) {
    if (fileSizeBytes <= recommendedMaxBytes) {
      return const ImportPolicyResult(
        decision: ImportDecision.allow,
        message: '推奨サイズ内です。',
      );
    }
    if (fileSizeBytes <= hardMaxBytes) {
      return const ImportPolicyResult(
        decision: ImportDecision.warn,
        message: '1MBを超えています。同期に時間がかかる可能性があります。',
      );
    }
    return const ImportPolicyResult(
      decision: ImportDecision.reject,
      message: '20MBを超えるPDFはMVPでは取り込めません。',
    );
  }
}
