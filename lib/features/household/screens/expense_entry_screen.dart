import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shopping_list_model.dart';
import '../models/expense_model.dart';
import '../services/household_service.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final ShoppingListModel shoppingList;

  const ExpenseEntryScreen({Key? key, required this.shoppingList}) : super(key: key);

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  bool _isDetailedMode = false;
  bool _isSaving = false;
  final TextEditingController _quickTotalController = TextEditingController();

  // Dùng map index -> controller để tránh bug mất state khi build lại
  late List<TextEditingController> _priceControllers;
  late List<ShoppingItemModel> _items;

  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.shoppingList.items.map((e) => e.copyWith()));
    _priceControllers = List.generate(_items.length, (_) => TextEditingController());

    // Lắng nghe thay đổi để tính tổng tự động
    for (var ctrl in _priceControllers) {
      ctrl.addListener(_recalculateTotal);
    }
  }

  @override
  void dispose() {
    _quickTotalController.dispose();
    for (var ctrl in _priceControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // Tính tổng tiền từ các ô nhập detail mode
  double get _detailTotal {
    double total = 0;
    for (var ctrl in _priceControllers) {
      total += double.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return total;
  }

  void _recalculateTotal() {
    setState(() {}); // Rebuild để cập nhật hiển thị tổng
  }

  Future<void> _submitExpense() async {
    double actualTotal;

    if (_isDetailedMode) {
      actualTotal = _detailTotal;
      // Gán actualPrice vào từng item
      for (int i = 0; i < _items.length; i++) {
        final price = double.tryParse(_priceControllers[i].text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        _items[i] = _items[i].copyWith(actualPrice: price);
      }
    } else {
      actualTotal = double.tryParse(_quickTotalController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    if (actualTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền thực tế!')),
      );
      return;
    }

    final expense = ExpenseModel(
      id: '',
      familyId: widget.shoppingList.familyId,
      shoppingListId: widget.shoppingList.id,
      createdBy: 'currentUser', // TODO: Get from AuthBloc
      estimatedAmount: widget.shoppingList.estimatedTotal,
      actualAmount: actualTotal,
      difference: actualTotal - widget.shoppingList.estimatedTotal,
      items: _isDetailedMode ? _items : [],
      purchasedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);

    try {
      await HouseholdService().recordExpense(expense, widget.shoppingList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã lưu giao dịch thành công!')),
        );
        Navigator.pop(context);
        Navigator.pop(context); // Quay về dashboard
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final estimatedTotal = widget.shoppingList.estimatedTotal;
    final currentTotal = _isDetailedMode
        ? _detailTotal
        : (double.tryParse(_quickTotalController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);
    final diff = currentTotal - estimatedTotal;
    final isOver = diff > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoàn tất đi chợ'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isDetailedMode = !_isDetailedMode;
              });
            },
            child: Text(
              _isDetailedMode ? 'Quick Mode' : 'Chi tiết',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── DỰ TOÁN ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dự toán ban đầu:', style: TextStyle(fontSize: 15)),
                        Text(
                          _currencyFormat.format(estimatedTotal),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── NHẬP CHI PHÍ ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chi phí thực tế:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_isDetailedMode)
                        Text(
                          _currencyFormat.format(_detailTotal),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isOver ? Colors.red : Colors.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // QUICK MODE
                  if (!_isDetailedMode)
                    TextField(
                      controller: _quickTotalController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      onChanged: (_) => _recalculateTotal(),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: 'đ',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF162435) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  // DETAIL MODE
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162435) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              // Tên + số lượng
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('${item.quantity} ${item.unit}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Ô nhập giá
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _priceControllers[i],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    suffixText: 'đ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  // ── CHÊNH LỆCH ──
                  if (currentTotal > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOver ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isOver ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isOver ? '⚠️ Vượt dự toán:' : '✅ Tiết kiệm được:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: isOver ? Colors.red : Colors.green)),
                          Text(
                            _currencyFormat.format(diff.abs()),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isOver ? Colors.red : Colors.green),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── NÚT LƯU ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('LƯU GIAO DỊCH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
