/// Tree Progress Widget - Visualize character climbing tree
/// Shows multiple players' characters progressing up the tree in real-time

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TreeProgressData {
  final int participantId;
  final String nickname;
  final String characterName;
  final int correctAnswers;
  final int totalQuestions;
  final Color playerColor;

  TreeProgressData({
    required this.participantId,
    required this.nickname,
    required this.characterName,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.playerColor,
  });

  // Position on tree: 0 (bottom) to 1 (top)
  double get treeProgress => correctAnswers / totalQuestions;
}

class TreeProgressWidget extends StatefulWidget {
  final List<TreeProgressData> players;
  final Duration animationDuration;

  const TreeProgressWidget({
    super.key,
    required this.players,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<TreeProgressWidget> createState() => _TreeProgressWidgetState();
}

class _TreeProgressWidgetState extends State<TreeProgressWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    try {
      _setupAnimations();
    } catch (e) {
      _hasError = true;
    }
  }

  void _setupAnimations() {
    _controllers = List.generate(
      widget.players.length,
      (index) => AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      ),
    );

    _animations = List.generate(
      widget.players.length,
      (index) => Tween<double>(
        begin: 0,
        end: widget.players[index].treeProgress,
      ).animate(
        CurvedAnimation(parent: _controllers[index], curve: Curves.easeInOutQuad),
      ),
    );

    // Start animations
    for (var controller in _controllers) {
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(TreeProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update animations when players data changes
    if (oldWidget.players.length != widget.players.length) {
      // Reset controllers if player count changed
      for (var controller in _controllers) {
        controller.dispose();
      }
      _setupAnimations();
    } else {
      // Update animation targets if data changed
      for (int i = 0; i < _animations.length && i < widget.players.length; i++) {
        final newProgress = widget.players[i].treeProgress;

        // Build a new tween from the current animation value to the new target
        final currentValue = (_animations[i].value).clamp(0.0, 1.0);
        _animations[i] = Tween<double>(begin: currentValue, end: newProgress).animate(
          CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOutQuad),
        );

        // Restart controller to animate from current -> new
        _controllers[i].forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.blue[100],
        child: Center(
          child: Text(
            'Loading tree progress...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue[900],
            ),
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    
    return Container(
      decoration: const BoxDecoration(
        // Professional forest/nature gradient background
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A5F), // Deep sky blue
            Color(0xFF2D5A3D), // Forest green
            Color(0xFF3D7A2D), // Medium green
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background: Layered forest effect with multiple gradients
          // Far background (sky)
          Container(
            height: screenSize.height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[900]!.withValues(alpha: 0.9),
                  Colors.blue[800]!.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),

          // Mid background: Tree canopy silhouette
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green[800]!.withValues(alpha: 0.6),
                    Colors.green[700]!.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Near background: Darker green gradient for depth
          Positioned(
            top: screenSize.height * 0.35,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green[700]!.withValues(alpha: 0.3),
                    Colors.green[900]!.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // Main tree: Center positioned with proper size
          Positioned(
            top: screenSize.height * 0.05,
            left: screenSize.width * 0.5 - 120, // Center horizontally
            right: screenSize.width * 0.5 - 120,
            child: Column(
              children: [
                // Try to load tree asset, fall back to custom paint
                SizedBox(
                  width: 240,
                  height: screenSize.height * 0.7,
                  child: Image.asset(
                    'tema/tree/Tree.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => 
                      _buildFallbackTree(
                        Size(240, screenSize.height * 0.7),
                      ),
                  ),
                ),
              ],
            ),
          ),

          // Animated characters on tree (with better visibility)
          ..._buildCharacterLayers(screenSize),

          // Ground/Base with grass
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green[700]!.withValues(alpha: 0.6),
                    Colors.green[900]!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackTree(Size screenSize) {
    return CustomPaint(
      size: Size(150, screenSize.height * 0.8),
      painter: TreePainter(),
    );
  }

  List<Widget> _buildCharacterLayers(Size screenSize) {
    if (widget.players.isEmpty) {
      return [];
    }
    
    return List.generate(
      widget.players.length,
      (index) {
        final player = widget.players[index];
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            // Calculate position on tree (0 = bottom, 1 = top)
            final normalizedProgress = _animations[index].value.clamp(0.0, 1.0);
            
            // Position from bottom (accounting for ground height of ~60)
            final yPosition = screenSize.height * (1 - normalizedProgress - 0.15);
            
            // Slight horizontal variation for each character
            final xOffset = (index % 2 == 0 ? -1 : 1) * (60 + (index * 15).toDouble());

            return Positioned(
              left: screenSize.width / 2 + xOffset,
              top: yPosition,
              child: _buildCharacterCard(player),
            );
          },
        );
      },
    );
  }

  Widget _buildCharacterCard(TreeProgressData player) {
    return Column(
      children: [
        // Player name label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: player.playerColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
          ),
          child: Text(
            player.nickname,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        
        // Character avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: player.playerColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: SvgPicture.asset(
              'karakter/${player.characterName}.svg',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              placeholderBuilder: (context) => Icon(
                Icons.pets,
                color: player.playerColor,
                size: 24,
              ),
            ),
          ),
        ),
        
        // Score indicator
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.amber[300],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '${player.correctAnswers}/${player.totalQuestions}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.amber[800],
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for tree silhouette
class TreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown[900]!
      ..style = PaintingStyle.fill;

    final trunkPaint = Paint()
      ..color = Colors.brown[800]!
      ..style = PaintingStyle.fill;

    // Draw tree crown (circular shape at top)
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.2),
      size.width * 0.4,
      paint,
    );

    // Draw tree trunk
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - 15,
        size.height * 0.35,
        30,
        size.height * 0.65,
      ),
      trunkPaint,
    );

    // Optional: Add some branches
    final branchPaint = Paint()
      ..color = Colors.brown[700]!
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final yPos = size.height * 0.35 + (i * 20);
      canvas.drawLine(
        Offset(size.width / 2, yPos),
        Offset(size.width / 2 - 30, yPos - 10),
        branchPaint,
      );
      canvas.drawLine(
        Offset(size.width / 2, yPos),
        Offset(size.width / 2 + 30, yPos - 10),
        branchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
