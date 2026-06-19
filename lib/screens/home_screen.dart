import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'collection_screen.dart';
import 'identify_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _collectionKey = 0;

  void _onPlantSaved() {
    setState(() {
      _index = 0;
      _collectionKey++;
    });
  }

  Future<void> _openSettings() async {
    final demoLoaded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (demoLoaded == true) {
      setState(() => _collectionKey++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.forest, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'BeMyForager',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'settings'.tr(),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          KeyedSubtree(
            key: ValueKey(_collectionKey),
            child: const CollectionScreen(),
          ),
          IdentifyScreen(onPlantSaved: _onPlantSaved),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: Colors.green[100],
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.collections_bookmark_outlined),
            selectedIcon: const Icon(Icons.collections_bookmark),
            label: 'collection_tab'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.yard_outlined),
            selectedIcon: const Icon(Icons.yard),
            label: 'identify_tab'.tr(),
          ),
        ],
      ),
    );
  }
}
