import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'item_details_page.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final List<Map<String, dynamic>> items = [
    {
      'name': 'Plastic',
      'image': 'assets/image/Plastic.png',
      'points': 10,
      'details': 'Includes plastic bottles and containers used daily.',
      'benefits': 'Reduces plastic waste, saves energy, and protects the environment from pollution.',
    },
    {
      'name': 'Metal',
      'image': 'assets/image/cans.png',
      'points': 20,
      'details': 'Includes metal beverage cans like aluminum and steel.',
      'benefits': 'Reduces mining, conserves natural resources, and lowers carbon emissions.',
    },
    {
      'name': 'Cardboard',
      'image': 'assets/image/cardboard.jpg.webp',
      'points': 8,
      'details': 'Includes cardboard boxes and packaging materials.',
      'benefits': 'Reduces tree cutting, saves water and energy, and minimizes landfill waste.',
    },
    {
      'name': 'Paper',
      'image': 'assets/image/paper.png.webp',
      'points': 5,
      'details': 'Includes regular paper such as books, magazines, and office papers.',
      'benefits': 'Preserves forests, reduces water and energy consumption, and decreases pollution.',
    },
    {
      'name': 'Glass',
      'image': 'assets/image/glass.jpeg',
      'points': 15,
      'details': 'Includes recyclable glass bottles and containers.',
      'benefits': 'Reduces sand extraction, saves energy, and minimizes non-biodegradable waste.',
    },
    {
      'name': 'Trash',
      'image': 'assets/image/trash-png.webp',
      'points': 2,
      'details': 'Includes general non-recyclable waste like food scraps.',
      'benefits': 'Reduces pollution, improves waste management, and maintains environmental cleanliness.',
    },
  ];

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Plastic':
        return Icons.local_drink;
      case 'Metal':
        return Icons.hardware;
      case 'Cardboard':
        return Icons.archive;
      case 'Paper':
        return Icons.description;
      case 'Glass':
        return Icons.local_bar;
      case 'Trash':
        return Icons.delete;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Items to Dispose",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF2E2E2E),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'Select the type of waste to learn more about recycling',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: AnimationLimiter(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    return AnimationConfiguration.staggeredGrid(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      columnCount: 2,
                      child: ScaleAnimation(
                        child: FadeInAnimation(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ItemDetailsPage(
                                    name: items[index]['name'],
                                    image: items[index]['image'],
                                    points: items[index]['points'],
                                    details: items[index]['details'],
                                    benefits: items[index]['benefits'],
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 10,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              color: Colors.grey[800],
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[850]!,
                                      Colors.grey[900]!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(color: Colors.white12, width: 2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Image.asset(
                                            items[index]['image']!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey,
                                                child: const Center(
                                                  child: Text(
                                                    'Image failed to load',
                                                    style: TextStyle(color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getIconForCategory(items[index]['name']!),
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            items[index]['name']!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black26,
                                                  offset: Offset(1, 1),
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  itemCount: items.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}