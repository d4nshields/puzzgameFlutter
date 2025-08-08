import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:puzzgame_flutter/presentation/theme/cozy_puzzle_theme.dart';

/// Puzzle Library Screen - Teaser view of upcoming beach puzzles
/// Uses coverflow-style presentation for visual appeal
class PuzzleLibraryScreen extends StatefulWidget {
  const PuzzleLibraryScreen({super.key});

  @override
  State<PuzzleLibraryScreen> createState() => _PuzzleLibraryScreenState();
}

class _PuzzleLibraryScreenState extends State<PuzzleLibraryScreen> {
  int _currentIndex = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  // Library images from assets/library - Beach Puzzles collection
  final List<PuzzlePreview> _puzzlePreviews = const [
    PuzzlePreview(
      title: "Artistic Still Life",
      assetPath: "assets/library/artistic_still_life_of_weathered_driftwood_colorf.jpeg",
      difficulty: "Medium",
      pieces: 150,
    ),
    PuzzlePreview(
      title: "Beach Picnic",
      assetPath: "assets/library/bright_blanket_on_sand_with_picnic_basket_sliced_.jpeg",
      difficulty: "Easy",
      pieces: 100,
    ),
    PuzzlePreview(
      title: "Cartoon Beach",
      assetPath: "assets/library/cartoonish_beach_scene_with_dozens_of_tiny_colorf.jpeg",
      difficulty: "Hard",
      pieces: 300,
    ),
    PuzzlePreview(
      title: "Whimsical Beach",
      assetPath: "assets/library/cheerful_whimsical_beach_scene_with_a_giant_purpl.jpeg",
      difficulty: "Medium",
      pieces: 200,
    ),
    PuzzlePreview(
      title: "Coastal Painting",
      assetPath: "assets/library/classic_coastal_oil_painting_of_a_weathered_woode.jpeg",
      difficulty: "Hard",
      pieces: 400,
    ),
    PuzzlePreview(
      title: "Beach Market",
      assetPath: "assets/library/colorful_open-air_beach_market_with_stalls_sellin.jpeg",
      difficulty: "Hard",
      pieces: 350,
    ),
    PuzzlePreview(
      title: "Dancing Kites",
      assetPath: "assets/library/dozens_of_colorful_kites_dancing_above_a_breezy_b.jpeg",
      difficulty: "Medium",
      pieces: 200,
    ),
    PuzzlePreview(
      title: "Fantasy Cove",
      assetPath: "assets/library/fantasy_beach_scene_with_a_rocky_cove_luminous_me.jpeg",
      difficulty: "Hard",
      pieces: 500,
    ),
    PuzzlePreview(
      title: "Giant Beach Balls",
      assetPath: "assets/library/fantasy_beach_with_dozens_of_giant_colorful_beach.jpeg",
      difficulty: "Medium",
      pieces: 250,
    ),
    PuzzlePreview(
      title: "Beach Bonfire",
      assetPath: "assets/library/friends_around_a_glowing_beach_bonfire_reflection.jpeg",
      difficulty: "Medium",
      pieces: 175,
    ),
    PuzzlePreview(
      title: "Sandcastle City",
      assetPath: "assets/library/giant_elaborate_sandcastle_city_with_tiny_flags_a.jpeg",
      difficulty: "Hard",
      pieces: 400,
    ),
    PuzzlePreview(
      title: "Tide Pool Life",
      assetPath: "assets/library/hyper-detailed_tide_pool_teeming_with_sea_anemone.jpeg",
      difficulty: "Expert",
      pieces: 750,
    ),
    PuzzlePreview(
      title: "Impressionist Beach",
      assetPath: "assets/library/impressionist_painting_of_a_sunny_beach_with_colo.jpeg",
      difficulty: "Medium",
      pieces: 200,
    ),
    PuzzlePreview(
      title: "Driftwood Arch",
      assetPath: "assets/library/large_natural_arch_made_of_intertwined_driftwood_.jpeg",
      difficulty: "Hard",
      pieces: 300,
    ),
    PuzzlePreview(
      title: "Spiral Mandala",
      assetPath: "assets/library/overhead_shot_of_a_beach_with_a_massive_spiral_ma.jpeg",
      difficulty: "Expert",
      pieces: 600,
    ),
    PuzzlePreview(
      title: "Foamy Waves",
      assetPath: "assets/library/overhead_view_of_intricate_foamy_waves_creating_l.jpeg",
      difficulty: "Hard",
      pieces: 350,
    ),
    PuzzlePreview(
      title: "Colorful Pebbles",
      assetPath: "assets/library/overhead_view_of_smooth_colorful_pebbles_at_the_e.jpeg",
      difficulty: "Medium",
      pieces: 225,
    ),
    PuzzlePreview(
      title: "Retro Postcard",
      assetPath: "assets/library/retro_1950s_beach_postcard_illustration_bright_co.jpeg",
      difficulty: "Easy",
      pieces: 125,
    ),
    PuzzlePreview(
      title: "Seashell Village",
      assetPath: "assets/library/tiny_whimsical_seaside_village_made_from_seashell.jpeg",
      difficulty: "Hard",
      pieces: 400,
    ),
    PuzzlePreview(
      title: "Crooked Lighthouse",
      assetPath: "assets/library/whimsical_seaside_scene_with_a_crooked_red-and-wh.jpeg",
      difficulty: "Medium",
      pieces: 175,
    ),
    PuzzlePreview(
      title: "Seaside Carnival",
      assetPath: "assets/library/whimsical_vintage_seaside_carnival_colorful_Ferri.jpeg",
      difficulty: "Hard",
      pieces: 450,
    ),
    PuzzlePreview(
      title: "Happy Sea Turtles",
      assetPath: "assets/library/whimsical_watercolor_illustration_of_happy_sea_tu.jpeg",
      difficulty: "Easy",
      pieces: 100,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CozyPuzzleTheme.linenWhite,
              CozyPuzzleTheme.warmSand.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and title
              _buildHeader(context),
              
              const SizedBox(height: 20),
              
              // Collection title and description
              _buildCollectionInfo(),
              
              const SizedBox(height: 20),
              
              // Coverflow carousel
              Expanded(
                child: _buildCoverflowCarousel(),
              ),
              
              // Puzzle details card
              _buildPuzzleDetails(),
              
              const SizedBox(height: 24),
              
              // Coming soon notice
              _buildComingSoonNotice(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          Tooltip(
            message: 'Back',
            child: CozyPuzzleTheme.createThemedButton(
              text: '',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.arrow_back,
              isPrimary: false,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Text(
              'Puzzle Library',
              style: CozyPuzzleTheme.headingMedium,
            ),
          ),
          
          // Collection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CozyPuzzleTheme.goldenAmber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: CozyPuzzleTheme.goldenAmber.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              'Preview',
              style: CozyPuzzleTheme.bodySmall.copyWith(
                color: CozyPuzzleTheme.goldenAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CozyPuzzleTheme.createThemedContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CozyPuzzleTheme.forestMist,
                        CozyPuzzleTheme.forestMist.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.water,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beach Puzzles',
                        style: CozyPuzzleTheme.headingSmall,
                      ),
                      Text(
                        '${_puzzlePreviews.length} puzzles coming soon',
                        style: CozyPuzzleTheme.bodyMedium.copyWith(
                          color: CozyPuzzleTheme.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverflowCarousel() {
    return Column(
      children: [
        Expanded(
          child: CarouselSlider.builder(
            carouselController: _controller,
            itemCount: _puzzlePreviews.length,
            itemBuilder: (context, index, realIndex) {
              final puzzle = _puzzlePreviews[index];
              final isCenter = index == _currentIndex;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                  horizontal: isCenter ? 8 : 16,
                  vertical: isCenter ? 20 : 40,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isCenter
                      ? [
                          BoxShadow(
                            color: CozyPuzzleTheme.richCharcoal.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: CozyPuzzleTheme.richCharcoal.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    puzzle.assetPath,
                    fit: BoxFit.cover,
                    semanticLabel: puzzle.title,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: CozyPuzzleTheme.warmSand,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: CozyPuzzleTheme.slateGray,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Preview Not Available',
                              style: CozyPuzzleTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            options: CarouselOptions(
              viewportFraction: 0.65,
              enlargeCenterPage: true,
              enlargeFactor: 0.25,
              enableInfiniteScroll: true,
              autoPlay: false,
              initialPage: 0,
              scrollDirection: Axis.horizontal,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ),
        
        // Page indicators
        const SizedBox(height: 16),
        _buildPageIndicators(),
      ],
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _puzzlePreviews.asMap().entries.map((entry) {
        final isActive = entry.key == _currentIndex;
        return GestureDetector(
          onTap: () => _controller.jumpToPage(entry.key),
          child: Container(
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive 
                  ? CozyPuzzleTheme.goldenAmber 
                  : CozyPuzzleTheme.slateGray.withOpacity(0.3),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPuzzleDetails() {
    final currentPuzzle = _puzzlePreviews[_currentIndex];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CozyPuzzleTheme.createThemedContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDetailItem(
              icon: Icons.extension,
              label: 'Pieces',
              value: '${currentPuzzle.pieces}',
            ),
            _buildDetailItem(
              icon: Icons.signal_cellular_alt,
              label: 'Difficulty',
              value: currentPuzzle.difficulty,
            ),
            _buildDetailItem(
              icon: Icons.collections,
              label: 'Collection',
              value: 'Beach',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CozyPuzzleTheme.forestMist.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: CozyPuzzleTheme.forestMist,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: CozyPuzzleTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: CozyPuzzleTheme.bodySmall.copyWith(
            color: CozyPuzzleTheme.slateGray,
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CozyPuzzleTheme.createThemedContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.schedule,
              size: 48,
              color: CozyPuzzleTheme.terracotta,
            ),
            const SizedBox(height: 12),
            Text(
              'Coming Soon!',
              style: CozyPuzzleTheme.headingSmall.copyWith(
                color: CozyPuzzleTheme.terracotta,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'These beautiful beach puzzles will be available in the full version. Register for early access to be the first to solve them!',
              style: CozyPuzzleTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for puzzle preview information
class PuzzlePreview {
  final String title;
  final String assetPath;
  final String difficulty;
  final int pieces;

  const PuzzlePreview({
    required this.title,
    required this.assetPath,
    required this.difficulty,
    required this.pieces,
  });
}
