import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:slotgame/menu.dart';

void startMiniGame(
    BuildContext context, int betAmount, Function(int) onWinCallback) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SpaceShooterGame(
        currentBet: betAmount,
        onComplete: (int miniGameWin) {
          onWinCallback(miniGameWin);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
}

class SpaceShooterGame extends StatefulWidget {
  final int currentBet;
  final Function(int) onComplete;

  const SpaceShooterGame({
    Key? key,
    required this.currentBet,
    required this.onComplete,
  }) : super(key: key);

  @override
  _SpaceShooterGameState createState() => _SpaceShooterGameState();
}

class _SpaceShooterGameState extends State<SpaceShooterGame>
    with TickerProviderStateMixin {
  late Player player;
  List<Projectile> projectiles = [];
  List<Enemy> enemies = [];
  List<PowerUp> powerUps = [];
  List<Explosion> explosions = [];
  List<Star> stars = [];
  bool isPlaying = false;
  int score = 0;
  int combo = 1;
  Timer? gameLoop;
  int waveCount = 1;
  int health = 100;
  int maxHealth = 100;
  int shield = 0;
  int maxShield = 50;
  double fireRate = 1.0;
  bool canFire = true;
  bool isPaused = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupGame();
    _initializeAnimations();
    _initializeStars();
    Future.delayed(Duration.zero, _startGame);
  }

  void _setupGame() {
    player = Player(
      position: Offset(0.5, 0.85),
      size: const Size(50, 50),
    );
  }

  void _initializeStars() {
    for (int i = 0; i < 50; i++) {
      stars.add(Star(
        position: Offset(
          math.Random().nextDouble(),
          math.Random().nextDouble(),
        ),
        speed: 0.001 + math.Random().nextDouble() * 0.003,
        size: 1 + math.Random().nextDouble() * 2,
      ));
    }
  }

  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
      isPaused = false;
      score = 0;
      health = maxHealth;
      shield = 0;
      enemies.clear();
      projectiles.clear();
      powerUps.clear();
      explosions.clear();
      waveCount = 1;
      combo = 1;
      fireRate = 1.0;
    });

    gameLoop =
        Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
    _spawnWave();
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        gameLoop?.cancel();
      } else {
        gameLoop =
            Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
      }
    });
  }

  void _update() {
    if (!isPlaying || isPaused) return;

    setState(() {
      // Update stars
      for (var star in stars) {
        star.position = star.position.translate(0, star.speed);
        if (star.position.dy > 1.0) {
          star.position = Offset(math.Random().nextDouble(), 0);
        }
      }

      // Update projectiles
      projectiles.removeWhere((projectile) {
        projectile.position = projectile.position.translate(0, -0.015);
        return projectile.position.dy < -0.1;
      });

      // Update enemies with improved patterns
      for (var enemy in enemies.toList()) {
        enemy.update();

        if (_checkCollision(
            enemy.position, enemy.size, player.position, player.size)) {
          _damagePlayer(20);
          enemies.remove(enemy);
          _addExplosion(enemy.position);
          continue;
        }

        for (var projectile in projectiles.toList()) {
          if (_checkCollision(enemy.position, enemy.size, projectile.position,
              projectile.size)) {
            score += 10 * combo * widget.currentBet;
            combo = math.min(combo + 1, 5);
            enemies.remove(enemy);
            projectiles.remove(projectile);
            _addExplosion(enemy.position);

            if (math.Random().nextDouble() < 0.15) {
              _spawnPowerUp(enemy.position);
            }
            break;
          }
        }
      }

      // Update power-ups with improved movement
      for (var powerUp in powerUps.toList()) {
        powerUp.position = powerUp.position.translate(
          math.sin(powerUp.time * 3) * 0.003,
          0.005,
        );
        powerUp.time += 0.05;

        if (_checkCollision(
            powerUp.position, powerUp.size, player.position, player.size)) {
          _collectPowerUp(powerUp);
          powerUps.remove(powerUp);
        }
      }

      // Update explosions
      explosions.removeWhere((explosion) => explosion.isDone());

      // Spawn new wave if needed
      if (enemies.isEmpty) {
        waveCount++;
        _spawnWave();
      }
    });
  }

  void _spawnWave() {
    final enemyCount = 5 + waveCount;
    final spacing = 1.0 / (enemyCount + 1);

    for (var i = 0; i < enemyCount; i++) {
      final enemy = Enemy(
        position: Offset((i + 1) * spacing, -0.1),
        size: const Size(40, 40),
        pattern: _getRandomPattern(),
        speed: 0.003 + (waveCount * 0.0005),
      );
      enemies.add(enemy);
    }
  }

  MovementPattern _getRandomPattern() {
    final patterns = [
      MovementPattern.zigzag,
      MovementPattern.sine,
      MovementPattern.spiral,
      MovementPattern.straight
    ];
    return patterns[math.Random().nextInt(patterns.length)];
  }

  void _shoot() {
    if (!canFire || !isPlaying || isPaused) return;

    setState(() {
      final projectileSize = const Size(8, 20);
      projectiles.add(Projectile(
        position: player.position.translate(-0.02, -0.05),
        size: projectileSize,
      ));
      projectiles.add(Projectile(
        position: player.position.translate(0.02, -0.05),
        size: projectileSize,
      ));

      canFire = false;
    });

    HapticFeedback.lightImpact();
    Future.delayed(Duration(milliseconds: (500 / fireRate).round()), () {
      if (mounted) setState(() => canFire = true);
    });
  }

  void _spawnPowerUp(Offset position) {
    powerUps.add(PowerUp(
      position: position,
      size: const Size(30, 30),
      type:
          PowerUpType.values[math.Random().nextInt(PowerUpType.values.length)],
      time: 0,
    ));
  }

  void _collectPowerUp(PowerUp powerUp) {
    setState(() {
      switch (powerUp.type) {
        case PowerUpType.health:
          health = math.min(health + 25, maxHealth);
          break;
        case PowerUpType.shield:
          shield = math.min(shield + 25, maxShield);
          break;
        case PowerUpType.fireRate:
          fireRate = math.min(fireRate + 0.2, 2.0);
          break;
        case PowerUpType.score:
          score += 50 * widget.currentBet;
          break;
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _addExplosion(Offset position) {
    explosions.add(Explosion(position: position));
    _shakeController.forward(from: 0);
  }

  void _damagePlayer(int damage) {
    setState(() {
      if (shield > 0) {
        shield = math.max(0, shield - damage);
      } else {
        health = math.max(0, health - damage);
        if (health <= 0) {
          _gameOver();
        }
      }
      combo = 1;
    });
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _gameOver() {
    isPlaying = false;
    gameLoop?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Game Over!',
          style: TextStyle(color: Colors.white, fontSize: 28),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Win: \$${score}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Wave: $waveCount',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (score >= widget.currentBet * 50)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Text(
                      '+3 Free Spins',
                      style: TextStyle(color: Colors.amber, fontSize: 20),
                    ),
                    Text(
                      '2x Multiplier',
                      style: TextStyle(color: Colors.amber, fontSize: 20),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onComplete(score);
              // MenuScreen'e yönlendir
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MenuScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              backgroundColor: Colors.green.withOpacity(0.2),
            ),
            child: const Text(
              'COLLECT',
              style: TextStyle(color: Colors.green, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  bool _checkCollision(Offset pos1, Size size1, Offset pos2, Size size2) {
    return (pos1.dx - pos2.dx).abs() < (size1.width + size2.width) / 200 &&
        (pos1.dy - pos2.dy).abs() < (size1.height + size2.height) / 200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _shoot(),
        onPanUpdate: (details) {
          if (!isPlaying || isPaused) return;
          setState(() {
            final size = MediaQuery.of(context).size;
            player.position = Offset(
              (player.position.dx + details.delta.dx / size.width)
                  .clamp(0.1, 0.9),
              (player.position.dy + details.delta.dy / size.height)
                  .clamp(0.1, 0.9),
            );
          });
        },
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                math.sin(_shakeController.value * math.pi * 8) *
                    _shakeAnimation.value,
                0,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.purple.shade900,
                          Colors.blue.shade900,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: GamePainter(
                      player: player,
                      projectiles: projectiles,
                      enemies: enemies,
                      powerUps: powerUps,
                      explosions: explosions,
                      stars: stars,
                      pulseValue: _pulseAnimation.value,
                    ),
                    size: Size.infinite,
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on,
                                        color: Colors.amber, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '\$${score}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (combo > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${combo}x',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: _togglePause,
                                icon: Icon(
                                  isPaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: health / maxHealth,
                                        backgroundColor:
                                            Colors.red.withOpacity(0.3),
                                        color: Colors.red,
                                        minHeight: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (shield > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.shield,
                                        color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: shield / maxShield,
                                          backgroundColor:
                                              Colors.blue.withOpacity(0.3),
                                          color: Colors.blue,
                                          minHeight: 8,
                                        ),
                                      ),
                                    ),
                                  ],
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
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class Player {
  Offset position;
  final Size size;
  Player({required this.position, required this.size});
}

class Projectile {
  Offset position;
  final Size size;
  Projectile({required this.position, required this.size});
}

class Enemy {
  Offset position;
  final Size size;
  final MovementPattern pattern;
  final double speed;
  double time = 0;
  double baseX = 0;

  Enemy({
    required this.position,
    required this.size,
    required this.pattern,
    required this.speed,
  }) {
    baseX = position.dx;
  }

  void update() {
    time += 0.05;
    switch (pattern) {
      case MovementPattern.zigzag:
        position = Offset(
          baseX + math.sin(time * 2) * 0.2,
          position.dy + speed,
        );
        break;
      case MovementPattern.sine:
        position = Offset(
          baseX + math.sin(time) * 0.3,
          position.dy + speed * 0.8,
        );
        break;
      case MovementPattern.spiral:
        position = Offset(
          baseX + math.sin(time * 1.5) * (0.2 + time * 0.01),
          position.dy + speed,
        );
        break;
      case MovementPattern.straight:
        position = Offset(position.dx, position.dy + speed * 1.2);
        break;
    }
  }
}

enum MovementPattern { zigzag, sine, spiral, straight }

enum PowerUpType { health, shield, fireRate, score }

class PowerUp {
  Offset position;
  final Size size;
  final PowerUpType type;
  double time;

  PowerUp({
    required this.position,
    required this.size,
    required this.type,
    required this.time,
  });
}

class Star {
  Offset position;
  final double speed;
  final double size;

  Star({
    required this.position,
    required this.speed,
    required this.size,
  });
}

class Explosion {
  final Offset position;
  double size = 0;
  double maxSize = 40;
  double growthRate = 2.5;

  Explosion({required this.position});

  void update() {
    size = math.min(size + growthRate, maxSize);
  }

  bool isDone() {
    return size >= maxSize;
  }
}

class GamePainter extends CustomPainter {
  final Player player;
  final List<Projectile> projectiles;
  final List<Enemy> enemies;
  final List<PowerUp> powerUps;
  final List<Explosion> explosions;
  final List<Star> stars;
  final double pulseValue;

  GamePainter({
    required this.player,
    required this.projectiles,
    required this.enemies,
    required this.powerUps,
    required this.explosions,
    required this.stars,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    final starPaint = Paint()..color = Colors.white;
    for (var star in stars) {
      canvas.drawCircle(
        Offset(star.position.dx * size.width, star.position.dy * size.height),
        star.size,
        starPaint,
      );
    }

    // Draw player with gradient
    final playerGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.blue.shade400, Colors.blue.shade600],
    );

    final playerRect = Rect.fromCenter(
      center: Offset(
          player.position.dx * size.width, player.position.dy * size.height),
      width: player.size.width,
      height: player.size.height,
    );

    final playerPaint = Paint()
      ..shader = playerGradient.createShader(playerRect)
      ..style = PaintingStyle.fill;

    final playerPath = Path()
      ..moveTo(playerRect.left, playerRect.bottom)
      ..lineTo(playerRect.center.dx, playerRect.top)
      ..lineTo(playerRect.right, playerRect.bottom)
      ..close();

    canvas.drawPath(playerPath, playerPaint);

    // Draw projectiles with glow effect
    final projectilePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

    for (var projectile in projectiles) {
      final projectileRect = Rect.fromCenter(
        center: Offset(
          projectile.position.dx * size.width,
          projectile.position.dy * size.height,
        ),
        width: projectile.size.width,
        height: projectile.size.height,
      );
      canvas.drawRect(projectileRect, projectilePaint);
    }

    // Draw enemies with custom shapes
    for (var enemy in enemies) {
      final enemyCenter = Offset(
        enemy.position.dx * size.width,
        enemy.position.dy * size.height,
      );

      final enemyPath = Path();
      switch (enemy.pattern) {
        case MovementPattern.zigzag:
          _drawZigzagEnemy(enemyPath, enemyCenter, enemy.size);
          break;
        case MovementPattern.sine:
          _drawSineEnemy(enemyPath, enemyCenter, enemy.size);
          break;
        case MovementPattern.spiral:
          _drawSpiralEnemy(enemyPath, enemyCenter, enemy.size);
          break;
        case MovementPattern.straight:
          _drawStraightEnemy(enemyPath, enemyCenter, enemy.size);
          break;
      }

      final enemyGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [Colors.red.shade400, Colors.red.shade800],
      );

      final enemyRect = Rect.fromCenter(
        center: enemyCenter,
        width: enemy.size.width,
        height: enemy.size.height,
      );

      final enemyPaint = Paint()
        ..shader = enemyGradient.createShader(enemyRect)
        ..style = PaintingStyle.fill;

      canvas.drawPath(enemyPath, enemyPaint);
    }

    // Draw power-ups with glowing effects
    for (var powerUp in powerUps) {
      final powerUpPaint = Paint()
        ..color = _getPowerUpColor(powerUp.type)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * pulseValue
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

      final powerUpCenter = Offset(
        powerUp.position.dx * size.width,
        powerUp.position.dy * size.height,
      );

      canvas.drawCircle(
        powerUpCenter,
        powerUp.size.width / 2 * pulseValue,
        powerUpPaint,
      );

      // Draw power-up icon
      final iconPaint = Paint()
        ..color = _getPowerUpColor(powerUp.type).withOpacity(0.8)
        ..style = PaintingStyle.fill;

      _drawPowerUpIcon(canvas, powerUpCenter, powerUp.type, iconPaint,
          powerUp.size.width / 3);
    }

    // Draw explosions with gradient
    for (var explosion in explosions) {
      final explosionGradient = RadialGradient(
        colors: [
          Colors.yellow.withOpacity(0.8),
          Colors.orange.withOpacity(0.6),
          Colors.red.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );

      final explosionRect = Rect.fromCenter(
        center: Offset(
          explosion.position.dx * size.width,
          explosion.position.dy * size.height,
        ),
        width: explosion.size * 2,
        height: explosion.size * 2,
      );

      final explosionPaint = Paint()
        ..shader = explosionGradient.createShader(explosionRect);

      canvas.drawCircle(
        explosionRect.center,
        explosion.size,
        explosionPaint,
      );
    }
  }

  void _drawZigzagEnemy(Path path, Offset center, Size size) {
    path.moveTo(center.dx - size.width / 2, center.dy + size.height / 2);
    path.lineTo(center.dx, center.dy - size.height / 2);
    path.lineTo(center.dx + size.width / 2, center.dy + size.height / 2);
    path.close();
  }

  void _drawSineEnemy(Path path, Offset center, Size size) {
    path.addOval(Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    ));
  }

  void _drawSpiralEnemy(Path path, Offset center, Size size) {
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
  }

  void _drawStraightEnemy(Path path, Offset center, Size size) {
    path.moveTo(center.dx - size.width / 2, center.dy - size.height / 2);
    path.lineTo(center.dx + size.width / 2, center.dy - size.height / 2);
    path.lineTo(center.dx, center.dy + size.height / 2);
    path.close();
  }

  void _drawPowerUpIcon(Canvas canvas, Offset center, PowerUpType type,
      Paint paint, double size) {
    final iconPath = Path();
    switch (type) {
      case PowerUpType.health:
        // Heart shape
        iconPath.moveTo(center.dx, center.dy - size);
        iconPath.cubicTo(
          center.dx + size,
          center.dy - size,
          center.dx + size,
          center.dy + size / 2,
          center.dx,
          center.dy + size,
        );
        iconPath.cubicTo(
          center.dx - size,
          center.dy + size / 2,
          center.dx - size,
          center.dy - size,
          center.dx,
          center.dy - size,
        );
        break;
      case PowerUpType.shield:
        // Shield shape
        iconPath.addOval(Rect.fromCenter(
          center: center,
          width: size * 1.5,
          height: size * 2,
        ));
        break;
      case PowerUpType.fireRate:
        // Lightning bolt
        iconPath.moveTo(center.dx - size / 2, center.dy - size);
        iconPath.lineTo(center.dx + size / 2, center.dy);
        iconPath.lineTo(center.dx - size / 2, center.dy + size);
        break;
      case PowerUpType.score:
        // Star shape
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + i * math.pi * 2 / 5;
          final x = center.dx + math.cos(angle) * size;
          final y = center.dy + math.sin(angle) * size;
          if (i == 0) {
            iconPath.moveTo(x, y);
          } else {
            iconPath.lineTo(x, y);
          }
        }
        iconPath.close();
        break;
    }
    canvas.drawPath(iconPath, paint);
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.health:
        return Colors.red;
      case PowerUpType.shield:
        return Colors.blue;
      case PowerUpType.fireRate:
        return Colors.yellow;
      case PowerUpType.score:
        return Colors.green;
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
