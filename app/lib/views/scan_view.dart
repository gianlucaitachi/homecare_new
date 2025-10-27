import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../repository/task_repository.dart';
import '../services/qr_service.dart';

class ScanView extends StatefulWidget {
  const ScanView({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _hasPermission = false;
  bool _permissionDenied = false;
  bool _isProcessing = false;
  Timer? _restartTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restartTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed && !_isProcessing && _hasPermission) {
      unawaited(_controller.start());
    }
  }

  void _onPermissionSet(MobileScannerController controller, bool granted) {
    if (!mounted) {
      return;
    }

    setState(() {
      _hasPermission = granted;
      _permissionDenied = !granted;
    });

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes.'),
        ),
      );
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || _isProcessing) {
      return;
    }

    Barcode? selected;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        selected = barcode;
        break;
      }
    }

    final value = selected?.rawValue?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    final qrService = context.read<QrService>();
    late QrPayload payload;
    try {
      payload = qrService.parse(value);
    } on FormatException catch (error) {
      _showError(error.message);
      _temporarilyPauseScanning();
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    await _controller.stop();

    await _completeTask(payload);
  }

  Future<void> _completeTask(QrPayload payload) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = context.read<TaskRepository>();
      await repository.completeByQr(
        id: payload.taskId,
        code: payload.qrCode,
      );

      if (!mounted) {
        return;
      }

      await _playSuccessFeedback();

      final task = repository.findCachedTask(payload.taskId);
      final taskTitle = task?.title;
      final message = taskTitle != null && taskTitle.isNotEmpty
          ? 'Marked "$taskTitle" as complete.'
          : 'Task completed successfully.';
      messenger.showSnackBar(SnackBar(content: Text(message)));

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showError(error.message);
      _resumeScanning();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final message = _messageFromDio(error) ??
          'Failed to complete the task. Please try again.';
      _showError(message);
      _resumeScanning();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('Failed to complete the task. Please try again.');
      _resumeScanning();
    }
  }

  void _temporarilyPauseScanning() {
    setState(() {
      _isProcessing = true;
    });
    unawaited(_controller.stop());
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 1), _resumeScanning);
  }

  void _resumeScanning() {
    if (!mounted) {
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = null;

    setState(() {
      _isProcessing = false;
    });

    if (_hasPermission) {
      unawaited(_controller.start());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _messageFromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      final message = map['message'] ?? map['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  Future<void> _playSuccessFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Widget _buildScanner() {
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Camera access is disabled. Enable permissions in system settings to scan QR codes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _permissionDenied = false;
                  });
                  unawaited(_controller.start());
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onPermissionSet: _onPermissionSet,
          onDetect: _onDetect,
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: Text(
            _isProcessing ? 'Processing scan...' : 'Align the QR code within the frame to complete a task.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          const ColoredBox(
            color: Color(0x88000000),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildScanner()),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Ensure the entire QR code is visible in the frame.'),
                const Text('• Keep the device steady while scanning.'),
                const Text('• A confirmation will appear when the task is completed.'),
                const SizedBox(height: 12),
                Text(
                  'Connected to: ${widget.baseUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (Scaffold.maybeOf(context) != null) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Task QR'),
      ),
      body: content,
    );
  }
}
