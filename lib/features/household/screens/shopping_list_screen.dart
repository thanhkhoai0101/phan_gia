import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list_model.dart';
import '../services/household_service.dart';
import 'expense_entry_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final ShoppingListModel shoppingList;

  const ShoppingListScreen({Key? key, required this.shoppingList}) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late ShoppingListModel _currentList;
  bool _isUpdating = false;

  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentList = widget.shoppingList;
  }

  bool get isCompleted => _currentList.status == 'completed';

  Future<void> _toggleItem(int index) async {
    if (isCompleted) return; // Không cho sửa nếu đã hoàn tất

    final item = _currentList.items[index];
    final updatedItems = List<ShoppingItemModel>.from(_currentList.items);
    updatedItems[index] = item.copyWith(isChecked: !item.isChecked);

    final updatedList = _currentList.copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );

    setState(() => _currentList = updatedList);

    // Lưu lên Firestore
    try {
      await HouseholdService().updateShoppingList(updatedList);
    } catch (e) {
      // Rollback UI nếu lỗi
      setState(() => _currentList = widget.shoppingList);
    }
  }

  int get _checkedCount => _currentList.items.where((i) => i.isChecked).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách đi chợ'),
        actions: [
          // Badge trạng thái
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCompleted ? '✅ Hoàn tất' : '🛒 Đang đi chợ',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── THÔNG TIN HEADER ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withOpacity(isDark ? 0.15 : 0.08),
              border: Border(bottom: BorderSide(color: primary.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isCompleted ? Colors.green : primary,
                  child: Icon(
                    isCompleted ? Icons.check : Icons.person,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted ? 'Đã hoàn tất đi chợ' : 'Đang đi chợ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_checkedCount/${_currentList.items.length} mặt hàng đã mua',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Dự toán', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      _currencyFormat.format(_currentList.estimatedTotal),
                      style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── PROGRESS BAR ──
          LinearProgressIndicator(
            value: _currentList.items.isEmpty
                ? 0
                : _checkedCount / _currentList.items.length,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: isCompleted ? Colors.green : primary,
            minHeight: 4,
          ),

          // ── DANH SÁCH MÓN HÀNG ──
          Expanded(
            child: _currentList.items.isEmpty
                ? const Center(child: Text('Danh sách trống.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentList.items.length,
                    itemBuilder: (context, index) {
                      final item = _currentList.items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: item.isChecked
                              ? Colors.green.withOpacity(0.05)
                              : (isDark ? const Color(0xFF162435) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isChecked
                                ? Colors.green.withOpacity(0.3)
                                : (isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: item.isChecked,
                          onChanged: isCompleted ? null : (_) => _toggleItem(index),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.isChecked ? TextDecoration.lineThrough : null,
                              color: item.isChecked ? Colors.grey : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text('${item.quantity} ${item.unit}',
                                  style: const TextStyle(fontSize: 13)),
                              if (item.actualPrice != null && item.actualPrice! > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '→ ${_currencyFormat.format(item.actualPrice!)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ]
                            ],
                          ),
                          activeColor: Colors.green,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── BOTTOM BUTTON ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isCompleted
              // Đã hoàn tất: hiển thị tổng thực chi
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text('Đã hoàn tất & lưu giao dịch',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                )
              // Chưa hoàn tất: nút "Hoàn tất đi chợ"
              : ElevatedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseEntryScreen(shoppingList: _currentList),
                            ),
                          );
                        },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('HOÀN TẤT ĐI CHỢ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
        ),
      ),
    );
  }
}
