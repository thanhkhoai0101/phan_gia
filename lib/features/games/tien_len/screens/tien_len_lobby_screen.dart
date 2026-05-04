import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/bloc/auth_state.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import 'tien_len_room_screen.dart';

class TienLenLobbyScreen extends StatefulWidget {
  const TienLenLobbyScreen({Key? key}) : super(key: key);

  @override
  State<TienLenLobbyScreen> createState() => _TienLenLobbyScreenState();
}

class _TienLenLobbyScreenState extends State<TienLenLobbyScreen> {
  final RoomService _roomService = RoomService();
  final TextEditingController _roomIdController = TextEditingController();
  String _selectedFilter = 'TẤT CẢ';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _roomIdController.dispose();
    super.dispose();
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _showActivePlayers(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 450,
            height: 600,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4D3E),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.amberAccent, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'NGƯỜI CHƠI ĐANG ĐẤU',
                          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: const Text(
                              'TẮT',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('rooms').where('status', isEqualTo: 'playing').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                      }
                      
                      List<Map<String, dynamic>> activeEntries = [];
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final roomId = doc.id;
                          final players = data['players'] as List<dynamic>? ?? [];
                          final playerCount = players.length;
                          
                          for (var p in players) {
                            String uid = (p is Map) ? p['uid'] : p.toString();
                            if (uid.startsWith('bot_')) continue;
                            activeEntries.add({
                              'uid': uid,
                              'roomId': roomId,
                              'playerCount': playerCount,
                            });
                          }
                        }
                      }

                      if (activeEntries.isEmpty) {
                        return const Center(child: Text('Không có ai đang chơi', style: TextStyle(color: Colors.white54)));
                      }

                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: activeEntries.map((e) => e['uid']).toSet().toList().take(10).toList()).get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) return const SizedBox();
                          final userDocs = { for (var doc in userSnapshot.data!.docs) doc.id : doc.data() as Map<String, dynamic> };
                          
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: activeEntries.length,
                            itemBuilder: (context, index) {
                              final entry = activeEntries[index];
                              final userData = userDocs[entry['uid']];
                              final name = userData?['displayName'] ?? 'Ẩn danh';
                              final shortRoomId = entry['roomId'].toString().substring(entry['roomId'].toString().length - 4).toUpperCase();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.amberAccent.withOpacity(0.2),
                                      child: const Icon(Icons.person, size: 16, color: Colors.amberAccent),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          Text('Phòng #$shortRoomId • ${entry['playerCount']}/4', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.login, color: Colors.greenAccent, size: 24),
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => TienLenRoomScreen(roomId: entry['roomId'], shouldResetOrientation: false))).then((_) => _setLandscape());
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeaderboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 450,
            height: 600,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4D3E),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.amberAccent, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'BẢNG XẾP HẠNG',
                          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: const Text(
                              'TẮT',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('users').orderBy('balance', descending: true).limit(20).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.white54)));
                      }

                      final users = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final data = users[index].data() as Map<String, dynamic>;
                          final name = data['displayName'] ?? 'Ẩn danh';
                          final balance = data['balance'] ?? 0;
                          final balanceStr = balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => "${m[1]}.");

                          Widget rankWidget;
                          if (index == 0) {
                            rankWidget = _buildRankBadge(Icons.stars, Colors.amber);
                          } else if (index == 1) {
                            rankWidget = _buildRankBadge(Icons.stars, const Color(0xFFC0C0C0));
                          } else if (index == 2) {
                            rankWidget = _buildRankBadge(Icons.stars, const Color(0xFFCD7F32));
                          } else {
                            rankWidget = SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: index < 3 ? Colors.amberAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                rankWidget,
                                const SizedBox(width: 16),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  balanceStr,
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _createRoom(BuildContext parentContext, String uid, int userBalance) {
    String selectedRule = 'per_card';
    int selectedBet = 10000;
    final List<int> betLevels = [10000, 20000, 50000, 100000, 200000];
    final TextEditingController customBetController = TextEditingController();
    bool isCustomBet = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B4D3E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amberAccent)),
              title: const Text('THIẾT LẬP PHÒNG', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Luật chơi:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    RadioListTile<String>(
                      title: const Text('Tính theo lá', style: TextStyle(color: Colors.white, fontSize: 14)),
                      activeColor: Colors.amberAccent,
                      value: 'per_card',
                      groupValue: selectedRule,
                      onChanged: (val) => setState(() => selectedRule = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Cúng bài', style: TextStyle(color: Colors.white, fontSize: 14)),
                      activeColor: Colors.amberAccent,
                      value: 'sacrifice',
                      groupValue: selectedRule,
                      onChanged: (val) => setState(() => selectedRule = val!),
                    ),
                    const Divider(color: Colors.white10),
                    const Text('Tiền cược:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: betLevels.map((amount) {
                        bool isSelected = !isCustomBet && selectedBet == amount;
                        return ChoiceChip(
                          label: Text('${amount ~/ 1000}k'),
                          selected: isSelected,
                          onSelected: (selected) => setState(() { isCustomBet = false; selectedBet = amount; }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: customBetController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Nhập số tiền khác...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState(() => isCustomBet = true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('HỦY', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: () async {
                    int finalBet = isCustomBet ? (int.tryParse(customBetController.text) ?? 0) : selectedBet;
                    if (finalBet <= 0) return;
                    if (userBalance < finalBet) return;
                    Navigator.pop(dialogContext);
                    String? roomId = await _roomService.createRoom(uid, selectedRule, finalBet);
                    if (roomId != null && mounted) {
                      Navigator.push(parentContext, MaterialPageRoute(builder: (_) => TienLenRoomScreen(roomId: roomId, shouldResetOrientation: false))).then((_) => _setLandscape());
                    }
                  },
                  child: const Text('BẮT ĐẦU'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showQuickPlayForm(BuildContext context, String uid, int userBalance, List<RoomModel> allRooms) {
    String selectedRule = 'per_card';
    RangeValues betRange = const RangeValues(10000, 100000);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B4D3E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amberAccent)),
              title: const Text('CHƠI NHANH', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Luật chơi:', style: TextStyle(color: Colors.white70)),
                    Row(
                      children: [
                        _buildChip(selectedRule == 'per_card', 'TÍNH LÁ', () => setState(() => selectedRule = 'per_card')),
                        const SizedBox(width: 10),
                        _buildChip(selectedRule == 'sacrifice', 'CÚNG BÀI', () => setState(() => selectedRule = 'sacrifice')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Mức cược: ${betRange.start.toInt()} - ${betRange.end.toInt()}', style: const TextStyle(color: Colors.white70)),
                    RangeSlider(
                      values: betRange, min: 1000, max: 500000, divisions: 50,
                      activeColor: Colors.amberAccent,
                      onChanged: (values) => setState(() => betRange = values),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('HỦY', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    RoomModel? suitableRoom;
                    for (var room in allRooms) {
                      if (room.ruleType == selectedRule && room.betAmount >= betRange.start && room.betAmount <= betRange.end && room.players.length < 4 && room.status == 'waiting') {
                        suitableRoom = room;
                        break;
                      }
                    }
                    if (suitableRoom != null) {
                      String? error = await _roomService.joinRoom(suitableRoom.id, uid);
                      if (error == null && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TienLenRoomScreen(roomId: suitableRoom!.id, shouldResetOrientation: false))).then((_) => _setLandscape());
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy bàn phù hợp!')));
                    }
                  },
                  child: const Text('VÀO BÀN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGameRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B4D3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amberAccent)),
          title: const Center(child: Text('LUẬT CHƠI TIẾN LÊN', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRuleSection('1. CƠ BẢN', 'Bộ bài 52 lá, chia đều cho 4 người (13 lá mỗi người). Lượt đánh theo chiều kim đồng hồ.'),
                _buildRuleSection('2. TÍNH LÁ', 'Kết thúc ván, người thắng ăn tiền từ những người còn lại dựa trên số lá họ chưa đánh được. Càng nhiều lá phạt càng nặng!'),
                _buildRuleSection('3. CÚNG BÀI', 'Hạng 1 ăn tiền Hạng 4, Hạng 2 ăn tiền Hạng 3. Ở ván sau, Hạng 4 phải cúng lá bài lớn nhất cho Hạng 1.'),
                _buildRuleSection('4. ĐIỂM ĐẶC BIỆT', 'Tứ quý chặn được heo (2), 3 đôi thông chặn được heo, 4 đôi thông chặn được đôi heo và có thể chặn mà không cần vòng.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ĐÃ HIỂU', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
          ],
        );
      },
    );
  }

  Widget _buildRuleSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 5),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildChip(bool isSelected, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.amberAccent : Colors.white10, borderRadius: BorderRadius.circular(15)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) return const SizedBox();
        final user = state.user;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF1B4D3E), Color(0xFF0F1B14)],
                radius: 1.2,
                center: Alignment.center,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, user),
                  Expanded(
                    child: Row(
                      children: [
                        _buildSidebar(context, user),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('DANH SÁCH BÀN: $_selectedFilter', 
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent, letterSpacing: 1.2),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, color: Colors.white70),
                                      onPressed: () => setState(() {}),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: StreamBuilder<List<RoomModel>>(
                                    stream: _roomService.streamWaitingRooms(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));
                                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                                      
                                      List<RoomModel> allRooms = snapshot.data ?? [];
                                      List<RoomModel> rooms = allRooms.where((room) {
                                        if (_selectedFilter == 'TẤT CẢ') return true;
                                        if (_selectedFilter == 'CÒN TRỐNG') return room.players.length < 4;
                                        if (_selectedFilter == 'CHƯA CHƠI') return room.status == 'waiting';
                                        return true;
                                      }).toList();
                                      
                                      return GridView.builder(
                                        padding: const EdgeInsets.only(bottom: 80),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9, crossAxisSpacing: 15, mainAxisSpacing: 15),
                                        itemCount: rooms.length + 1,
                                        itemBuilder: (context, index) {
                                          if (index == 0) return _buildCreateTableButton(context, user);
                                          final room = rooms[index - 1];
                                          return _buildRoomTable(context, room, user);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTopBar(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Home & Rules
          Row(
            children: [
              _buildCircleAction(Icons.home_rounded, const Color(0xFFFF6B6B), () => Navigator.pop(context)),
              const SizedBox(width: 12),
              _buildRulesButton(context),

              const SizedBox(width: 12),
              // Center: User Info & Balance (Integrated Pill)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUserInfoBadge(user),
                    Container(width: 1, height: 20, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 8)),
                    _buildBalanceBadge(user),
                    const SizedBox(width: 4),
                    _buildAddBalanceButton(),
                  ],
                ),
              ),
            ],
          ),

          // Right: Active Players & Leaderboard & Menu
          Row(
            children: [
              _buildActivePlayersButton(context),
              const SizedBox(width: 12),
              _buildCircleAction(Icons.emoji_events_rounded, Colors.purpleAccent, () {
                Future.delayed(Duration.zero, () => _showLeaderboard(context));
              }),
              const SizedBox(width: 12),
              _buildCircleAction(Icons.menu_rounded, Colors.blueGrey, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesButton(BuildContext context) {
    return InkWell(
      onTap: () => _showGameRules(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.casino_rounded, color: Colors.amberAccent, size: 18),
            const SizedBox(width: 6),
            const Text('LUẬT CHƠI', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlayersButton(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').where('status', isEqualTo: 'playing').snapshots(),
      builder: (context, snapshot) {
        int activeCount = 0;
        if (snapshot.hasData) {
          Set<String> uids = {};
          for (var doc in snapshot.data!.docs) {
            final players = (doc.data() as Map<String, dynamic>)['players'] as List<dynamic>? ?? [];
            for (var p in players) {
              String uid = (p is Map) ? p['uid'] : p.toString();
              if (!uid.startsWith('bot_')) uids.add(uid);
            }
          }
          activeCount = uids.length;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCircleAction(Icons.people_alt_rounded, const Color(0xFF4ECDC4), () {
              Future.delayed(Duration.zero, () => _showActivePlayers(context));
            }),
            if (activeCount > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1B4D3E), width: 2),
                  ),
                  child: Text('$activeCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserInfoBadge(UserModel user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.amber, Colors.orange])),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            Text('Cấp 1', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceBadge(UserModel user) {
    String balanceStr = user.balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => "${m[1]}.");
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 18),
        const SizedBox(width: 6),
        Text(balanceStr, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildAddBalanceButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
      child: const Icon(Icons.add_rounded, color: Colors.black, size: 14),
    );
  }

  Widget _buildCircleAction(IconData icon, Color color, [VoidCallback? onTap]) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.8),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, UserModel user) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSideTab('TẤT CẢ', _selectedFilter == 'TẤT CẢ', () => setState(() => _selectedFilter = 'TẤT CẢ')),
            _buildSideTab('CÒN TRỐNG', _selectedFilter == 'CÒN TRỐNG', () => setState(() => _selectedFilter = 'CÒN TRỐNG')),
            _buildSideTab('CHƯA CHƠI', _selectedFilter == 'CHƯA CHƠI', () => setState(() => _selectedFilter = 'CHƯA CHƠI')),
            const SizedBox(height: 20),
            StreamBuilder<List<RoomModel>>(
              stream: _roomService.streamWaitingRooms(),
              builder: (context, snapshot) => _buildSideTab('CHƠI NHANH', _selectedFilter == 'CHƠI NHANH', () {
                setState(() => _selectedFilter = 'CHƠI NHANH');
                _showQuickPlayForm(context, user.uid, user.balance, snapshot.data ?? []);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 10),
        width: double.infinity, height: 38,
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFFF9D29D), Color(0xFFE99C6A)]) : const LinearGradient(colors: [Color(0xFF8B5A2B), Color(0xFF5D3A1A)]),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(child: Text(title, style: TextStyle(color: isSelected ? Colors.brown : Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
      ),
    );
  }

  Widget _buildCreateTableButton(BuildContext context, UserModel user) {
    return InkWell(
      onTap: () => _createRoom(context, user.uid, user.balance),
      child: Column(children: [
        Container(
          height: 80,
          decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amberAccent, width: 2)),
          child: const Center(child: Icon(Icons.add, color: Colors.white, size: 40)),
        ),
        const SizedBox(height: 8),
        const Text('Tạo bàn', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildRoomTable(BuildContext context, RoomModel room, UserModel user) {
    return InkWell(
      onTap: () async {
        String? error = await _roomService.joinRoom(room.id, user.uid);
        if (error == null && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TienLenRoomScreen(roomId: room.id, shouldResetOrientation: false))).then((_) => _setLandscape());
        }
      },
      child: Column(children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF006400), Color(0xFF004400)]),
              borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF8B4513), width: 4),
            ),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 14), const SizedBox(width: 4), Text('${room.betAmount}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))]),
              Text('${room.players.length}/4', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              if (room.status == 'playing') const Text('Đang chơi', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
            ])),
          ),
          Positioned(top: -5, right: -5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1)), child: Text(room.ruleType == 'per_card' ? 'Lá' : 'Cúng', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        ]),
        const SizedBox(height: 8),
        Text(room.id.substring(room.id.length - 4).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
      ]),
    );
  }
}
