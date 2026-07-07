import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/report_submission_status.dart';

final reportSubmissionStatusProvider = StateProvider<ReportSubmissionStatus>(
  (_) => const ReportSubmissionStatus.idle(),
);
