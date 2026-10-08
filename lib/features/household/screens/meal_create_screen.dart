import 'package:flutter/material.dart';
import '../models/meal_model.dart';
import '../services/household_service.dart';

class MealCreateScreen extends StatefulWidget {
  const MealCreateScreen({Key? key}) : super(key: key);

  @override
  State<MealCreateScreen> createState() => _MealCreateScreenState();
}

class _MealCreateScreenState extends State<MealCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imageController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '15');
  final _cookTimeController = TextEditingController(text: '30');
  final _servingsController = TextEditingController(text: '4');
  final _costController = TextEditingController(text: '200000'); // Default 4 * 50,000

  String _category = 'other';
  String _mealType = 'main';

  final List<Map<String, TextEditingController>> _ingredients = [];
  final List<TextEditingController> _instructions = [];
  
  bool _isLoading = false;

  final Map<String, String> _categories = {
    'pork': 'Thịt heo',
    'beef': 'Thịt bò',
    'chicken': 'Thịt gà',
    'fish': 'Cá & Hải sản',
    'vegetarian': 'Chay',
    'other': 'Khác',
  };

  final Map<String, String> _mealTypes = {
    'main': 'Món chính',
    'soup': 'Canh/Súp',
    'vegetable': 'Rau xanh',
    'side': 'Món ăn kèm',
    'dessert': 'Tráng miệng',
    'drink': 'Đồ uống',
  };

  @override
  void initState() {
    super.initState();
    _addIngredient();
    _addInstruction();

    _servingsController.addListener(() {
      final s = int.tryParse(_servingsController.text) ?? 4;
      // Auto update cost only if the user hasn't heavily customized it (heuristics)
      _costController.text = (s * 50000).toString();
    });
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add({
        'name': TextEditingController(),
        'quantity': TextEditingController(text: '1'),
        'unit': TextEditingController(text: 'g'),
      });
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addInstruction() {
    setState(() {
      _instructions.add(TextEditingController());
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructions.removeAt(index);
    });
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 nguyên liệu!')),
      );
      return;
    }
    
    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 bước hướng dẫn nấu!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      
      final List<IngredientModel> parsedIngredients = _ingredients.map((ing) {
        return IngredientModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(), // Temp ID
          name: ing['name']!.text.trim(),
          quantity: double.tryParse(ing['quantity']!.text) ?? 1.0,
          unit: ing['unit']!.text.trim(),
        );
      }).toList();

      final List<String> parsedInstructions = _instructions
          .map((i) => i.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final newMeal = MealModel(
        id: '', // Service will create ID
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
        category: _category,
        mealType: _mealType,
        prepTime: int.tryParse(_prepTimeController.text) ?? 15,
        cookTime: int.tryParse(_cookTimeController.text) ?? 30,
        servings: int.tryParse(_servingsController.text) ?? 4,
        estimatedCost: double.tryParse(_costController.text) ?? 200000.0,
        ingredients: parsedIngredients,
        instructions: parsedInstructions,
        nutrition: NutritionModel(calories: 300, protein: 20, carbs: 20, fat: 10), // Temp mock
        createdAt: now,
        updatedAt: now,
      );

      await HouseholdService().createMeal(newMeal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo món ăn thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Món Ăn Mới'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveMeal,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── THÔNG TIN CƠ BẢN ──
            _buildSectionHeader('Thông tin chung', Icons.info_outline, primary),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tên món ăn (*)', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Bắt buộc nhập' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _imageController,
                      decoration: const InputDecoration(labelText: 'Link hình ảnh (URL)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Mô tả ngắn', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _category,
                            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                            items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                            onChanged: (val) => setState(() => _category = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _mealType,
                            decoration: const InputDecoration(labelText: 'Loại món', border: OutlineInputBorder()),
                            items: _mealTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                            onChanged: (val) => setState(() => _mealType = val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── KHẨU PHẦN & THỜI GIAN ──
            _buildSectionHeader('Định lượng & Chi phí', Icons.access_time, primary),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Chuẩn bị (phút)',labelStyle: TextStyle(fontSize: 9), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cookTimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Nấu (phút)',labelStyle: TextStyle(fontSize: 9), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _servingsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Số người',labelStyle: TextStyle(fontSize: 9), border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chi phí dự kiến (VNĐ)', 
                        border: OutlineInputBorder(),
                        helperText: 'Tự động tính theo mức 50,000đ/người (có thể sửa)',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Bắt buộc nhập chi phí' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── NGUYÊN LIỆU ──
            _buildSectionHeader('Nguyên liệu', Icons.restaurant_menu, primary),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ingredients.length,
              itemBuilder: (context, index) {
                final ing = _ingredients[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: ing['name'],
                          decoration: InputDecoration(hintText: 'Tên NL (VD: Thịt heo)', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Nhập tên' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: ing['quantity'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'SL', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: ing['unit'],
                          decoration: InputDecoration(hintText: 'Đơn vị', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeIngredient(index),
                      ),
                    ],
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Thêm nguyên liệu'),
            ),
            const SizedBox(height: 24),

            // ── CÁCH NẤU ──
            _buildSectionHeader('Cách nấu', Icons.format_list_numbered, primary),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('Bước ${index + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _instructions[index],
                          maxLines: 2,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Nhập hướng dẫn' : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeInstruction(index),
                      ),
                    ],
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: _addInstruction,
              icon: const Icon(Icons.add),
              label: const Text('Thêm bước nấu'),
            ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
