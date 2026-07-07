import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../../models/user_model.dart';
import '../../blocs/tien_len/tien_len_room_bloc.dart';
import '../../blocs/tien_len/tien_len_room_event.dart';
import '../../blocs/tien_len/tien_len_room_state.dart';
import '../../logic/tien_len_logic.dart';
import '../../models/bot_style.dart';
import '../../models/room_model.dart';
import '../../models/card_model.dart';
import '../../services/room_service.dart';

class TienLenRoomScreen extends StatelessWidget {
  final String roomId;
  final bool shouldResetOrientation;

  const TienLenRoomScreen({
    Key? key,
    required this.roomId,
    this.shouldResetOrientation = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TienLenRoomBloc(),
      child: _TienLenRoomView(
        roomId: roomId,
        shouldResetOrientation: shouldResetOrientation,
      ),
    );
  }
}

class _TienLenRoomView extends StatefulWidget {
  final String roomId;
  final bool shouldResetOrientation;

  const _TienLenRoomView({
    Key? key,
    required this.roomId,
    required this.shouldResetOrientation,
  }) : super(key: key);

  @override
  State<_TienLenRoomView> createState() => _TienLenRoomViewState();
}

class _TienLenRoomViewState extends State<_TienLenRoomView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RoomService _roomService = RoomService();
  bool _isLeaving = false;
  StreamSubscription? _roomSubscription;
  double _gameVolume = 1.0;
  double _voiceVolume = 1.0;
  String? _lastBotTurnKey; // Kết hợp turnId + turnStartedAt để bot không bị kẹt
  Timer? _botTimeoutTimer; // Timer để auto-pass nếu bot bị kẹt

  @override
  void initState() {
    super.initState();
    // Quay ngang màn hình khi vào phòng
    Future.microtask(() {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final userId = authState.user.uid;

      // Tự động Join vào danh sách players nếu chưa có (quan trọng cho lời mời)
      _roomService.joinRoom(widget.roomId, userId);

      _roomSubscription = _roomService.streamRoom(widget.roomId).listen((room) {
        if (mounted) {
          context.read<TienLenRoomBloc>().add(RoomUpdated(room, userId));
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ZegoUIKit().joinRoom(widget.roomId);
        ZegoUIKit().turnMicrophoneOn(false);
        ZegoUIKit().setAudioOutputToSpeaker(true);
      });
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _botTimeoutTimer?.cancel();
    _audioPlayer.dispose();
    ZegoUIKit().leaveRoom();

    // Chỉ quay lại màn hình dọc nếu được yêu cầu (thường là khi vào từ Invite)
    if (widget.shouldResetOrientation) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    // ]);
    super.dispose();
  }

  void _handleBotTurn(RoomModel room) async {
    try {
      final botUid = room.gameState!.currentTurnId;
      final botHand = room.gameState!.playerHands[botUid] ?? [];

      if (botHand.isEmpty) {
        // Bot đã hết bài, skip
        _roomService.passTurn(room.id, botUid);
        return;
      }

      // Bot phải nhìn ĐỐI THỦ NGUY HIỂM NHẤT (ít bài nhất) trong tất cả người
      // chơi khác đang còn bài, không chỉ người kế tiếp — để biết lúc nào cần
      // đè/khóa người sắp về dù họ ngồi ghế không kề bên.
      int nextOpponentCards = 13;
      final players = room.players;
      int minOpp = 9999;
      for (final p in players) {
        if (p == botUid) continue;
        final n = room.gameState!.playerHands[p]?.length ?? 0;
        if (n > 0 && n < minOpp) minOpp = n;
      }
      if (minOpp != 9999) nextOpponentCards = minOpp;

      // Đặt timeout safety — nếu 10 giây mà bot chưa đánh, tự pass
      _botTimeoutTimer?.cancel();
      _botTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          debugPrint("Bot timeout safety: auto-pass for $botUid");
          _roomService.passTurn(room.id, botUid);
        }
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      final bestMove = TienLenLogic.findBestMove(
        hand: botHand,
        lastPlayed: room.gameState!.lastPlayedCards,
        isNewRound: room.gameState!.lastPlayedCards.isEmpty,
        opponentCardsLeft: nextOpponentCards,
        playedCards: room.gameState!.allPlayedCards,
        style: BotStyle.balanced,
        mandatoryCard: room.gameState!.mandatoryOpeningCard,
      );

      // Huỷ timeout vì đã xử lý xong
      _botTimeoutTimer?.cancel();

      if (bestMove.isNotEmpty) {
        await _roomService.playCards(room.id, botUid, bestMove);
      } else {
        await _roomService.passTurn(room.id, botUid);
      }
    } catch (e) {
      debugPrint("Bot Error: $e");
      _botTimeoutTimer?.cancel();
      if (mounted) {
        final botUid = room.gameState?.currentTurnId;
        if (botUid != null) _roomService.passTurn(room.id, botUid);
      }
    }
  }

  void _playSound(String fileName) async {
    if (_gameVolume == 0) return;
    try {
      await _audioPlayer.play(
        AssetSource('sounds/$fileName'),
        volume: _gameVolume,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint("Audio Error ($fileName): $e");
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B4D3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.amberAccent),
              ),
              title: const Text(
                'CÀI ĐẶT ÂM THANH',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Game Volume
                    Row(
                      children: [
                        Icon(
                          _gameVolume > 0 ? Icons.music_note : Icons.music_off,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Âm thanh game:',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          '${(_gameVolume * 100).toInt()}%',
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ],
                    ),
                    Slider(
                      value: _gameVolume,
                      min: 0,
                      max: 1.0,
                      activeColor: Colors.amberAccent,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setStateSB(() {
                          _gameVolume = val;
                        });
                        setState(() {
                          _gameVolume = val;
                        });
                        _audioPlayer.setVolume(val);
                      },
                    ),
                    const SizedBox(height: 20),
                    // Voice Volume
                    Row(
                      children: [
                        Icon(
                          _voiceVolume > 0
                              ? Icons.record_voice_over
                              : Icons.voice_over_off,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Âm thanh voice chat:',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          '${(_voiceVolume * 100).toInt()}%',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ],
                    ),
                    Slider(
                      value: _voiceVolume,
                      min: 0,
                      max: 1.0,
                      activeColor: Colors.greenAccent,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setStateSB(() {
                          _voiceVolume = val;
                        });
                        setState(() {
                          _voiceVolume = val;
                        });
                        ZegoExpressEngine.instance.setAllPlayStreamVolume(
                          (val * 100).toInt(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ĐÓNG',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showKickedDialog({bool isDeleted = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162435),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isDeleted ? Colors.amberAccent : Colors.redAccent,
          ),
        ),
        title: Text(
          isDeleted ? 'Thông báo' : 'Thông báo',
          style: TextStyle(
            color: isDeleted ? Colors.amberAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isDeleted ? 'Phòng đã bị giải tán!' : 'Bạn đã bị đuổi ra khỏi phòng!',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Nếu đang ở trong phòng thì mới pop phòng, tránh pop nhầm Lobby
              if (!_isLeaving && mounted) {
                setState(() => _isLeaving = true);
                if (Navigator.canPop(context)) Navigator.pop(context);
              }
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return BlocListener<TienLenRoomBloc, TienLenRoomState>(
      listenWhen: (previous, current) =>
          previous.room != current.room ||
          previous.soundToPlay != current.soundToPlay ||
          (previous.secondsLeft != current.secondsLeft &&
              current.secondsLeft == 0) ||
          (previous.isKicked != current.isKicked && current.isKicked),
      listener: (context, state) {
        if (state.isKicked && !_isLeaving) {
          _showKickedDialog(isDeleted: state.room == null);
        }

        final room = state.room;
        if (state.soundToPlay != null) {
          if (state.soundToPlay == '5second.mp3') {
            if (room?.gameState?.currentTurnId == user.uid) {
              _playSound(state.soundToPlay!);
            }
          } else {
            _playSound(state.soundToPlay!);
          }
          context.read<TienLenRoomBloc>().add(const SoundPlayed());
        }

        // --- TIMEOUT AUTO-PLAY (Cho người chơi thật) ---
        if (state.secondsLeft == 0 &&
            room != null &&
            room.status == 'playing') {
          _audioPlayer.stop(); // Tắt nhạc đếm ngược 5 giây
        }
        if (state.secondsLeft == 0 &&
            room != null &&
            room.status == 'playing' &&
            room.gameState?.currentTurnId == user.uid) {
          final myHand = room.gameState!.playerHands[user.uid] ?? [];
          if (myHand.isNotEmpty) {
            final isOpenRound = room.gameState!.lastPlayedCards.isEmpty;

            if (isOpenRound) {
              // Vòng mới → đánh lá nhỏ nhất
              final mandatory = room.gameState!.mandatoryOpeningCard;
              if (room.gameState!.isFirstTurn && mandatory != null) {
                _roomService.playCards(widget.roomId, user.uid, [mandatory]);
              } else {
                List<CardModel> sortedHand = TienLenLogic.sortCards(myHand);
                _roomService.playCards(widget.roomId, user.uid, [
                  sortedHand.first,
                ]);
              }
            } else {
              // Đang trong vòng đánh → bỏ lượt
              _roomService.passTurn(widget.roomId, user.uid);
            }
          }
        }

        // --- TIMEOUT AUTO-PASS FOR BOT (Khi bot hết giờ mà chưa đánh) ---
        if (state.secondsLeft == 0 &&
            room != null &&
            room.status == 'playing' &&
            room.gameState?.currentTurnId != null &&
            room.gameState!.currentTurnId.startsWith('bot_') &&
            room.hostId == user.uid) {
          final botUid = room.gameState!.currentTurnId;
          debugPrint("Bot $botUid timeout — auto pass");
          final botHand = room.gameState!.playerHands[botUid] ?? [];
          if (room.gameState!.lastPlayedCards.isEmpty && botHand.isNotEmpty) {
            // Bot phải ra bài (Open Round) — đánh lá nhỏ nhất
            final mandatory = room.gameState!.mandatoryOpeningCard;
            if (room.gameState!.isFirstTurn && mandatory != null) {
              _roomService.playCards(widget.roomId, botUid, [mandatory]);
            } else {
              List<CardModel> sortedHand = TienLenLogic.sortCards(botHand);
              _roomService.playCards(widget.roomId, botUid, [sortedHand.first]);
            }
          } else {
            _roomService.passTurn(widget.roomId, botUid);
          }
        }

        // --- BOT AUTO-PLAY LOGIC (Chỉ Host mới điều khiển Máy) ---
        if (room != null &&
            room.status == 'playing' &&
            room.gameState?.currentTurnId != null &&
            room.gameState!.currentTurnId!.startsWith('bot_') &&
            room.hostId == user.uid) {
          // Dùng turnStartedAt thay vì lastPlayedCards.isEmpty để key luôn thay đổi khi lượt mới bắt đầu
          final turnKey =
              "${room.gameState!.currentTurnId}_${room.gameState!.turnStartedAt}";
          if (_lastBotTurnKey != turnKey) {
            _lastBotTurnKey = turnKey;
            _handleBotTurn(room);
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20), Color(0xFF0D2310)],
              radius: 1.5,
              center: Alignment.center,
            ),
          ),
          child: BlocBuilder<TienLenRoomBloc, TienLenRoomState>(
            builder: (context, state) {
              final room = state.room;
              if (room == null)
                return const Center(child: CircularProgressIndicator());

              return Stack(
                children: [
                  if (room.status == 'playing' || room.status == 'finished')
                    SafeArea(child: _buildGameTable(context, room, user, state))
                  else
                    SafeArea(child: _buildLobby(context, room, user)),

                  if (room.status == 'finished')
                    _buildGameOverOverlay(context, room, user),

                  if (state.effectText != null)
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, val, child) => Transform.scale(
                          scale: 1.0 + val * 0.8,
                          child: Opacity(
                            opacity: (1.0 - val).clamp(0, 1),
                            child: Text(
                              state.effectText!,
                              style: TextStyle(
                                color: state.effectColor,
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    blurRadius: 20,
                                    offset: const Offset(4, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLobby(BuildContext context, RoomModel room, UserModel user) {
    List<String?> seats = [null, null, null, null];
    for (int i = 0; i < room.players.length; i++) seats[i] = room.players[i];
    bool isHost = user.uid == room.hostId;
    bool isReady = room.readyPlayers.contains(user.uid);
    bool allReady = room.players.every(
      (p) => p == room.hostId || room.readyPlayers.contains(p),
    );

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PHÒNG CHỜ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.05),
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                  ),
                ),
                const SizedBox(height: 10),
                // Player Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: [
                      PlayerSeatWidget(
                        playerId: seats[0],
                        isHost: room.hostId == seats[0],
                        isMe: user.uid == seats[0],
                        isReady: room.readyPlayers.contains(seats[0]),
                        onKick:
                            (isHost && seats[0] != user.uid && seats[0] != null)
                            ? () => _roomService.kickPlayer(
                                widget.roomId,
                                user.uid,
                                seats[0]!,
                              )
                            : null,
                        onAdd: (isHost && seats[0] == null)
                            ? () => _showInviteDialog(context, user, room)
                            : null,
                      ),
                      PlayerSeatWidget(
                        playerId: seats[1],
                        isHost: room.hostId == seats[1],
                        isMe: user.uid == seats[1],
                        isReady: room.readyPlayers.contains(seats[1]),
                        onKick:
                            (isHost && seats[1] != user.uid && seats[1] != null)
                            ? () => _roomService.kickPlayer(
                                widget.roomId,
                                user.uid,
                                seats[1]!,
                              )
                            : null,
                        onAdd: (isHost && seats[1] == null)
                            ? () => _showInviteDialog(context, user, room)
                            : null,
                      ),
                      PlayerSeatWidget(
                        playerId: seats[2],
                        isHost: room.hostId == seats[2],
                        isMe: user.uid == seats[2],
                        isReady: room.readyPlayers.contains(seats[2]),
                        onKick:
                            (isHost && seats[2] != user.uid && seats[2] != null)
                            ? () => _roomService.kickPlayer(
                                widget.roomId,
                                user.uid,
                                seats[2]!,
                              )
                            : null,
                        onAdd: (isHost && seats[2] == null)
                            ? () => _showInviteDialog(context, user, room)
                            : null,
                      ),
                      PlayerSeatWidget(
                        playerId: seats[3],
                        isHost: room.hostId == seats[3],
                        isMe: user.uid == seats[3],
                        isReady: room.readyPlayers.contains(seats[3]),
                        onKick:
                            (isHost && seats[3] != user.uid && seats[3] != null)
                            ? () => _roomService.kickPlayer(
                                widget.roomId,
                                user.uid,
                                seats[3]!,
                              )
                            : null,
                        onAdd: (isHost && seats[3] == null)
                            ? () => _showInviteDialog(context, user, room)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildGlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.amberAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cược: ${room.betAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => "${m[1]}.")}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (isHost)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                onPressed: () => _showChangeBetDialog(
                                  context,
                                  room.betAmount,
                                ),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(left: 8),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    isHost
                        ? _buildActionBtn(
                            'BẮT ĐẦU GAME',
                            allReady && room.players.length >= 2
                                ? Colors.amberAccent
                                : Colors.grey.withOpacity(0.5),
                            allReady && room.players.length >= 2
                                ? () => _roomService.startGame(widget.roomId)
                                : null,
                          )
                        : _buildActionBtn(
                            isReady ? 'HUỶ SẴN SÀNG' : 'SẴN SÀNG!',
                            isReady ? Colors.redAccent : Colors.amberAccent,
                            () => _roomService.toggleReady(
                              widget.roomId,
                              user.uid,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        Positioned(
          top: 20,
          left: 20,
          child: Row(
            children: [
              _buildCircleAction(Icons.arrow_back, Colors.white10, () {
                setState(() => _isLeaving = true);
                _roomService.leaveRoom(widget.roomId, user.uid); // Don't await
                Navigator.pop(context);
              }),
              const SizedBox(width: 10),
              _buildCircleAction(
                Icons.settings,
                Colors.white10,
                _showSettingsDialog,
              ),
            ],
          ),
        ),

        Positioned(
          top: 20,
          right: 20,
          child: _buildGlassContainer(
            child: Row(
              children: [
                const Icon(
                  Icons.meeting_room,
                  color: Colors.amberAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'ID: ${room.id.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showChangeBetDialog(BuildContext context, int currentBet) {
    final controller = TextEditingController(text: currentBet.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B4D3E),
        title: const Text(
          'ĐỔI MỨC CƯỢC',
          style: TextStyle(color: Colors.amberAccent),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nhập mức cược mới...',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HUỶ', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final newBet = int.tryParse(controller.text);
              if (newBet != null && newBet > 0) {
                _roomService.updateBetAmount(widget.roomId, newBet);
                Navigator.pop(context);
              }
            },
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, UserModel user, RoomModel room) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B4D3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.amberAccent),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MỜI NGƯỜI CHƠI',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final error = await _roomService.addBot(room.id);
                      if (error != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                    icon: const Icon(Icons.android, size: 16),
                    label: const Text(
                      'THÊM MÁY',
                      style: TextStyle(fontSize: 10),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 350,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm tên người chơi...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.amberAccent,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .limit(20)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          final users = snapshot.data!.docs.where((doc) {
                            final name =
                                (doc.data()
                                        as Map<String, dynamic>)['displayName']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';
                            return name.contains(searchQuery.toLowerCase()) &&
                                doc.id != user.uid;
                          }).toList();

                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final userData =
                                  users[index].data() as Map<String, dynamic>;
                              final uid = users[index].id;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white10,
                                  child: Text(
                                    userData['displayName']?[0] ?? '?',
                                  ),
                                ),
                                title: Text(
                                  userData['displayName'] ?? 'Ẩn danh',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${userData['balance']} đ',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    _roomService.sendInvite(
                                      user.uid,
                                      user.displayName,
                                      uid,
                                      room.id,
                                      room.betAmount,
                                    );
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã gửi lời mời tới ${userData['displayName']}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('MỜI'),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionBtn(String text, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGameTable(
    BuildContext context,
    RoomModel room,
    UserModel user,
    TienLenRoomState state,
  ) {
    final gameState = room.gameState!;
    final myHand = gameState.playerHands[user.uid] ?? [];
    bool isMyTurn = gameState.currentTurnId == user.uid;

    return Stack(
      children: [
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(180),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF0D2310)],
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(170),
                border: Border.all(color: Colors.white10, width: 2),
              ),
            ),
          ),
        ),

        Positioned(top: 15, left: 20, child: _buildGlassInfo(room)),

        Positioned(
          top: 15,
          right: 20,
          child: Row(
            children: [
              _buildCircleAction(
                Icons.settings,
                Colors.white10,
                _showSettingsDialog,
              ),
              const SizedBox(width: 10),
              _buildCircleAction(
                Icons.logout,
                Colors.redAccent.withOpacity(0.5),
                () {
                  if (_isLeaving) return;
                  setState(() => _isLeaving = true);
                  _roomService.leaveRoom(widget.roomId, user.uid);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),

        ..._buildPlayerSeats(room, user, state),

        if (gameState.lastPlayedCards.isNotEmpty)
          Center(
            child: Wrap(
              spacing: -30,
              children: gameState.lastPlayedCards
                  .asMap()
                  .entries
                  .map(
                    (e) => Transform.rotate(
                      angle:
                          (e.key - (gameState.lastPlayedCards.length / 2)) *
                          0.1,
                      child: CardWidget(card: e.value, size: 45),
                    ),
                  )
                  .toList(),
            ),
          ),

        if (room.status == 'playing')
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (isMyTurn) _buildTurnActions(context, state, user.uid),
                const SizedBox(height: 10),
                _buildMyHand(context, myHand, state),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGameOverOverlay(
    BuildContext context,
    RoomModel room,
    UserModel user,
  ) {
    final payouts = room.gameState?.finalPayouts ?? {};
    final isHost = user.uid == room.hostId;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C3E50), Color(0xFF000000)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.amberAccent.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(0.1),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'KẾT THÚC VÁN ĐẤU',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 25),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: room.players.map((pid) {
                        final payout = payouts[pid] ?? 0;
                        final isWinner = payout > 0;
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(pid)
                              .get(),
                          builder: (context, snapshot) {
                            String name = '...';
                            if (pid.startsWith('bot_')) {
                              name = 'MÁY';
                            } else if (snapshot.hasData &&
                                snapshot.data!.data() != null) {
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              name = data['displayName'] ?? 'Người chơi';
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: isWinner
                                            ? Colors.amberAccent
                                            : Colors.grey,
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    payout >= 0 ? '+$payout' : '$payout',
                                    style: TextStyle(
                                      color: isWinner
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSmallAction(
                      'RỜI BÀN',
                      Colors.redAccent.withOpacity(0.2),
                      () {
                        setState(() => _isLeaving = true);
                        _roomService.leaveRoom(
                          widget.roomId,
                          user.uid,
                        ); // Don't await
                        Navigator.pop(context, widget.shouldResetOrientation);
                      },
                    ),
                    const SizedBox(width: 15),
                    if (isHost)
                      _buildActionBtn(
                        'CHƠI TIẾP',
                        Colors.amberAccent,
                        () => _roomService.playAgain(widget.roomId),
                      )
                    else
                      const Text(
                        'Chờ chủ phòng...',
                        style: TextStyle(
                          color: Colors.white38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInfo(RoomModel room) {
    return _buildGlassContainer(
      child: Row(
        children: [
          const Icon(
            Icons.table_restaurant,
            color: Colors.amberAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BÀN #${room.id.substring(room.id.length - 4).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Cược: ${room.betAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTurnActions(
    BuildContext context,
    TienLenRoomState state,
    String uid,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSmallAction(
          'Bỏ chọn',
          Colors.white24,
          () => context.read<TienLenRoomBloc>().add(const ClearSelection()),
        ),
        const SizedBox(width: 15),
        _buildSmallAction(
          'Bỏ lượt',
          const Color(0xFFC62828),
          () => context.read<TienLenRoomBloc>().add(
            PassTurnAction(widget.roomId, uid),
          ),
        ),
        const SizedBox(width: 15),
        _buildSmallAction(
          'Đánh bài',
          Colors.amberAccent,
          state.selectedCards.isEmpty
              ? null
              : () => context.read<TienLenRoomBloc>().add(
                  PlayCardsAction(widget.roomId, uid),
                ),
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildSmallAction(
    String text,
    Color color,
    VoidCallback? onTap, {
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.withOpacity(0.3) : color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: onTap == null ? Colors.white24 : textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMyHand(
    BuildContext context,
    List<CardModel> hand,
    TienLenRoomState state,
  ) {
    final sorted = TienLenLogic.sortCards(hand);
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: sorted.asMap().entries.map((e) {
          final isSelected = state.selectedCards.contains(e.value);
          final offset = (e.key - (sorted.length / 2)) * 30.0;
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: MediaQuery.of(context).size.width / 2 + offset - 32,
            bottom: isSelected ? 25 : 0,
            child: GestureDetector(
              onTap: () => context.read<TienLenRoomBloc>().add(
                ToggleCardSelection(e.value),
              ),
              child: Transform.rotate(
                angle: offset * 0.001,
                child: CardWidget(card: e.value, size: 65),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildPlayerSeats(
    RoomModel room,
    UserModel me,
    TienLenRoomState state,
  ) {
    List<String> players = room.players;
    int myIdx = players.indexOf(me.uid);
    List<Widget> seats = [];
    List<Alignment> alignments = [
      Alignment.bottomCenter,
      Alignment.centerRight,
      Alignment.topCenter,
      Alignment.centerLeft,
    ];

    for (int i = 0; i < players.length; i++) {
      int relativeIdx = (i - myIdx + players.length) % players.length;
      if (relativeIdx == 0) continue;

      final pid = players[i];
      final isTurn = room.gameState?.currentTurnId == pid;
      final cardCount = room.gameState?.playerHands[pid]?.length ?? 0;
      final chopEvent = room.gameState?.chopEvent;
      int? chopAmount;
      int? chopTimestamp;
      if (chopEvent != null &&
          (chopEvent['chopperId'] == pid || chopEvent['victimId'] == pid)) {
        chopAmount = chopEvent['chopperId'] == pid
            ? chopEvent['amount']
            : -chopEvent['amount'];
        chopTimestamp = chopEvent['timestamp'];
      }

      seats.add(
        Align(
          alignment: alignments[relativeIdx],
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: PlayerAvatarWidget(
              uid: pid,
              isActive: isTurn,
              secondsLeft: state.secondsLeft,
              chopAmount: chopAmount,
              chopTimestamp: chopTimestamp,
              cardCount: cardCount,
              balance: pid.startsWith('bot_') ? room.botBalances[pid] : null,
            ),
          ),
        ),
      );
    }
    final myCardCount = room.gameState?.playerHands[me.uid]?.length ?? 0;
    seats.add(
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: PlayerAvatarWidget(
            uid: me.uid,
            isActive: room.gameState?.currentTurnId == me.uid,
            secondsLeft: state.secondsLeft,
            isMe: true,
            cardCount: myCardCount,
          ),
        ),
      ),
    );

    return seats;
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCircleAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class PlayerAvatarWidget extends StatelessWidget {
  final String uid;
  final bool isActive;
  final int secondsLeft;
  final bool isMe;
  final int? chopAmount;
  final int? chopTimestamp;
  final int cardCount;

  const PlayerAvatarWidget({
    Key? key,
    required this.uid,
    required this.isActive,
    required this.secondsLeft,
    this.isMe = false,
    this.chopAmount,
    this.chopTimestamp,
    this.cardCount = 0,
    this.balance,
  }) : super(key: key);

  final dynamic balance;

  @override
  Widget build(BuildContext context) {
    if (uid.startsWith('bot_')) {
      return _buildAvatarUI('MÁY', balance ?? 100000000);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.data() == null) {
          return const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF37474F),
            child: Icon(Icons.person, color: Colors.white, size: 35),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildAvatarUI(
          data['displayName'] ?? 'Ẩn danh',
          data['balance'],
        );
      },
    );
  }

  Widget _buildAvatarUI(String name, dynamic balance) {
    bool isBot = uid.startsWith('bot_');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                builder: (context, val, child) => Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amberAccent.withOpacity(0.5 * (1 - val)),
                        blurRadius: 15 * val,
                        spreadRadius: 5 * val,
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.amberAccent : Colors.white24,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF37474F),
                child: isBot
                    ? const Icon(
                        Icons.android,
                        color: Colors.blueGrey,
                        size: 35,
                      )
                    : Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    '$secondsLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (cardCount > 0)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style,
                        color: Colors.blueAccent,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$cardCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildVoiceStatus(),
            if (chopAmount != null && chopTimestamp != null) _buildChopEffect(),
          ],
        ),
        const SizedBox(height: 8),
        _buildGlassLabel(name, balance ?? 0),
      ],
    );
  }

  Widget _buildVoiceStatus() {
    return Positioned(
      bottom: -5,
      right: -5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe) ...[
            ValueListenableBuilder<bool>(
              valueListenable: ZegoUIKit().getMicrophoneStateNotifier(uid),
              builder: (context, isMicOn, _) => GestureDetector(
                onTap: () => ZegoUIKit().turnMicrophoneOn(!isMicOn),
                child: _buildVoiceIcon(
                  isMicOn ? Icons.mic : Icons.mic_off,
                  isMicOn ? Colors.green : Colors.redAccent,
                ),
              ),
            ),
          ] else
            ValueListenableBuilder<bool>(
              valueListenable: ZegoUIKit().getMicrophoneStateNotifier(uid),
              builder: (context, isMicOn, _) => isMicOn
                  ? _buildVoiceIcon(Icons.mic, Colors.green)
                  : const SizedBox(),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.white, size: 12),
    );
  }

  Widget _buildGlassLabel(String name, dynamic balance) {
    String balanceStr = balance.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$balanceStr',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChopEffect() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(chopTimestamp),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -50 * value),
        child: Opacity(
          opacity: (1.0 - value).clamp(0, 1),
          child: Text(
            chopAmount! > 0 ? '+$chopAmount' : '$chopAmount',
            style: TextStyle(
              color: chopAmount! > 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerSeatWidget extends StatelessWidget {
  final String? playerId;
  final bool isHost;
  final bool isMe;
  final bool isReady;
  final VoidCallback? onKick;
  final VoidCallback? onAdd;

  const PlayerSeatWidget({
    Key? key,
    this.playerId,
    required this.isHost,
    required this.isMe,
    this.isReady = false,
    this.onKick,
    this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (playerId == null) {
      return InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  color: onAdd != null
                      ? Colors.amberAccent
                      : Colors.white.withOpacity(0.1),
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  'TRỐNG',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.1),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (playerId != null && playerId!.startsWith('bot_')) {
      return Container(
        alignment: Alignment.center,
        width: 130,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isReady ? Colors.greenAccent : Colors.white10,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.android, color: Colors.blueGrey, size: 50),
                const SizedBox(height: 12),
                const Text(
                  'MÁY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isReady)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'SẴN SÀNG',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (onKick != null)
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: onKick,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 120, height: 160);
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return Container(
          alignment: Alignment.center,
          width: 130,
          height: 170,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isReady
                  ? Colors.greenAccent
                  : Colors.white.withOpacity(0.1),
              width: isReady ? 2 : 1,
            ),
            boxShadow: [
              if (isReady)
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.2),
                  blurRadius: 15,
                ),
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFF455A64),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data['displayName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${data['balance'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isReady)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'SẴN SÀNG',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isHost)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                  if (onKick != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: onKick,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CardWidget extends StatelessWidget {
  final CardModel card;
  final double size;

  const CardWidget({Key? key, required this.card, this.size = 50})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    String suitIcon = '';
    Color color = Colors.black87;
    switch (card.suit) {
      case CardSuit.heart:
        suitIcon = '♥';
        color = const Color(0xFFD32F2F);
        break;
      case CardSuit.diamond:
        suitIcon = '♦';
        color = const Color(0xFFD32F2F);
        break;
      case CardSuit.club:
        suitIcon = '♣';
        break;
      case CardSuit.spade:
        suitIcon = '♠';
        break;
    }
    String rankStr = card.rank
        .toString()
        .split('.')
        .last
        .replaceAll('three', '3')
        .replaceAll('four', '4')
        .replaceAll('five', '5')
        .replaceAll('six', '6')
        .replaceAll('seven', '7')
        .replaceAll('eight', '8')
        .replaceAll('nine', '9')
        .replaceAll('ten', '10')
        .replaceAll('jack', 'J')
        .replaceAll('queen', 'Q')
        .replaceAll('king', 'K')
        .replaceAll('ace', 'A')
        .replaceAll('two', '2');

    return Container(
      width: size,
      height: size * 1.45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: Text(
              rankStr,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
                height: 1,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Text(
              suitIcon,
              style: TextStyle(color: color, fontSize: size * 0.22),
            ),
          ),
          Center(
            child: Text(
              suitIcon,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: size * 0.6,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Transform.rotate(
              angle: 3.1415,
              child: Text(
                rankStr,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.28,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
