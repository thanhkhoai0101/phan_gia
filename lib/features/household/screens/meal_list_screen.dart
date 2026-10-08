import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../models/meal_model.dart';
import '../services/household_service.dart';
import 'meal_detail_screen.dart';

class MealListScreen extends StatefulWidget {
  const MealListScreen({Key? key}) : super(key: key);

  @override
  State<MealListScreen> createState() => _MealListScreenState();
}

class _MealListScreenState extends State<MealListScreen> {
  String _selectedCategory = 'all';

  final Map<String, String> _categories = {
    'all': 'Tất cả',
    'pork': 'Thịt heo',
    'beef': 'Thịt bò',
    'chicken': 'Thịt gà',
    'fish': 'Cá & Hải sản',
    'vegetarian': 'Chay',
    'other': 'Khác',
  };

  Future<void> _addToTodayPlan(BuildContext context, MealModel meal) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      try {
        await HouseholdService().addMealToTodayPlan('default_family', meal, authState.user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm "${meal.name}" vào thực đơn hôm nay!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Có lỗi xảy ra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách món ăn'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: _categories.entries.map((entry) {
                final isSelected = _selectedCategory == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = entry.key;
                        });
                      }
                    },
                    selectedColor: primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? primary : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Meal List
          Expanded(
            child: StreamBuilder<List<MealModel>>(
              stream: HouseholdService().getMeals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                
                final allMeals = snapshot.data ?? [];
                
                // Filter
                final filteredMeals = _selectedCategory == 'all' 
                    ? allMeals 
                    : allMeals.where((m) => m.category == _selectedCategory).toList();
                
                if (filteredMeals.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy món ăn nào.', style: TextStyle(fontStyle: FontStyle.italic)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredMeals.length,
                  itemBuilder: (context, index) {
                    final meal = filteredMeals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MealDetailScreen(meal: meal),
                            ),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: meal.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: meal.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.restaurant, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.restaurant, color: Colors.grey),
                                    ),
                            ),
                            // Info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text('${meal.prepTime + meal.cookTime}p', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                        const SizedBox(width: 12),
                                        Icon(Icons.local_fire_department, size: 14, color: Colors.orange.shade400),
                                        const SizedBox(width: 4),
                                        Text('${meal.nutrition?.calories ?? 0} kcal', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Action
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: primary,
                                tooltip: 'Thêm vào hôm nay',
                                onPressed: () => _addToTodayPlan(context, meal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
