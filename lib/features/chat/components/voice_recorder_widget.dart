import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(File file, int durationInSeconds) onStopAndSend;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    Key? key,
    required this.onStopAndSend,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late AudioRecorder _recorder;
  bool _isRecording = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  String? _filePath;
  DateTime? _startTime;

  // Sound wave bar heights for animation
  final List<double> _waveHeights = List.generate(8, (_) => 10.0);
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _filePath!,
        );

        _startTime = DateTime.now();

        setState(() {
          _isRecording = true;
          _secondsElapsed = 0;
        });

        // Start Timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsElapsed++;
          });
        });

        // Start wave animation
        _waveTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
          if (mounted) {
            setState(() {
              for (int i = 0; i < _waveHeights.length; i++) {
                // Random height for wave effect
                _waveHeights[i] = 10.0 + (5.0 + (i % 3 == 0 ? 15.0 : 8.0)) * (0.5 + (0.5 * (i % 2 == 0 ? 1 : 0.5)));
                // Mix in random factor
                _waveHeights[i] = _waveHeights[i].clamp(10.0, 45.0);
              }
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền truy cập Micro để ghi âm'), backgroundColor: Colors.orangeAccent),
        );
        widget.onCancel();
      }
    } catch (e) {
      print('Error starting voice recorder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khởi động ghi âm: $e'), backgroundColor: Colors.redAccent),
      );
      widget.onCancel();
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _waveTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null && _filePath != null) {
        final duration = _startTime != null
            ? DateTime.now().difference(_startTime!).inSeconds
            : _secondsElapsed;
        
        widget.onStopAndSend(File(_filePath!), duration > 0 ? duration : 1);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _waveTimer?.cancel();

    try {
      await _recorder.stop();
      if (_filePath != null) {
        final file = File(_filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }

    widget.onCancel();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Blinking dot + Timer
          Row(
            children: [
              _BlinkingDot(),
              const SizedBox(width: 8),
              Text(
                _formatTime(_secondsElapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Animated Waveform
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _waveHeights.map((height) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3.5,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 20),

          // Trash / Cancel Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 24),
            onPressed: _cancelRecording,
          ),

          // Send Button
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blueAccent,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _stopAndSend,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
