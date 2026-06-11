import 'package:flutter/material.dart';
import 'collection_screen.dart';
import 'identify_screen.dart';
import '../services/demo_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _collectionKey = 0;
  bool _demoLoading = false;

  void _onPlantSaved() {
    setState(() {
      _index = 0;
      _collectionKey++;
    });
  }

  Future<void> _loadDemo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load demo plants?'),
        content: const Text(
          'Adds 5 sample plants with various locations and dates to your collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _demoLoading = true);
    try {
      await DemoDataService().populate();
    } finally {
      if (mounted) {
        setState(() {
          _demoLoading = false;
          _index = 0;
          _collectionKey++;
        });
      }
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
          if (_demoLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.science_outlined, color: Colors.white),
              tooltip: 'Load demo plants',
              onPressed: _loadDemo,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.yard_outlined),
            selectedIcon: Icon(Icons.yard),
            label: 'Identify',
          ),
        ],
      ),
    );
  }
}
