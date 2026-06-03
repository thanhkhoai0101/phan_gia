import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../base/base_format.dart' show NumberFormatExtension;
import '../../models/bau_cua_model.dart';
import '../../services/bau_cua_service.dart';
import 'bau_cua_room_screen.dart';

class BauCuaLobbyScreen extends StatefulWidget {
  const BauCuaLobbyScreen({Key? key}) : super(key: key);

  @override
  State<BauCuaLobbyScreen> createState() => _BauCuaLobbyScreenState();
}

class _BauCuaLobbyScreenState extends State<BauCuaLobbyScreen> {
  final BauCuaService _service = BauCuaService();

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const Scaffold(body: Center(child: Text("Cần đăng nhập")));
    final user = authState.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1B2A), Color(0xFF1B4D3E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, user.displayName, user.balance),
              Expanded(
                child: StreamBuilder<List<BauCuaRoom>>(
                  stream: _service.streamRooms(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.amber));
                    }
                    final rooms = snapshot.data ?? [];
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: rooms.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildCreateRoomButton(context, user.displayName);
                        return _buildRoomCard(context, rooms[index - 1], user.displayName, user.balance);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String name, num balance) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('BẦU CUA', style: TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(balance.toCompactFormat(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomButton(BuildContext context, String name) {
    return InkWell(
      onTap: () async {
        String roomId = await _service.createRoom(name, 1000);
        Navigator.push(context, MaterialPageRoute(builder: (_) => BauCuaRoomScreen(roomId: roomId)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 2, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white30, size: 48),
            SizedBox(height: 8),
            Text('Tạo Bàn Mới', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, BauCuaRoom room, String name, num balance) {
    return InkWell(
      onTap: () async {
        await _service.joinRoom(room.id, name, balance);
        Navigator.push(context, MaterialPageRoute(builder: (_) => BauCuaRoomScreen(roomId: room.id)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
          image: const DecorationImage(
            image: AssetImage('assets/images/logo.png'), // Placeholder or bg
            opacity: 0.1,
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bàn #${room.id.substring(0, 4)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(room.hostName, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 4),
                Text('${room.players.length}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: room.status == 'betting' ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.status == 'betting' ? 'ĐANG CƯỢC' : 'ĐANG CHỜ',
                style: TextStyle(color: room.status == 'betting' ? Colors.greenAccent : Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
