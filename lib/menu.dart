import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:slotgame/3x3Slot.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  late AnimationController _coinController;
  late AnimationController _lightController;
  final List<GameMode> _gameModes = [
    GameMode(
        title: '3x3 CLASSIC',
        description: 'Traditional slot experience',
        columns: 3),
    GameMode(
        title: '6x6 MEGA', description: 'More reels, more wins!', columns: 6),
    GameMode(
        title: '9x9 ULTIMATE',
        description: 'Maximum winning potential!',
        columns: 9),
  ];

  @override
  void initState() {
    super.initState();
    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C1F63),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Exit Game',
            style: TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Do you want to exit the game?',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => exit(0),
              child: const Text('Yes', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C1F63),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'How to Play',
            style: TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoSection(
                    'Game Modes',
                    '• 3x3 Classic: Traditional slot experience\n'
                        '• 6x6 Mega: Enhanced gameplay with more reels\n'
                        '• 9x9 Ultimate: Maximum winning potential with massive grid'),
                const Divider(color: Colors.white24),
                _infoSection(
                    'How to Win',
                    '• Match symbols horizontally, vertically, or diagonally\n'
                        '• Higher bet multipliers increase potential winnings\n'
                        '• Special symbols trigger bonus features and free spins'),
                const Divider(color: Colors.white24),
                _infoSection(
                    'Features',
                    '• Auto-spin functionality\n'
                        '• Progressive jackpots\n'
                        '• Bonus mini-games\n'
                        '• Daily rewards and achievements'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Got it!', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _rateApp() async {
    const url = 'https://apps.apple.com/app/id6740924818';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  void dispose() {
    _coinController.dispose();
    _lightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // Casino lights background effect
          ...List.generate(20, (index) {
            return Positioned(
              left: math.Random().nextDouble() *
                  MediaQuery.of(context).size.width,
              top: math.Random().nextDouble() *
                  MediaQuery.of(context).size.height,
              child: AnimatedBuilder(
                animation: _lightController,
                builder: (context, child) {
                  return Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber
                              .withOpacity(_lightController.value * 0.5),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Animated logo
                AnimatedBuilder(
                  animation: _coinController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _coinController.value * 2 * math.pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child:
                              Icon(Icons.casino, size: 60, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFA500),
                      Color(0xFFFFD700)
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'NEGA SLOTS',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Game modes
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _gameModes.length,
                    itemBuilder: (context, index) {
                      return GameModeCard(
                        gameMode: _gameModes[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      SlotGameScreen(
                                columns: _gameModes[index].columns,
                                mode: _gameModes[index].title,
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircleButton(
                        icon: Icons.exit_to_app,
                        label: 'EXIT',
                        onTap: _showExitDialog,
                      ),
                      _buildCircleButton(
                        icon: Icons.star,
                        label: 'RATE US',
                        onTap: _rateApp,
                      ),
                      _buildCircleButton(
                        icon: Icons.help_outline,
                        label: 'HELP',
                        onTap: _showGameInfo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2C1F63), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class GameMode {
  final String title;
  final String description;
  final int columns;

  GameMode({
    required this.title,
    required this.description,
    required this.columns,
  });
}

class GameModeCard extends StatelessWidget {
  final GameMode gameMode;
  final VoidCallback onTap;

  const GameModeCard({
    Key? key,
    required this.gameMode,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1F63), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${gameMode.columns}x${gameMode.columns}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameMode.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gameMode.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
