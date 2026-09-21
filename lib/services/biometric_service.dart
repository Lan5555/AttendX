import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check whether the device supports biometric authentication
  /// and has at least one biometric enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();

      if (!isSupported) {
        return false;
      }

      final biometrics = await _auth.getAvailableBiometrics();

      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Show the system biometric authentication prompt.
  Future<BiometricResult> captureBiometric({
    required String reason,
  }) async {
    try {
      final bool supported = await _auth.isDeviceSupported();

      if (!supported) {
        return BiometricResult(
          success: false,
          errorMessage: 'This device does not support biometric authentication.',
        );
      }

      final biometrics = await _auth.getAvailableBiometrics();

      if (biometrics.isEmpty) {
        return BiometricResult(
          success: false,
          errorMessage:
              'No biometric authentication is enrolled on this device.',
        );
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!didAuthenticate) {
        return BiometricResult(
          success: false,
          errorMessage:
              'Biometric authentication was cancelled or failed.',
        );
      }

      final biometricToken = _generateBiometricToken();

      return BiometricResult(
        success: true,
        biometricToken: biometricToken,
      );
    } on PlatformException catch (e) {
      return BiometricResult(
        success: false,
        errorMessage: e.message ?? 'Biometric authentication failed.',
      );
    }
  }

  String _generateBiometricToken() {
    final bytes = Uint8List.fromList(
      List<int>.generate(
        32,
        (i) => DateTime.now().microsecondsSinceEpoch % 256,
      ),
    );

    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class BiometricResult {
  final bool success;
  final String? biometricToken;
  final String? errorMessage;

  BiometricResult({
    required this.success,
    this.biometricToken,
    this.errorMessage,
  });
}