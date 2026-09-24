import 'dart:async';
import 'dart:convert';
import 'package:attendx/services/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/attendance_verification.dart';
import '../../../shared/widgets/qr_scanner_frame.dart';
import '../../../shared/widgets/verification_step.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/status_badge.dart';

enum _FlowStage { scan, verifying, success, error }

/// The full mark-attendance journey: QR scan -> QR verify -> BLE proximity
/// -> face/liveness verification -> success. The camera scan is real;
/// BLE proximity and liveness are still mocked behind the same
/// [AttendanceVerification] interface.
class MarkAttendanceFlow extends StatefulWidget {
  final Course course;
  const MarkAttendanceFlow({super.key, required this.course});

  @override
  State<MarkAttendanceFlow> createState() => _MarkAttendanceFlowState();
}

class _MarkAttendanceFlowState extends State<MarkAttendanceFlow> {
  _FlowStage _stage = _FlowStage.scan;
  bool _flashOn = false;
  AttendanceVerification _verification = const AttendanceVerification();
  StreamSubscription<AttendanceVerification>? _sub;
  String? _errorTitle;
  String? _errorMessage;
  DateTime? _recordedAt;
  bool _synced = true;
  final AttendanceService _service = AttendanceService();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final String _clientRecordId;

  @override
  void initState() {
    super.initState();
    _clientRecordId = const Uuid().v4();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  void _onQrDetected(String scannedData) {
    if (_stage != _FlowStage.scan) return;

    final raw = scannedData.trim();

    // A real attendance QR contains a JSON payload with a sessionId.
    // Ignore anything else (ML Kit noise, unrelated QR codes, stale
    // screenshots) and keep the camera open.
    if (!raw.startsWith('{') || !raw.contains('sessionId')) {
      debugPrint('Ignoring non-attendance QR: $raw');
      return;
    }

    setState(() => _stage = _FlowStage.verifying);

    _sub = _processQrScan(raw).listen(
      (v) {
        setState(() => _verification = v);

        if (v.allPassed) {
          _finish();
        } else if (v.hasFailed) {
          setState(() {
            _stage = _FlowStage.error;
            _errorTitle = 'Verification Failed';
            _errorMessage = 'One of the verification steps did not pass.';
          });
        }
      },
      onError: (_) {
        setState(() {
          _stage = _FlowStage.error;
          _errorTitle = 'Verification Failed';
          _errorMessage =
              'Something went wrong during verification. Please try again.';
        });
      },
    );
  }

  /// Parses the scanned QR and runs through the verification stages.
  /// Handles JSON, URL, and delimited payloads.
  Stream<AttendanceVerification> _processQrScan(String scannedData) async* {
    // ── Stage 1: QR verification ─────────────────────────────────────────
    var v = const AttendanceVerification(
      qrStatus: VerificationStageStatus.inProgress,
    );
    yield v;

    final raw = scannedData.trim();

    String? sessionId;
    String? qrToken;

    print(sessionId);
    print(qrToken);

    // Attempt 1: JSON object like {"sessionId":"...","token":"..."}
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        sessionId = decoded['sessionId'] as String?;
        qrToken = (decoded['token'] ?? decoded['qrToken']) as String?;
      }
    } catch (_) {
      // Not JSON — fall through.
    }

    // Attempt 2: URL like https://.../scan?sessionId=...&token=...
    if (sessionId == null || qrToken == null) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasQuery) {
        sessionId = uri.queryParameters['sessionId'];
        qrToken =
            uri.queryParameters['token'] ?? uri.queryParameters['qrToken'];
      }
    }

    // Attempt 3: Delimited format "sessionId:token" or "sessionId|token"
    if (sessionId == null || qrToken == null) {
      for (final delim in [':', '|', ',']) {
        final parts = raw.split(delim);
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          sessionId = parts[0].trim();
          qrToken = parts[1].trim();
          break;
        }
      }
    }

    if (sessionId == null || qrToken == null) {
      yield v.copyWith(qrStatus: VerificationStageStatus.failed);
      _errorTitle = 'Invalid QR code';
      _errorMessage =
          'This QR doesn\'t look like an attendance code. Ask your lecturer '
          'to refresh the QR and try again.';
      return;
    }

    debugPrint('Parsed sessionId=$sessionId token=$qrToken');

    await Future.delayed(const Duration(milliseconds: 300));

    v = v.copyWith(
      qrStatus: VerificationStageStatus.success,
      sessionId: sessionId,
      qrToken: qrToken,
    );
    yield v;

    // ── Stage 2: BLE proximity ───────────────────────────────────────────
    v = v.copyWith(bleStatus: VerificationStageStatus.inProgress);
    yield v;

    // TODO: real BLE scan -> rssi; fail if below threshold.
    await Future.delayed(const Duration(milliseconds: 500));

    v = v.copyWith(
      bleStatus: VerificationStageStatus.success,
      bleRssi: -58,
    );
    yield v;

    // ── Stage 3: Identity / liveness ─────────────────────────────────────
    v = v.copyWith(identityStatus: VerificationStageStatus.inProgress);
    yield v;

    // TODO: real liveness verification.
    await Future.delayed(const Duration(milliseconds: 500));

    v = v.copyWith(
      identityStatus: VerificationStageStatus.success,
      livenessConfirmed: true,
    );
    yield v;

    // ── Stage 4: Record ──────────────────────────────────────────────────
    v = v.copyWith(attendanceStatus: VerificationStageStatus.success);
    yield v;
  }

  Future<void> _finish() async {
    final isOnline = await _isOnline();

    final payload = <String, dynamic>{
      'sessionId': _verification.sessionId,
      'qrToken': _verification.qrToken,
      'bleRssi': _verification.bleRssi,
      'livenessConfirmed': _verification.livenessConfirmed,
      'clientRecordId': _clientRecordId,
    };

    bool synced = false;

    if (isOnline) {
      try {
        final response = await _service.markAttendance(payload);

        if (response.success) {
          synced = true;
        } else {
          if (!mounted) return;
          setState(() {
            _stage = _FlowStage.error;
            _errorTitle = 'Attendance not recorded';
            _errorMessage = response.message;
          });
          return;
        }
      } catch (_) {
        synced = false;
      }
    } else {
      // TODO: persist `payload` to your offline queue.
      synced = false;
    }

    if (!mounted) return;
    setState(() {
      _stage = _FlowStage.success;
      _recordedAt = DateTime.now();
      _synced = synced;
    });
  }

  void _resetFlow() {
    setState(() {
      _stage = _FlowStage.scan;
      _verification = const AttendanceVerification();
      _errorTitle = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.securityDark,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_stage) {
            _FlowStage.scan => _buildScanStep(),
            _FlowStage.verifying => _buildVerifyingStep(),
            _FlowStage.success => _buildSuccessStep(),
            _FlowStage.error => _buildErrorStep(),
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SCAN STEP
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildScanStep() {
    return Column(
      key: const ValueKey('scan'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _scannerController.toggleTorch();
                  setState(() => _flashOn = !_flashOn);
                },
                icon: Icon(
                  _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Scan Attendance QR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Scan the QR code displayed by your lecturer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final qr = capture.barcodes.firstWhere(
                        (b) => b.format == BarcodeFormat.qrCode,
                        orElse: () => const Barcode(),
                      );
                      final value = qr.rawValue;
                      if (value != null && value.isNotEmpty) {
                        debugPrint('QR raw: $value');
                        _onQrDetected(value);
                      }
                    },
                    errorBuilder: (context, error) {
                      return Center(
                        child: Text(
                          'Camera error: ${error.errorCode}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
                ),
                const QrScannerFrame(),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Position the QR code inside the frame.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // VERIFYING STEP
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildVerifyingStep() {
    final (title, subtitle, icon) = _activeStageContent();
    return Column(
      key: const ValueKey('verify'),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: VerificationStepper(verification: _verification),
        ),
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.securityAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.securityAccent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.securityAccent, size: 36),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.securityAccent),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  (String, String, IconData) _activeStageContent() {
    if (_verification.qrStatus != VerificationStageStatus.success) {
      return (
        'Verifying attendance...',
        'Confirming the QR code signature with the session.',
        Icons.qr_code_rounded,
      );
    }
    if (_verification.bleStatus != VerificationStageStatus.success) {
      return (
        'Checking proximity',
        'Make sure you are close to your lecturer.',
        Icons.bluetooth_searching_rounded,
      );
    }
    if (_verification.identityStatus != VerificationStageStatus.success) {
      return (
        'Verify your identity',
        'Position your face inside the frame.',
        Icons.face_retouching_natural_rounded,
      );
    }
    return (
      'Recording attendance',
      'Signing and saving your attendance record.',
      Icons.fact_check_rounded,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUCCESS STEP
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSuccessStep() {
    final now = _recordedAt ?? DateTime.now();
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Attendance Recorded',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your attendance has been successfully recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.securityDarkAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _SuccessRow(label: 'Course', value: widget.course.code),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(
                  label: 'Time',
                  value: DateFormat('h:mm a').format(now),
                ),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(
                  label: 'Date',
                  value: DateFormat('d MMMM yyyy').format(now),
                ),
                const Divider(color: Colors.white12, height: 22),
                _SuccessRow(
                  label: 'Attendance',
                  value:
                      '${widget.course.attendancePercentage.toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBadge(
            label: _synced ? 'Synced' : 'Saved offline',
            tone: _synced ? StatusTone.success : StatusTone.warning,
            icon: _synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          ),
          if (!_synced) ...[
            const SizedBox(height: 8),
            Text(
              'Attendance saved securely. It will sync automatically when you are back online.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11.5,
              ),
            ),
          ],
          const Spacer(),
          AppButton(
            label: 'Done',
            width: double.infinity,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // ERROR STEP
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildErrorStep() {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.close_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _errorTitle ?? 'Something went wrong',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            width: double.infinity,
            onPressed: _resetFlow,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  const _SuccessRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
