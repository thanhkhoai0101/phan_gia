import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/household_bloc.dart';
import '../blocs/household_state.dart';
import '../models/meal_model.dart';
import '../services/meal_generator_service.dart';
import '../services/household_service.dart';
import '../models/meal_plan_model.dart';
import '../models/shopping_list_model.dart';
import 'meal_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RandomMealScreen extends StatefulWidget {
  const RandomMealScreen({Key? key}) : super(key: key);

  @override
  State<RandomMealScreen> createState() => _RandomMealScreenState();
}

class _RandomMealScreenState extends State<RandomMealScreen> {
  MealGeneratorMode _selectedMode = MealGeneratorMode.normal;
  List<MealModel>? _generatedMeals;

  void _generate(List<MealModel> allMeals) {
    // Gọi thuật toán random món ăn
    // Chú ý: Ở đây ta pass history = [] tạm thời, bạn có thể bổ sung get history từ Firebase sau.
    final result = MealGeneratorService.generateMealPlan(
      allMeals: allMeals,
      history: [], 
      mode: _selectedMode,
    );
    
    setState(() {
      _generatedMeals = result;
    });
  }

  void _saveMealPlan() async {
    if (_generatedMeals == null || _generatedMeals!.isEmpty) return;

    // TODO: Get real familyId from Auth
    const familyId = 'default_family'; 
    final now = DateTime.now();

    final plan = MealPlanModel(
      id: '',
      familyId: familyId,
      targetDate: now,
      mealIds: _generatedMeals!.map((m) => m.id).toList(),
      estimatedTotalCost: _generatedMeals!.fold(0, (sum, m) => sum + m.estimatedCost),
      createdAt: now,
      updatedAt: now,
    );

    // Sinh shopping list
    List<ShoppingItemModel> shoppingItems = [];
    for (var meal in _generatedMeals!) {
      for (var ing in meal.ingredients) {
        shoppingItems.add(ShoppingItemModel(
          id: ing.id,
          name: ing.name,
          quantity: ing.quantity,
          unit: ing.unit,
        ));
      }
    }

    final shoppingList = ShoppingListModel(
      id: '',
      familyId: familyId,
      items: shoppingItems,
      estimatedTotal: plan.estimatedTotalCost,
      targetDate: now,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final service = HouseholdService();
      await service.createMealPlan(plan);
      await service.createShoppingList(shoppingList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu thực đơn & Tạo danh sách đi chợ thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôm nay ăn gì?'),
      ),
      body: BlocBuilder<HouseholdBloc, HouseholdState>(
        builder: (context, state) {
          if (state is HouseholdLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HouseholdLoaded) {
            final allMeals = state.meals;
            if (allMeals.isEmpty) {
              return const Center(child: Text('Chưa có danh sách món ăn.'));
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Chọn tiêu chí:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MealGeneratorMode.values.map((mode) {
                      final isSelected = _selectedMode == mode;
                      return ChoiceChip(
                        label: Text(_getModeString(mode)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedMode = mode);
                          }
                        },
                        selectedColor: primary.withOpacity(0.2),
                        labelStyle: TextStyle(color: isSelected ? primary : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton.icon(
                    onPressed: () => _generate(allMeals),
                    icon: const Icon(Icons.casino),
                    label: const Text('BỐC MÓN NGẪU NHIÊN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_generatedMeals != null) ...[
                    const Text('Kết quả thực đơn:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_generatedMeals!.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('Không tìm thấy món ăn nào phù hợp với tiêu chí này.',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _generatedMeals!.length,
                          itemBuilder: (context, index) {
                            final meal = _generatedMeals![index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: meal.imageUrl != null 
                                    ? CachedNetworkImage(
                                        imageUrl: meal.imageUrl!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) {
                                          return const Icon(Icons.fastfood, size: 40);
                                        },
                                      )
                                    : const Icon(Icons.fastfood, size: 40),
                                title: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${meal.prepTime + meal.cookTime} phút - ${meal.estimatedCost}đ'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MealDetailScreen(
                                      meal: meal,
                                      onMealUpdated: (updatedMeal) {
                                        setState(() {
                                          _generatedMeals![index] = updatedMeal;
                                        });
                                      },
                                    )),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveMealPlan,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('LƯU THỰC ĐƠN HÔM NAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  String _getModeString(MealGeneratorMode mode) {
    switch (mode) {
      case MealGeneratorMode.normal: return 'Bình thường';
      case MealGeneratorMode.fast: return 'Nấu nhanh';
      case MealGeneratorMode.budget: return 'Tiết kiệm';
      case MealGeneratorMode.lazy: return 'Lười biếng';
      case MealGeneratorMode.weekend: return 'Cuối tuần';
    }
  }
}
