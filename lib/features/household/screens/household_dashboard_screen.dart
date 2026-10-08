import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../models/expense_model.dart';
import '../seed_data.dart';
import 'random_meal_screen.dart';
import '../services/household_service.dart';
import '../models/meal_plan_model.dart';
import '../models/shopping_list_model.dart';
import '../blocs/household_bloc.dart';
import '../blocs/household_state.dart';
import 'shopping_list_screen.dart';
import 'meal_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'weekly_finance_screen.dart';
import 'meal_create_screen.dart';
import 'package:intl/intl.dart';
import 'meal_list_screen.dart';

class HouseholdDashboardScreen extends StatelessWidget {
  const HouseholdDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    DateTime now = DateTime.now();
    int currentDay = now.weekday;
    DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentDay - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCookingMode = false;
        if (authState is AuthAuthenticated) {
          isCookingMode = authState.user.isCookingModeEnabled;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nội trợ & Tài chính'),
            elevation: 0,
            actions: [
              if (isCookingMode)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Import 30 Món ăn mẫu',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang import dữ liệu, vui lòng đợi...')),
                    );
                    await SeedData.importMeals();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Import thành công 30 món ăn!')),
                    );
                  },
                ),
            ],
          ),
          floatingActionButton: isCookingMode
              ? FloatingActionButton.extended(
                  heroTag: 'household_fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MealCreateScreen()),
                    );
                  },
                  backgroundColor: primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Thêm món', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : null,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── HÔM NAY ĂN GÌ? (Chỉ hiện khi bật Cooking Mode) ──
                if (isCookingMode) ...[
                  _buildActionCard(
                    context: context,
                    title: 'Hôm nay ăn gì?',
                    subtitle: 'Bốc món ngẫu nhiên cho gia đình',
                    icon: Icons.restaurant_menu_rounded,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RandomMealScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context: context,
                    title: 'Danh sách món ăn',
                    subtitle: 'Xem toàn bộ món ăn và chọn món cho hôm nay',
                    icon: Icons.list_alt_rounded,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MealListScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ── THỰC ĐƠN HÔM NAY ──
                _buildSectionTitle('🍽️ Thực đơn hôm nay'),
                const SizedBox(height: 12),
                StreamBuilder<List<MealPlanModel>>(
                  stream: HouseholdService().getMealPlans(
                      'default_family',
                      DateTime.now().subtract(const Duration(hours: 23)),
                      DateTime.now().add(const Duration(hours: 23))),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final plans = snapshot.data ?? [];
                    if (plans.isEmpty) {
                      return _buildInfoCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chưa có thực đơn cho hôm nay.',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                            if (isCookingMode) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RandomMealScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Tạo thực đơn'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary.withOpacity(0.15),
                                    foregroundColor: primary,
                                    elevation: 0,
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                      );
                    }

                    final todayPlan = plans.last;
                    return isCookingMode
                        ? _buildCookingModePlanCard(context, todayPlan, isDark, primary)
                        : _buildViewModePlanList(context, todayPlan, isDark, primary);
                  },
                ),
                const SizedBox(height: 20),

                // ── ĐI CHỢ & CHI TIÊU (Chỉ hiện khi bật Cooking Mode) ──
                if (isCookingMode) ...[
                  _buildSectionTitle('🛒 Đi chợ hôm nay'),
                  const SizedBox(height: 12),
                  StreamBuilder<List<ShoppingListModel>>(
                    stream: HouseholdService().getTodayShoppingLists('default_family'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final lists = snapshot.data ?? [];
                      if (lists.isEmpty) {
                        return _buildInfoCard(
                          isDark: isDark,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_basket_rounded, color: Colors.green),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Chưa có danh sách đi chợ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(height: 4),
                                    Text('Hãy tạo thực đơn trước nhé!'),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      }

                      final activeList = lists.first;
                      final isCompleted = activeList.status == 'completed';
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ShoppingListScreen(shoppingList: activeList)),
                          );
                        },
                        child: _buildInfoCard(
                          isDark: isDark,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCompleted ? Icons.check_rounded : Icons.shopping_basket_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCompleted
                                          ? 'Đã hoàn tất đi chợ hôm nay ✅'
                                          : 'Đã có danh sách (${activeList.items.length} mặt hàng)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isCompleted
                                          ? 'Nhấn để xem lại chi tiết'
                                          : 'Nhấn để đi chợ & tick mặt hàng',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('📊 Chi tiêu tuần này'),
                  const SizedBox(height: 12),
                  StreamBuilder<List<ExpenseModel>>(
                    stream: HouseholdService().getWeeklyExpenses('default_family', startOfWeek, endOfWeek),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final expenses = snapshot.data ?? [];
                      double totalExpense = expenses.fold(0, (sum, e) => sum + e.actualAmount);
                      double budget = 1000000.0; // Mặc định 1 triệu
                      double progress = (totalExpense / budget).clamp(0.0, 1.0);
                      bool isExceeded = totalExpense > budget;
                      
                      final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
                      
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WeeklyFinanceScreen(familyId: 'default_family')),
                          );
                        },
                        child: _buildInfoCard(
                          isDark: isDark,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Đã chi:', style: TextStyle(fontSize: 16)),
                                  Text(
                                    currencyFormat.format(totalExpense),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded ? Colors.redAccent : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.withOpacity(0.2),
                                color: isExceeded ? Colors.redAccent : Colors.green,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('Ngân sách: ${currencyFormat.format(budget)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // Card rút gọn khi ở chế độ nấu ăn
  Widget _buildCookingModePlanCard(BuildContext context, MealPlanModel todayPlan, bool isDark, Color primary) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, controller) => _buildMealListBottomSheet(context, todayPlan, primary, controller, true),
          ),
        );
      },
      child: _buildInfoCard(
        isDark: isDark,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bạn có ${todayPlan.mealIds.length} món ăn hôm nay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Dự toán: ${todayPlan.estimatedTotalCost}đ',
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Nhấn để xem chi tiết', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Danh sách đầy đủ trên view chính khi không bật chế độ nấu ăn
  Widget _buildViewModePlanList(BuildContext context, MealPlanModel todayPlan, bool isDark, Color primary) {
    return _buildInfoCard(
      isDark: isDark,
      child: BlocBuilder<HouseholdBloc, HouseholdState>(
        bloc: context.read<HouseholdBloc>(),
        builder: (context, state) {
          final allMeals = (state is HouseholdLoaded) ? state.meals : [];
          final mealsToday = allMeals.where((m) => todayPlan.mealIds.contains(m.id)).toList();

          if (mealsToday.isEmpty) {
            return const Center(child: Text('Chưa tải được thông tin món ăn.'));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: mealsToday.map((meal) {
              final rating = todayPlan.mealRatings[meal.id] ?? 0;
              final note = todayPlan.mealNotes[meal.id] ?? '';

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: meal.imageUrl!,
                              width: 64, height: 64, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildFallbackIcon(primary),
                              errorListener: (_) {},
                            )
                          : _buildFallbackIcon(primary),
                    ),
                    title: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${meal.prepTime + meal.cookTime} phút',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 12),
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(rating > 0 ? '$rating/5' : 'Chưa đánh giá',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
                      );
                    },
                  ),
                  // Phần đánh giá nhanh & Ghi chú
                  Container(
                    margin: const EdgeInsets.only(left: 76, top: 4, bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Đánh giá:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            ...List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  HouseholdService().updateMealFeedback(
                                    todayPlan.familyId, todayPlan.id, meal.id, index + 1, note
                                  );
                                },
                                child: Icon(
                                  index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: note,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Ghi chú (nhạt, mặn, thêm ớt...)',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.black26 : Colors.white,
                          ),
                          onFieldSubmitted: (val) {
                            HouseholdService().updateMealFeedback(
                              todayPlan.familyId, todayPlan.id, meal.id, rating, val
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã lưu ghi chú!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (meal != mealsToday.last) const Divider(height: 24),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // Nội dung bottom sheet (dành cho chế độ nấu ăn)
  Widget _buildMealListBottomSheet(BuildContext context, MealPlanModel todayPlan, Color primary, ScrollController controller, bool isCookingMode) {
    return BlocBuilder<HouseholdBloc, HouseholdState>(
      bloc: context.read<HouseholdBloc>(),
      builder: (_, state) {
        final allMeals = (state is HouseholdLoaded) ? state.meals : [];
        final mealsToday = allMeals.where((m) => todayPlan.mealIds.contains(m.id)).toList();

        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thực đơn hôm nay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Dự toán: ${todayPlan.estimatedTotalCost}đ',
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: mealsToday.isEmpty
                  ? const Center(child: Text('Chưa tải được thông tin món ăn.'))
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: mealsToday.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final meal = mealsToday[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: meal.imageUrl!,
                                    width: 64, height: 64, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _buildFallbackIcon(primary),
                                  )
                                : _buildFallbackIcon(primary),
                          ),
                          title: Text(meal.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('${meal.prepTime + meal.cookTime} phút',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                                  Text('${meal.estimatedCost}đ',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallbackIcon(Color primary) {
    return Container(
      width: 64, height: 64,
      color: primary.withOpacity(0.15),
      child: Icon(Icons.restaurant, color: primary),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.2 : 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildInfoCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162435) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: child,
    );
  }
}
