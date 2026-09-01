import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// Furrow's one failure state for a screen whose data did not load: the
/// fleet's [OhErrorState] (a plain sentence, Try again, the exception only
/// behind Details), with the exception logged rather than printed on screen.
Widget loadFailure(
  Object error,
  StackTrace? stackTrace, {
  required String title,
  VoidCallback? onRetry,
}) {
  debugPrint('Furrow: $title: $error');
  return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(OhSpacing.md),
      child: OhErrorState.fromError(
        error,
        stackTrace: stackTrace,
        title: title,
        onRetry: onRetry,
        icon: Icons.error_outline,
      ),
    ),
  );
}
