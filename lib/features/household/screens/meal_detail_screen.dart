import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meal_model.dart';

class MealDetailScreen extends StatefulWidget {
  final MealModel meal;
  final void Function(MealModel)? onMealUpdated;

  const MealDetailScreen({Key? key, required this.meal, this.onMealUpdated}) : super(key: key);

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late int _currentServings;

  @override
  void initState() {
    super.initState();
    _currentServings = widget.meal.servings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── HÌNH ẢNH MÓN ĂN & APPBAR ──
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.meal.name,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: widget.meal.imageUrl != null && widget.meal.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.meal.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: primary.withOpacity(0.5),
                        child: const Icon(Icons.restaurant, size: 80, color: Colors.white),
                      ),
                    )
                  : Container(
                      color: primary.withOpacity(0.5),
                      child: const Icon(Icons.restaurant, size: 80, color: Colors.white),
                    ),
            ),
          ),

          // ── NỘI DUNG CHI TIẾT ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THÔNG TIN CHUNG
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoBadge(Icons.timer, '${widget.meal.prepTime + widget.meal.cookTime} phút', isDark),
                      _buildInfoBadge(Icons.people, '$_currentServings người', isDark),
                      _buildInfoBadge(Icons.attach_money, '${_calculateCurrentCost()}đ', isDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // MÔ TẢ
                  if (widget.meal.description.isNotEmpty) ...[
                    Text(
                      widget.meal.description,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // TÍNH TOÁN KHẨU PHẦN
                  _buildSectionTitle('👥 Tùy chỉnh khẩu phần'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Số người ăn: '),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (_currentServings > 1) {
                            setState(() => _currentServings--);
                            _fireUpdate();
                          }
                        },
                      ),
                      Text(
                        '$_currentServings',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(' người'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() => _currentServings++);
                          _fireUpdate();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // NGUYÊN LIỆU
                  _buildSectionTitle('🥩 Nguyên liệu'),
                  const SizedBox(height: 12),
                  if (widget.meal.ingredients.isEmpty)
                    const Text('Chưa có thông tin nguyên liệu.')
                  else
                    ...widget.meal.ingredients.map((ing) {
                      final portionMultiplier = _currentServings / widget.meal.servings;
                      final calculatedQuantity = ing.quantity * portionMultiplier;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(ing.name, style: const TextStyle(fontSize: 15)),
                            ),
                            Text(
                              '${calculatedQuantity.toStringAsFixed(calculatedQuantity.truncateToDouble() == calculatedQuantity ? 0 : 1)} ${ing.unit}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 24),

                  // CÁCH NẤU
                  _buildSectionTitle('🍳 Cách nấu'),
                  const SizedBox(height: 12),
                  if (widget.meal.instructions.isEmpty)
                    const Text('Chưa có thông tin cách nấu.')
                  else
                    ...List.generate(widget.meal.instructions.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: primary,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.meal.instructions[index],
                                style: const TextStyle(fontSize: 15, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // DINH DƯỠNG
                  _buildSectionTitle('📊 Giá trị dinh dưỡng (Ước tính)'),
                  const SizedBox(height: 8),
                  const Text(
                    '* Thông tin chỉ mang tính chất tham khảo cho 1 phần ăn.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionGrid(isDark),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _fireUpdate() {
    if (widget.onMealUpdated != null) {
      final ratio = _currentServings / widget.meal.servings;
      
      final newIngredients = widget.meal.ingredients.map((ing) {
        return IngredientModel(
          id: ing.id,
          name: ing.name,
          quantity: ing.quantity * ratio,
          unit: ing.unit,
        );
      }).toList();

      final updatedMeal = widget.meal.copyWith(
        servings: _currentServings,
        estimatedCost: widget.meal.estimatedCost * ratio,
        ingredients: newIngredients,
      );
      
      widget.onMealUpdated!(updatedMeal);
    }
  }

  String _calculateCurrentCost() {
    final ratio = _currentServings / widget.meal.servings;
    final newCost = widget.meal.estimatedCost * ratio;
    // Format to remove decimals for VND
    return newCost.toInt().toString();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNutritionGrid(bool isDark) {
    final nutritions = [
      {'label': 'Protein', 'value': '${widget.meal.nutrition.protein}g'},
      {'label': 'Carb', 'value': '${widget.meal.nutrition.carbs}g'},
      {'label': 'Fat', 'value': '${widget.meal.nutrition.fat}g'},
      {'label': 'Sodium', 'value': '${widget.meal.nutrition.sodium}mg'},
      {'label': 'Fiber', 'value': '${widget.meal.nutrition.fiber}g'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: nutritions.map((n) {
        return Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162435) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(n['label']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(n['value']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
