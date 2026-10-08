import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/household_service.dart';
import 'package:intl/intl.dart';

class WeeklyFinanceScreen extends StatefulWidget {
  final String familyId;
  
  const WeeklyFinanceScreen({Key? key, required this.familyId}) : super(key: key);

  @override
  State<WeeklyFinanceScreen> createState() => _WeeklyFinanceScreenState();
}

class _WeeklyFinanceScreenState extends State<WeeklyFinanceScreen> {
  final double _weeklyBudget = 1000000.0;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  late DateTime _startOfWeek;
  late DateTime _endOfWeek;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    int currentDay = now.weekday;
    _startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentDay - 1));
    _endOfWeek = _startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê tài chính'),
        elevation: 0,
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: HouseholdService().getWeeklyExpenses(widget.familyId, _startOfWeek, _endOfWeek),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data ?? [];
          
          // Tính tổng chi tiêu
          double totalExpense = expenses.fold(0, (sum, e) => sum + e.actualAmount);
          double remaining = _weeklyBudget - totalExpense;
          bool isExceeded = remaining < 0;

          // Xử lý dữ liệu cho biểu đồ 7 ngày
          List<double> dailyExpenses = List.filled(7, 0.0);
          for (var exp in expenses) {
            int weekdayIndex = exp.purchasedAt.weekday - 1; // 0: Thứ 2, 6: Chủ Nhật
            dailyExpenses[weekdayIndex] += exp.actualAmount;
          }
          double maxDailyExpense = dailyExpenses.isEmpty ? 0 : dailyExpenses.reduce((a, b) => a > b ? a : b);
          if (maxDailyExpense == 0) maxDailyExpense = 1; // Tránh chia cho 0

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── TỔNG QUAN TUẦN NÀY ──
                _buildSummaryCard(isDark, totalExpense, remaining, isExceeded),
                const SizedBox(height: 24),
                
                // ── BIỂU ĐỒ CHI TIÊU ──
                const Text('📊 Chi tiêu theo ngày', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162435) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                      final amount = dailyExpenses[index];
                      final heightRatio = amount / maxDailyExpense;
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (amount > 0)
                            Text(
                              NumberFormat.compact().format(amount),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 120 * heightRatio,
                            decoration: BoxDecoration(
                              color: amount > 0 ? theme.colorScheme.primary : Colors.grey.withOpacity(0.2),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: amount > 0 ? FontWeight.bold : FontWeight.normal,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),

                // ── LỊCH SỬ GIAO DỊCH ──
                const Text('📝 Lịch sử chi tiêu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (expenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162435) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
                    ),
                    child: const Text('Chưa có khoản chi tiêu nào trong tuần này.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(isDark, expenses[index]);
                    },
                  ),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, double totalExpense, double remaining, bool isExceeded) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isExceeded ? Colors.redAccent.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
            isExceeded ? Colors.red : Colors.orange,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isExceeded ? Colors.red : Colors.orange).withOpacity(isDark ? 0.2 : 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TỔNG CHI TUẦN NÀY', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold)),
              Icon(isExceeded ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(totalExpense),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ngân sách', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text(currencyFormat.format(_weeklyBudget), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(isExceeded ? 'Vượt ngân sách' : 'Còn lại', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text(
                    currencyFormat.format(remaining.abs()),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (totalExpense / _weeklyBudget).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.3),
            color: isExceeded ? Colors.black38 : Colors.white,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionItem(bool isDark, ExpenseModel expense) {
    bool isSaved = expense.difference <= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162435) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đi chợ hôm nay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Dự toán: ${currencyFormat.format(expense.estimatedAmount)}', 
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(expense.purchasedAt), 
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currencyFormat.format(expense.actualAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                isSaved ? '-${currencyFormat.format(expense.difference.abs())}' : '+${currencyFormat.format(expense.difference)}',
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w600,
                  color: isSaved ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
