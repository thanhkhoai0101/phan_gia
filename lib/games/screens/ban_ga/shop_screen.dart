import 'package:flutter/material.dart';
import 'services/shop_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ShopService _shop = ShopService();

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('🛒 Cửa Hàng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A3E),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amberAccent),
                const SizedBox(width: 6),
                Text('${_shop.coins}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent)),
              ],
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('⚔️ Nâng Cấp Tàu'),
          _shopItem(
            icon: Icons.favorite,
            iconColor: Colors.redAccent,
            title: 'Tăng Máu Tối Đa',
            description: 'Nâng HP tối đa lên ${_shop.maxHp + 1} mạng (hiện: ${_shop.maxHp})',
            cost: 100 * (_shop.maxHp - 2),
            onBuy: () async {
              final ok = await _shop.buyMaxHp();
              if (!mounted) return;
              if (ok) {
                _refresh();
                _showSnack('Nâng cấp thành công! HP tối đa: ${_shop.maxHp}');
              } else {
                _showSnack('Không đủ vàng! Cần ${100 * (_shop.maxHp - 2)} 🪙', isError: true);
              }
            },
          ),
          const SizedBox(height: 12),
          _shopItem(
            icon: Icons.timer,
            iconColor: Colors.cyanAccent,
            title: 'Tăng Thời Gian Vũ Khí',
            description: 'Vũ khí kéo dài thêm +2s (hiện: ${_shop.powerupDuration.toInt()}s → ${_shop.powerupDuration.toInt() + 2}s)',
            cost: 150,
            onBuy: () async {
              final ok = await _shop.buyPowerupDuration();
              if (!mounted) return;
              if (ok) {
                _refresh();
                _showSnack('Nâng cấp thành công! Thời gian: ${_shop.powerupDuration.toInt()}s');
              } else {
                _showSnack('Không đủ vàng! Cần 150 🪙', isError: true);
              }
            },
          ),
          const SizedBox(height: 24),
          _sectionTitle('🔫 Vũ Khí Khởi Đầu'),
          _weaponItem(
            label: '🔹 Súng Thường',
            description: 'Miễn phí — Bắn một viên đạn',
            cost: 0,
            type: 1,
          ),
          const SizedBox(height: 12),
          _weaponItem(
            label: '🟢 Đạn Tỉa 3',
            description: '200 🪙 — Bắt đầu với đạn tỉa 3 mũi',
            cost: 200,
            type: 2,
          ),
          const SizedBox(height: 12),
          _weaponItem(
            label: '🔵 Đạn Liên Thanh',
            description: '300 🪙 — Bắt đầu với chế độ bắn nhanh',
            cost: 300,
            type: 3,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  Widget _shopItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int cost,
    required VoidCallback onBuy,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF2A2A5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(description,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.monetization_on, size: 14),
          label: Text('$cost', style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: onBuy,
        ),
      ),
    );
  }

  Widget _weaponItem({
    required String label,
    required String description,
    required int cost,
    required int type,
  }) {
    final isSelected = _shop.startingWeapon == type;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [const Color(0xFF1A3A2E), const Color(0xFF0D5C3A)]
              : [const Color(0xFF1A1A3E), const Color(0xFF2A2A5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected
                ? Colors.greenAccent
                : Colors.deepPurpleAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
          child: const Icon(Icons.bolt, color: Colors.orangeAccent),
        ),
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(description,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: isSelected
            ? Chip(
                label: const Text('Đang dùng', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.green.shade700,
                padding: EdgeInsets.zero,
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.monetization_on, size: 14),
                label: Text(
                  cost == 0 ? 'Miễn Phí' : '$cost',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  if (cost == 0) {
                    _shop.buyStartingWeapon(type, 0);
                    if (!mounted) return;
                    _refresh();
                    _showSnack('Đã chọn: $label');
                  } else {
                    final ok = await _shop.buyStartingWeapon(type, cost);
                    if (!mounted) return;
                    if (ok) {
                      _refresh();
                      _showSnack('Đã chọn: $label');
                    } else {
                      _showSnack('Không đủ vàng! Cần $cost 🪙', isError: true);
                    }
                  }
                },
              ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
