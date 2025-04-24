import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Racing Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class PowerUp {
  final Offset position;
  final PowerUpType type;
  PowerUp(this.position, this.type);
}

enum PowerUpType {
  shield,
  speedBoost,
  extraLife
}

class RoadStripe {
  double y;
  RoadStripe(this.y);
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const carWidth = 50.0;
  static const carHeight = 80.0;
  static const obstacleWidth = 60.0;
  static const obstacleHeight = 60.0;
  static const powerUpSize = 30.0;
  static const laneWidth = 80.0;
   static const roadColor = Color(0xFF303030);
  static const grassColor = Color(0xFF1B5E20);
  static const stripeWidth = 10.0;
  static const stripeHeight = 50.0;
  static const stripeGap = 20.0;
  
  double playerX = 0.0;
  double playerY = 0.0;
  int score = 0;
  int highScore = 0;
  int lives = 3;
  List<Offset> obstacles = [];
  List<PowerUp> powerUps = [];
  List<RoadStripe> roadStripes = [];
  bool isPlaying = false;
  bool hasShield = false;
  Timer? gameTimer;
  Timer? shieldTimer;
  Timer? speedBoostTimer;
  double gameSpeed = 5.0;
  double baseGameSpeed = 5.0;
  final random = Random();

  @override
  void initState() {
    super.initState();
    loadHighScore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initializeRoadStripes();
    startGame();
  }

  Future<void> loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        highScore = prefs.getInt('highScore') ?? 0;
      });
    } catch (e) {
      setState(() {
        highScore = 0;
      });
    }
  }

  Future<void> saveHighScore() async {
    if (score > highScore) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('highScore', score);
        setState(() {
          highScore = score;
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void initializeRoadStripes() {
    roadStripes.clear();
    double y = 0;
    final screenHeight = MediaQuery.of(context).size.height;
    while (y < screenHeight) {
      roadStripes.add(RoadStripe(y));
      y += 100;
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    shieldTimer?.cancel();
    speedBoostTimer?.cancel();
    super.dispose();
  }

  void startGame() {
    setState(() {
      score = 0;
      lives = 3;
      obstacles.clear();
      powerUps.clear();
      isPlaying = true;
      hasShield = false;
      gameSpeed = baseGameSpeed;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final screenWidth = MediaQuery.of(context).size.width;
        playerX = (screenWidth - carWidth) / 2;
        playerY = MediaQuery.of(context).size.height - carHeight - 20;
        addNewObstacle();
      });
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      updateGame();
    });
  }

  void updateGame() {
    if (!isPlaying) return;

    setState(() {
      // Update road stripes
      for (var stripe in roadStripes) {
        stripe.y += gameSpeed;
        if (stripe.y > MediaQuery.of(context).size.height) {
          stripe.y = -100;
        }
      }

      // Move and check obstacles
      for (int i = obstacles.length - 1; i >= 0; i--) {
        final newY = obstacles[i].dy + gameSpeed;
        obstacles[i] = Offset(obstacles[i].dx, newY);
        
        if (!hasShield && checkCollision(obstacles[i])) {
          handleCollision();
          obstacles.removeAt(i);
          return;
        }
        
        if (newY > MediaQuery.of(context).size.height) {
          obstacles.removeAt(i);
          score += 10;
          if (score % 100 == 0) {
            gameSpeed = baseGameSpeed + (score / 100) * 0.5;
          }
        }
      }

      // Move power-ups
      for (int i = powerUps.length - 1; i >= 0; i--) {
        var newPos = Offset(powerUps[i].position.dx, powerUps[i].position.dy + gameSpeed);
        powerUps[i] = PowerUp(newPos, powerUps[i].type);
        
        if (checkPowerUpCollision(powerUps[i])) {
          activatePowerUp(powerUps[i].type);
          powerUps.removeAt(i);
        } else if (newPos.dy > MediaQuery.of(context).size.height) {
          powerUps.removeAt(i);
        }
      }

      // Generate new obstacles
      if (obstacles.isEmpty || 
          (obstacles.last.dy > obstacleHeight * 2 && 
           random.nextDouble() < 0.03)) {
        addNewObstacle();
      }

      // Generate power-ups
      if (random.nextDouble() < 0.005) {
        addPowerUp();
      }
    });
  }

  void addNewObstacle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final laneCount = 3;
    final lane = random.nextInt(laneCount);
    
    final totalLanesWidth = laneCount * laneWidth;
    final startX = (screenWidth - totalLanesWidth) / 2;
    final x = startX + (lane * laneWidth) + (laneWidth - obstacleWidth) / 2;
    
    final minSpacing = obstacleHeight * 3;
    final randomOffset = random.nextDouble() * obstacleHeight;
    final y = obstacles.isEmpty ? -obstacleHeight : 
             min(-obstacleHeight, obstacles.last.dy - minSpacing - randomOffset);
    
    obstacles.add(Offset(x, y));
  }

  void addPowerUp() {
    final screenWidth = MediaQuery.of(context).size.width;
    final x = random.nextDouble() * (screenWidth - powerUpSize);
    final type = PowerUpType.values[random.nextInt(PowerUpType.values.length)];
    powerUps.add(PowerUp(Offset(x, -powerUpSize), type));
  }

  bool checkCollision(Offset obstacle) {
    final collisionMargin = 5.0;
    return (playerX + collisionMargin < obstacle.dx + obstacleWidth - collisionMargin &&
            playerX + carWidth - collisionMargin > obstacle.dx + collisionMargin &&
            playerY + collisionMargin < obstacle.dy + obstacleHeight - collisionMargin &&
            playerY + carHeight - collisionMargin > obstacle.dy + collisionMargin);
  }

  bool checkPowerUpCollision(PowerUp powerUp) {
    return (playerX < powerUp.position.dx + powerUpSize &&
            playerX + carWidth > powerUp.position.dx &&
            playerY < powerUp.position.dy + powerUpSize &&
            playerY + carHeight > powerUp.position.dy);
  }

  void handleCollision() {
    lives--;
    if (lives <= 0) {
      gameOver();
    } 
  }

  void activatePowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        hasShield = true;
        shieldTimer?.cancel();
        shieldTimer = Timer(const Duration(seconds: 5), () {
          setState(() => hasShield = false);
        });
        break;
      case PowerUpType.speedBoost:
        gameSpeed = baseGameSpeed * 0.5;
        speedBoostTimer?.cancel();
        speedBoostTimer = Timer(const Duration(seconds: 3), () {
          setState(() => gameSpeed = baseGameSpeed);
        });
        break;
      case PowerUpType.extraLife:
        if (lives < 3) lives++;
        break;
    }
  }

  void gameOver() {
    setState(() {
      isPlaying = false;
    });
    gameTimer?.cancel();
    saveHighScore();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score'),
            Text('High Score: $highScore'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              startGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!isPlaying) return;
    
    setState(() {
      playerX += details.delta.dx;
      final screenWidth = MediaQuery.of(context).size.width;
      playerX = playerX.clamp(0, screenWidth - carWidth);
    });
  }

  IconData _getPowerUpIcon(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Icons.shield;
      case PowerUpType.speedBoost:
        return Icons.speed;
      case PowerUpType.extraLife:
        return Icons.favorite;
    }
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Colors.blue;
      case PowerUpType.speedBoost:
        return Colors.green;
      case PowerUpType.extraLife:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
     final screenWidth = MediaQuery.of(context).size.width;
    final roadWidth = screenWidth * 0.8; // Road takes 80% of screen width
    final grassWidth = (screenWidth - roadWidth) / 2;
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: _onPanUpdate,
        child: Container(
          color: Colors.grey[900],
          child: Stack(
            children: [

                // Background (sky)
            Container(
              color: Colors.lightBlue[900],
            ),

            // Left grass
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: grassWidth,
              child: Container(
                color: grassColor,
                child: _buildGrassPattern(),
              ),
            ),

            // Right grass
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: grassWidth,
              child: Container(
                color: grassColor,
                child: _buildGrassPattern(),
              ),
            ),

              // Road
            Positioned(
              left: grassWidth,
              right: grassWidth,
              top: 0,
              bottom: 0,
              child: Container(
                color: roadColor,
                child: Stack(
                  children: [
                    // Road stripes
                    ...roadStripes.map((stripe) => Positioned(
                      left: (roadWidth - stripeWidth) / 2,
                      top: stripe.y,
                      child: Container(
                        width: stripeWidth,
                        height: stripeHeight,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),

               // Score panel
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Lives
                    Row(
                      children: List.generate(3, (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.favorite,
                          color: index < lives ? Colors.red : Colors.grey[800],
                          size: 30,
                        ),
                      )),
                    ),
                    // Score
                    Text(
                      'Score: $score\nBest: $highScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ), 

              

               // Player's car
            Positioned(
              left: playerX,
              top: playerY,
              child: Transform.scale(
                scale: 1.2,
                child: Container(
                  width: carWidth,
                  height: carHeight,
                  decoration: BoxDecoration(
                    color: hasShield ? Colors.blue.withOpacity(0.7) : Colors.red[700],
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        hasShield ? Colors.blue.withOpacity(0.7) : Colors.red[700]!,
                        hasShield ? Colors.blue.withOpacity(0.9) : Colors.red[900]!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (hasShield ? Colors.blue : Colors.red[700])!.withOpacity(0.5),
                        blurRadius: hasShield ? 15 : 10,
                        spreadRadius: hasShield ? 5 : 2,
                      ),
                        const BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Car body details
                      Center(
                        child: Container(
                          width: carWidth * 0.8,
                          height: carHeight * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Wheels
                      ...[-1, 1].map((offset) => Positioned(
                        left: offset == -1 ? -5 : carWidth - 10,
                        top: carHeight * 0.15,
                        child: Container(
                          width: 15,
                          height: carHeight * 0.7,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),

               // Obstacles with improved design
            ...obstacles.map((obstacle) => Positioned(
              left: obstacle.dx,
              top: obstacle.dy,
              child: Container(
                width: obstacleWidth,
                height: obstacleHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 40,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.orange[700]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            )), 

               // Power-ups with improved design
            ...powerUps.map((powerUp) => Positioned(
              left: powerUp.position.dx,
              top: powerUp.position.dy,
              child: Container(
                width: powerUpSize,
                height: powerUpSize,
                decoration: BoxDecoration(
                  color: _getPowerUpColor(powerUp.type),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getPowerUpColor(powerUp.type).withOpacity(0.7),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getPowerUpIcon(powerUp.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )),
          ],
        ),
      ),
    )
    );
  }
Widget _buildGrassPattern() {
    return CustomPaint(
      painter: GrassPatternPainter(),
    );
  }
}

// Add this new class for grass pattern
class GrassPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[900]!
      ..style = PaintingStyle.fill;

    final random = Random(42); // Fixed seed for consistent pattern
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}