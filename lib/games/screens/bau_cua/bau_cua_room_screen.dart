import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../blocs/bau_cua/bau_cua_bloc.dart';
import '../../blocs/bau_cua/bau_cua_event.dart';
import '../../blocs/bau_cua/bau_cua_state.dart';
import '../../models/bau_cua_model.dart';
import '../../services/bau_cua_service.dart';
import '../../widgets/bau_cua_mascot_card.dart';

class BauCuaRoomScreen extends StatefulWidget {
  final String roomId;
  const BauCuaRoomScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<BauCuaRoomScreen> createState() => _BauCuaRoomScreenState();
}

class _BauCuaRoomScreenState extends State<BauCuaRoomScreen> with SingleTickerProviderStateMixin {
  late BauCuaBloc _bloc;
  late AnimationController _shakeController;
  int _selectedChip = 1000;
  final List<int> _chips = [1000, 5000, 10000, 50000, 100000];

  final List<String> _mascotNames = ['NAI', 'BẦU', 'GÀ', 'TÔM', 'CUA', 'CÁ'];
  final List<Color> _mascotColors = [Colors.orange, Colors.blue, Colors.red, Colors.green, Colors.purple, Colors.cyan];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
    _bloc = BauCuaBloc(service: BauCuaService());
    _bloc.add(LoadRoom(widget.roomId));
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _shakeController.reverse();
        else if (status == AnimationStatus.dismissed) _shakeController.forward();
      });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _shakeController.dispose();
    BauCuaService().leaveRoom(widget.roomId);
    _bloc.close();
    super.dispose();
  }

  void _startShaking() => _shakeController.forward();
  void _stopShaking() => _shakeController.stop();

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1541450805268-4822a3a774ca?auto=format&fit=crop&q=80&w=2070'),
              fit: BoxFit.cover,
              opacity: 0.2,
            ),
            color: Color(0xFF0F1B2A),
          ),
          child: BlocConsumer<BauCuaBloc, BauCuaState>(
            listener: (context, state) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.redAccent));
              }
              if (state.room?.status == 'rolling') {
                _startShaking();
              } else {
                _stopShaking();
              }
            },
            builder: (context, state) {
              if (state.isLoading || state.room == null) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }
              final room = state.room!;
              final userState = context.read<AuthBloc>().state;
              if (userState is! AuthAuthenticated) return const SizedBox();
              final currentUser = userState.user;

              return SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, room, currentUser.balance),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                bool isLandscape = constraints.maxWidth > constraints.maxHeight;
                                return Column(
                                  children: [
                                    Expanded(
                                      child: isLandscape
                                        ? Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const SizedBox(height: 10),
                                                      _buildDiceArea(room),
                                                      const SizedBox(height: 10),
                                                      _buildStatusBadge(room),
                                                      if (room.status == 'waiting' && room.hostUid == BauCuaService().currentUser?.uid && !room.isAuto)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 10),
                                                          child: _buildHostStartButton(room),
                                                        ),
                                                      const SizedBox(height: 10),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  children: [
                                                    const SizedBox(height: 10),
                                                    Expanded(child: _buildBettingGrid(room, currentUser.uid, currentUser.displayName, isLandscape)),
                                                    _buildChipSelector(currentUser.balance),
                                                    const SizedBox(height: 10),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    children: [
                                                      const SizedBox(height: 10),
                                                      _buildDiceArea(room),
                                                      const SizedBox(height: 10),
                                                      _buildStatusBadge(room),
                                                      if (room.status == 'waiting' && room.hostUid == BauCuaService().currentUser?.uid && !room.isAuto)
                                                        _buildHostStartButton(room),
                                                      const SizedBox(height: 20),
                                                      _buildBettingGrid(room, currentUser.uid, currentUser.displayName, false),
                                                      const SizedBox(height: 20),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              _buildChipSelector(currentUser.balance),
                                              const SizedBox(height: 20),
                                            ],
                                          ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (room.status == 'result')
                            Center(
                              child: _buildWinLossAnimation(room, currentUser.uid),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, BauCuaRoom room, num balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text('PHAN GIA - BẦU CUA',
                style: TextStyle(
                  color: Colors.amberAccent.withOpacity(0.9),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2.0,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)]
                )
              ),
              const SizedBox(height: 2),
              Text('Phòng #${room.id.substring(0, 4).toUpperCase()}',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(balance >= 1000000 ? '${(balance / 1000000).toStringAsFixed(1)}M' : balance.toString(),
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceArea(BauCuaRoom room) {
    bool isLifted = room.status == 'result' || room.status == 'waiting';

    return LayoutBuilder(
      builder: (context, constraints) {
        double shakerSize = MediaQuery.of(context).size.height * 0.35;
        if (shakerSize > 160) shakerSize = 160;
        if (shakerSize < 100) shakerSize = 100;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Plate (Dĩa) - More realistic wood/gold plate
            Container(
              width: shakerSize,
              height: shakerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD6A86A), // Golden wood color
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                gradient: RadialGradient(
                  colors: [const Color(0xFFD6A86A), Colors.brown.shade700],
                ),
              ),
            ),

            // Dice
            if (isLifted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: room.resultDice.map((index) => _buildDie(index)).toList(),
              ),

            // sửa thành cái bát cho đẹp
            // Bowl (Tô)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              top: isLifted ? -shakerSize : (shakerSize * 0.1),
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  double shakeX = room.status == 'rolling' ? (_shakeController.value * 12 - 6) : 0;
                  return Transform.translate(
                    offset: Offset(shakeX, 0),
                    child: Container(
                      width: shakerSize * 0.85,
                      height: shakerSize * 0.65,
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(shakerSize * 0.4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.red.shade400, Colors.red.shade900],
                        ),
                      ),
                    )
                  );
                },
              ),
            ),

            // Nút Soi Cầu
            Positioned(
              bottom: 10,
              child: GestureDetector(
                onTap: () => _showHistoryDialog(context, room.history),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: const Text('SOI CẦU', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  void _showHistoryDialog(BuildContext context, List<List<int>> history) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('LỊCH SỬ (20 VÁN GẦN NHẤT)', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: history.isEmpty 
              ? const Center(child: Text('Chưa có lịch sử', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final results = history[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Ván ${history.length - index}: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 10),
                          ...results.map((d) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildHistoryDie(d, size: 30),
                          )).toList(),
                        ],
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ĐÓNG', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHostStartButton(BauCuaRoom room) {
    String btnText = room.history.isEmpty ? 'BẮT ĐẦU XÓC' : 'CHƠI TIẾP';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ElevatedButton(
        onPressed: () => _bloc.add(StartRound()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 8,
        ),
        child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildStatusBadge(BauCuaRoom room) {
    String text = '';
    Color color = Colors.amberAccent;
    final isHost = room.hostUid == BauCuaService().currentUser?.uid;

    switch (room.status) {
      case 'waiting':
        text = isHost && !room.isAuto ? 'NHẤN BẮT ĐẦU ĐỂ XÓC' : 'ĐỢI NHÀ CÁI...';
        color = Colors.blueAccent;
        break;
      case 'preparing':
        text = 'CHUẨN BỊ VÁN MỚI: ${room.timerSeconds}s';
        color = Colors.lightBlueAccent;
        break;
      case 'betting':
        text = 'ĐẶT CƯỢC: ${room.timerSeconds}s';
        color = Colors.greenAccent;
        break;
      case 'rolling':
        text = 'ĐANG XÓC...';
        color = Colors.orangeAccent;
        break;
      case 'result':
        text = 'KẾT QUẢ${room.timerSeconds > 0 ? ' (${room.timerSeconds}s)' : ''}';
        color = Colors.amberAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
    );
  }

  Widget _buildDie(int index) {
    return Container(
      width: 55,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          // Bottom-right shadow for 3D depth
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(3, 3)),
          // Top-left highlight for 3D depth
          BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 2, offset: const Offset(-1, -1)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade100],
        ),
      ),
      child: Stack(
        children: [
          // Subtle side shading to simulate a cube
          Positioned(
            right: 0, bottom: 0, top: 0,
            child: Container(width: 4, color: Colors.grey.withOpacity(0.1)),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(height: 4, color: Colors.grey.withOpacity(0.1)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildMascotImageInDie(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotImageInDie(int index) {
    String name;
    switch (index) {
      case 0: name = 'nai'; break;
      case 1: name = 'bau'; break;
      case 2: name = 'ga'; break;
      case 3: name = 'tom'; break;
      case 4: name = 'cua'; break;
      case 5: name = 'ca'; break;
      default: name = 'nai';
    }
    final String assetPath = 'assets/images/baucua/${name}_pro.png';

    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        color: _mascotColors[index].withOpacity(0.2),
        child: Center(child: Icon(_getMascotIcon(index), color: _mascotColors[index], size: 16)),
      ),
    );
  }

  IconData _getMascotIcon(int index) {
    switch (index) {
      case 0: return Icons.eco;
      case 1: return Icons.wine_bar; // Bầu
      case 2: return Icons.egg;
      case 3: return Icons.bug_report;
      case 4: return Icons.vaping_rooms;
      case 5: return Icons.tsunami;
      default: return Icons.help_outline;
    }
  }

  Widget _buildBettingGrid(BauCuaRoom room, String currentUid, String currentName, bool isLandscape) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: isLandscape ? null : const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: isLandscape ? 1.1 : 0.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          int totalOnMascot = room.currentBets.where((b) => b.mascotIndex == index).fold(0, (sum, b) => sum + b.amount);
          int myOnMascot = room.currentBets.where((b) => b.userId == currentUid && b.mascotIndex == index).fold(0, (sum, b) => sum + b.amount);
          return BauCuaMascotCard(
            index: index,
            name: _mascotNames[index],
            totalBet: totalOnMascot,
            myBet: myOnMascot,
            canBet: room.status == 'betting',
            onTap: () => _bloc.add(PlaceBetEvent(index, _selectedChip, currentName)),
            mascotColor: _mascotColors[index],
          );
        },
      ),
    );
  }

  Widget _buildChipSelector(num balance) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _chips.map((chip) => _buildChip(chip, balance)).toList(),
      ),
    );
  }

  Widget _buildChip(int value, num balance) {
    bool isSelected = _selectedChip == value;
    bool isDisabled = balance < value;
    return GestureDetector(
      onTap: isDisabled ? null : () => setState(() => _selectedChip = value),
      child: Opacity(
        opacity: isDisabled ? 0.3 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isSelected ? Colors.amberAccent : Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.4), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(
              value >= 1000 ? '${value ~/ 1000}k' : value.toString(),
              style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDie(int index, {double size = 14}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.1),
        child: _buildMascotImageInDie(index),
      ),
    );
  }

  Widget _buildWinLossAnimation(BauCuaRoom room, String currentUid) {
    int myTotalBet = 0;
    int myWinAmount = 0;

    for (var bet in room.currentBets.where((b) => b.userId == currentUid)) {
      myTotalBet += bet.amount;
      int matchCount = room.resultDice.where((d) => d == bet.mascotIndex).length;
      if (matchCount > 0) {
        myWinAmount += bet.amount + (matchCount * bet.amount);
      }
    }

    if (myTotalBet == 0) return const SizedBox();

    int netProfit = myWinAmount - myTotalBet;

    String text;
    Color color;
    if (netProfit > 0) {
      text = '+${netProfit >= 1000 ? '${netProfit ~/ 1000}k' : netProfit}';
      color = Colors.greenAccent;
    } else if (netProfit < 0) {
      text = '${netProfit >= 1000 || netProfit <= -1000 ? '${netProfit ~/ 1000}k' : netProfit}';
      color = Colors.redAccent;
    } else {
      text = 'HÒA';
      color = Colors.white;
    }

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('winloss_${room.lastRollAt?.millisecondsSinceEpoch}'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      netProfit > 0 ? 'THẮNG LỚN' : (netProfit < 0 ? 'THUA RỒI' : 'HUỀ VỐN'),
                      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text,
                      style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, shadows: const [
                        Shadow(color: Colors.black, blurRadius: 10)
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
