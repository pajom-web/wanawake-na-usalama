enum ReportDeliveryState { idle, sending, received, failed }

class ReportSubmissionStatus {
  const ReportSubmissionStatus._({
    required this.state,
    this.reportId,
    this.message,
    this.updatedAt,
  });

  const ReportSubmissionStatus.idle() : this._(state: ReportDeliveryState.idle);

  factory ReportSubmissionStatus.sending() {
    return ReportSubmissionStatus._(
      state: ReportDeliveryState.sending,
      updatedAt: DateTime.now(),
    );
  }

  factory ReportSubmissionStatus.received({String? reportId}) {
    return ReportSubmissionStatus._(
      state: ReportDeliveryState.received,
      reportId: reportId,
      updatedAt: DateTime.now(),
    );
  }

  factory ReportSubmissionStatus.failed(String message) {
    return ReportSubmissionStatus._(
      state: ReportDeliveryState.failed,
      message: message,
      updatedAt: DateTime.now(),
    );
  }

  final ReportDeliveryState state;
  final String? reportId;
  final String? message;
  final DateTime? updatedAt;
}
