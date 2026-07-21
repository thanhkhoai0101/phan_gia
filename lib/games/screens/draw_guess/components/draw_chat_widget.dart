import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/draw_guess/draw_room_bloc.dart';
import '../../../blocs/draw_guess/draw_room_state_event.dart';

class DrawChatWidget extends StatefulWidget {
  final bool isDrawer;

  const DrawChatWidget({super.key, required this.isDrawer});

  @override
  State<DrawChatWidget> createState() => _DrawChatWidgetState();
}

class _DrawChatWidgetState extends State<DrawChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<DrawRoomBloc>().add(SubmitGuessEvent(text));
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawRoomBloc, DrawRoomState>(
      builder: (context, state) {
        final messages = state.messages;

        return Container(
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF200A38),
            border: Border(top: BorderSide(color: Color(0xFF4A148C), width: 1)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFF2D0D4E),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.purple, size: 16),
                    const SizedBox(width: 6),
                    const Text('Chat & Đoán', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (widget.isDrawer) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Bạn đang vẽ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];

                    if (msg.isSystemMsg) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(msg.text, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ),
                        ),
                      );
                    }

                    if (msg.isCorrectGuess) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('✅ ${msg.senderName} ${msg.text}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${msg.senderName}: ',
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: msg.text,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Input
              if (!widget.isDrawer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF4A148C))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          cursorColor: Colors.purple,
                          decoration: InputDecoration(
                            hintText: 'Nhập câu trả lời...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFF3D1668),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _submit,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
