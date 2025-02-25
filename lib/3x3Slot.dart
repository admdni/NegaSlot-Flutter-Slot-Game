import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:slotgame/TreasureHuntGame.dart';

// Ödeme çizgileri için pozisyon sınıfı
class Position {
  final int x;
  final int y;
  Position(this.x, this.y);
}

// Slot sembolü sınıfı
class SlotSymbol {
  final String name;
  final String imageUrl;
  final int value;
  final String placeholder;
  final bool isWild;
  final bool isScatter;
  final bool isBonus;
  final Color color;

  SlotSymbol({
    required this.name,
    required this.imageUrl,
    required this.value,
    required this.placeholder,
    this.isWild = false,
    this.isScatter = false,
    this.isBonus = false,
    required this.color,
  });
}

// Bonus oyun kartı sınıfı
class BonusCard {
  final String symbol;
  final int value;
  bool isMatched;

  BonusCard({
    required this.symbol,
    this.value = 0,
    this.isMatched = false,
  });
}

// Mini oyun sınıfı
class MiniGame extends StatefulWidget {
  final Function(int) onComplete;
  final int currentBet;

  const MiniGame({
    Key? key,
    required this.onComplete,
    required this.currentBet,
  }) : super(key: key);

  @override
  _MiniGameState createState() => _MiniGameState();
}

class _MiniGameState extends State<MiniGame> {
  List<bool> boxes = List.generate(9, (_) => false);
  int attempts = 3;
  int totalWin = 0;

  void _handleTap(int index) {
    if (attempts <= 0 || boxes[index]) return;

    setState(() {
      boxes[index] = true;
      attempts--;

      // Random ödül
      int reward = math.Random().nextInt(5) + 1;
      totalWin += reward * widget.currentBet;

      if (attempts <= 0) {
        Future.delayed(const Duration(seconds: 2), () {
          widget.onComplete(totalWin);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pick a Box! Attempts left: $attempts',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _handleTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: boxes[index] ? Colors.amber : Colors.purple,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Center(
                    child: Text(
                      boxes[index] ? '${(index + 1) * widget.currentBet}' : '?',
                      style: TextStyle(
                        fontSize: 24,
                        color: boxes[index] ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Total Win: \$$totalWin',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SlotGameScreen extends StatefulWidget {
  final int columns;
  final String mode;

  const SlotGameScreen({
    Key? key,
    required this.columns,
    required this.mode,
  }) : super(key: key);

  @override
  State<SlotGameScreen> createState() => _SlotGameScreenState();
}

class _SlotGameScreenState extends State<SlotGameScreen>
    with TickerProviderStateMixin {
  static const int VISIBLE_SYMBOLS = 3;
  late int SYMBOLS_PER_REEL;

  // Animasyon kontrolcüleri
  late List<AnimationController> _reelControllers;
  late List<Animation<double>> _spinAnimations;
  late AnimationController _shakeController;
  late AnimationController _glowController;

  // Oyun durumu
  bool isSpinning = false;
  bool isMiniGameActive = false;
  int balance = 1000;
  int betAmount = 10;
  int multiplier = 1;
  int freeSpins = 0;
  int jackpot = 10000;
  bool isMiniGameUnlocked = false;
  int consecutiveWins = 0;

  // Slot sembolleri
  final List<SlotSymbol> symbols = [
    SlotSymbol(
      name: 'Wild',
      imageUrl: 'assets/wild.png',
      value: 500,
      placeholder: '★',
      isWild: true,
      color: Colors.purple,
    ),
    SlotSymbol(
      name: 'Scatter',
      imageUrl: 'assets/scatter.png',
      value: 200,
      placeholder: '⚡',
      isScatter: true,
      color: Colors.amber,
    ),
    SlotSymbol(
      name: 'Bonus',
      imageUrl: 'assets/bonus.png',
      value: 150,
      placeholder: '🎁',
      isBonus: true,
      color: Colors.green,
    ),
    SlotSymbol(
      name: 'Seven',
      imageUrl: 'assets/seven.png',
      value: 100,
      placeholder: '7',
      color: Colors.red,
    ),
    SlotSymbol(
      name: 'Diamond',
      imageUrl: 'assets/diamond.png',
      value: 75,
      placeholder: '💎',
      color: Colors.blue,
    ),
    SlotSymbol(
      name: 'Bell',
      imageUrl: 'assets/bell.png',
      value: 50,
      placeholder: '🔔',
      color: Colors.orange,
    ),
  ];

  late List<List<SlotSymbol>> reelStates;
  List<List<bool>> highlightedPositions = [];
  List<List<Position>> paylines = [];

  @override
  void initState() {
    super.initState();
    SYMBOLS_PER_REEL = VISIBLE_SYMBOLS;
    _initializeGame();
    _setupAnimations();
  }

  void _initializeGame() {
    _initializeReels();
    _initializePaylines();
    _initializeHighlights();
  }

  void _setupAnimations() {
    _reelControllers = List.generate(
      widget.columns,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2000 + (index * 300)),
      ),
    );

    _spinAnimations = _reelControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
    }).toList();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _initializeReels() {
    reelStates = List.generate(
      widget.columns,
      (_) => List.generate(SYMBOLS_PER_REEL, (_) => _getRandomSymbol()),
    );
  }

  void _initializePaylines() {
    // Yatay çizgiler
    for (int i = 0; i < VISIBLE_SYMBOLS; i++) {
      paylines.add(List.generate(widget.columns, (j) => Position(j, i)));
    }

    // Çapraz çizgiler
    if (widget.columns == 3) {
      paylines.add([
        Position(0, 0),
        Position(1, 1),
        Position(2, 2),
      ]);
      paylines.add([
        Position(0, 2),
        Position(1, 1),
        Position(2, 0),
      ]);
    }
  }

  void _initializeHighlights() {
    highlightedPositions = List.generate(
      widget.columns,
      (_) => List.generate(VISIBLE_SYMBOLS, (_) => false),
    );
  }

  SlotSymbol _getRandomSymbol() {
    double random = math.Random().nextDouble();

    // Özel sembollerin çıkma olasılıkları
    if (random < 0.03) return symbols[0]; // Wild %3
    if (random < 0.06) return symbols[1]; // Scatter %3
    if (random < 0.09) return symbols[2]; // Bonus %3

    return symbols.sublist(3)[math.Random().nextInt(symbols.length - 3)];
  }

  Future<void> _spin() async {
    if (isSpinning || (balance < betAmount && freeSpins <= 0)) return;

    setState(() {
      isSpinning = true;
      if (freeSpins > 0) {
        freeSpins--;
      } else {
        balance -= betAmount;
      }
    });

    _resetHighlights();

    // Makara dönüş animasyonları
    for (int i = 0; i < widget.columns; i++) {
      _reelControllers[i].reset();
      _shakeController.forward(from: 0.0);

      await Future.delayed(Duration(milliseconds: 200 * i));
      _reelControllers[i].forward();

      // Bulanık efekt için hızlı sembol değişimi
      for (int j = 0; j < 15; j++) {
        await Future.delayed(const Duration(milliseconds: 50));
        setState(() {
          reelStates[i] =
              List.generate(SYMBOLS_PER_REEL, (_) => _getRandomSymbol());
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _checkWins();

    setState(() {
      isSpinning = false;
    });
  }

  void _checkWins() {
    bool hasWin = false;
    int totalWin = 0;
    int bonusCount = 0;
    int scatterCount = 0;
    Set<Position> winningPositions = {};

    // Ödeme çizgilerini kontrol et
    for (var payline in paylines) {
      String firstSymbol = reelStates[payline[0].x][payline[0].y].name;
      bool isWinningLine = true;
      bool hasWild = false;

      for (int i = 1; i < payline.length; i++) {
        var currentSymbol = reelStates[payline[i].x][payline[i].y];
        if (currentSymbol.isWild) {
          hasWild = true;
          continue;
        }
        if (currentSymbol.name != firstSymbol &&
            !reelStates[payline[0].x][payline[0].y].isWild) {
          isWinningLine = false;
          break;
        }
      }

      if (hasWin) {
        setState(() {
          balance += totalWin;
          consecutiveWins++;

          // 3 ardışık kazançtan sonra mini oyunu aç
          if (consecutiveWins >= 3 && !isMiniGameUnlocked) {
            isMiniGameUnlocked = true;
            _showMiniGameDialog();
          }
        });
        _showWinDialog(totalWin);
      } else {
        consecutiveWins = 0;
      }

      if (isWinningLine) {
        hasWin = true;
        var baseValue = reelStates[payline[0].x][payline[0].y].value;
        var lineWin = baseValue * betAmount * multiplier;

        if (hasWild) lineWin = (lineWin * 2).toInt(); // Wild bonus

        totalWin += lineWin;
        payline.forEach((pos) => winningPositions.add(pos));
      }
    }

    // Özel sembol kontrolleri
    for (var reel in reelStates) {
      for (var symbol in reel) {
        if (symbol.isBonus) bonusCount++;
        if (symbol.isScatter) scatterCount++;
      }
    }

    // Scatter ödülleri
    if (scatterCount >= 3) {
      hasWin = true;
      int scatterWin = betAmount * scatterCount * 5;
      totalWin += scatterWin;
      freeSpins += scatterCount;
      _showBonusDialog('FREE SPINS!', 'You won $scatterCount free spins!');
    }

    // Bonus oyunu tetikleme
    if (bonusCount >= 3) {
      startMiniGame(context, betAmount, (int miniGameWin) {
        setState(() {
          balance += miniGameWin;
          isMiniGameUnlocked = false;

          if (miniGameWin >= betAmount * 50) {
            multiplier = 2;
            freeSpins += 3;
          }
        });

        _showMiniGameResultDialog(miniGameWin);
      });
    }

    if (hasWin) {
      setState(() {
        balance += totalWin;
        consecutiveWins++;

        // Jackpot kontrolü
        if (consecutiveWins >= 5) {
          totalWin += jackpot;
          _showJackpotDialog();
          consecutiveWins = 0;
        }

        // Kazanan pozisyonları vurgula
        winningPositions.forEach((pos) {
          highlightedPositions[pos.x][pos.y] = true;
        });
      });

      _showWinDialog(totalWin);
    } else {
      consecutiveWins = 0;
    }
  }

  void _showMiniGameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          '🎮 BONUS GAME UNLOCKED! 🎮',
          style: TextStyle(color: Colors.amber),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You\'ve unlocked the Treasure Hunt bonus game!\nCollect treasures to win big rewards!',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'PLAY LATER',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    startMiniGame(context, betAmount, (int miniGameWin) {
                      setState(() {
                        balance += miniGameWin;
                        isMiniGameUnlocked = false;

                        if (miniGameWin >= betAmount * 50) {
                          multiplier = 2;
                          freeSpins += 3;
                        }
                      });

                      _showMiniGameResultDialog(miniGameWin);
                    });
                  },
                  child: const Text(
                    'PLAY NOW',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void startMiniGame(
      BuildContext context, int betAmount, Function onGameComplete) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SpaceShooterGame(
          currentBet: betAmount,
          onComplete: (int miniGameWin) {
            onGameComplete(miniGameWin);
            Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showMiniGameResultDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Mini Game Rewards',
          style: TextStyle(color: Colors.amber),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You won \$$amount!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'BONUS REWARDS:',
              style: TextStyle(color: Colors.amber),
            ),
            const Text(
              '• 2x Multiplier for next spins\n• 3 Free Spins',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'AWESOME!',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  void _showWinDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BIG WIN!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '\ $amount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (consecutiveWins > 1)
                Text(
                  '$consecutiveWins Consecutive Wins!',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'COLLECT',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJackpotDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'JACKPOT!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '\ $jackpot',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'AMAZING!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBonusDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetHighlights() {
    setState(() {
      highlightedPositions = List.generate(
        widget.columns,
        (_) => List.generate(VISIBLE_SYMBOLS, (_) => false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.mode),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stats Display
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCard('Balance', '\ $balance'),
                _buildInfoCard('Bet', '\ $betAmount'),
                _buildInfoCard('Free Spins', '$freeSpins'),
              ],
            ),
          ),

          // Jackpot Display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'JACKPOT: \ $jackpot',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Slot Machine
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Column(
                children: [
                  // Machine Header
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.amber),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.casino, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'MEGA SLOT',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reels
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        widget.columns,
                        (index) => _buildReel(index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBetButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (!isSpinning && betAmount > 10) {
                      setState(() => betAmount -= 10);
                    }
                  },
                ),
                _buildSpinButton(),
                _buildBetButton(
                  icon: Icons.add,
                  onPressed: () {
                    if (!isSpinning && betAmount < balance) {
                      setState(() => betAmount += 10);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReel(int reelIndex) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: AnimatedBuilder(
          animation: _spinAnimations[reelIndex],
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(VISIBLE_SYMBOLS, (symbolIndex) {
                return Container(
                  height: 70,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: highlightedPositions[reelIndex][symbolIndex]
                          ? Colors.amber
                          : Colors.amber.withOpacity(0.2),
                      width:
                          highlightedPositions[reelIndex][symbolIndex] ? 2 : 1,
                    ),
                    boxShadow: highlightedPositions[reelIndex][symbolIndex]
                        ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      reelStates[reelIndex][symbolIndex].placeholder,
                      style: TextStyle(
                        fontSize: 36,
                        color: highlightedPositions[reelIndex][symbolIndex]
                            ? Colors.amber
                            : reelStates[reelIndex][symbolIndex].color,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.amber.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    return GestureDetector(
      onTap: isSpinning ? null : _spin,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isSpinning
                ? [Colors.grey, Colors.grey.shade700]
                : [Colors.amber, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSpinning ? Colors.grey : Colors.amber).withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isSpinning ? Icons.refresh : Icons.play_arrow,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBetButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black87,
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: Icon(
          icon,
          color: Colors.amber,
          size: 30,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _reelControllers) {
      controller.dispose();
    }
    _shakeController.dispose();
    _glowController.dispose();
    super.dispose();
  }
}
