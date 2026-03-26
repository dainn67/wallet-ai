import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Consumer<RecordProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.categories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = provider.categories;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  Text(
                    l10n.translate('drawer_categories'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: () {
                      // Will be implemented in task 011
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            l10n.translate('no_categories') ?? 'No categories yet',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            category.type == 'income' 
                                ? l10n.translate('income_label') 
                                : l10n.translate('spent_label'),
                            style: TextStyle(
                              fontSize: 12,
                              color: category.type == 'income' ? Colors.green : Colors.red,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            // Will be implemented in task 012
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
}
