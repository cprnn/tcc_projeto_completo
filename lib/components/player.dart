// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'dart:collection';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:rabbits_challenge/components/checkpoint.dart';
import 'package:rabbits_challenge/components/collision_block.dart';
import 'package:rabbits_challenge/components/custom_hitbox.dart';
import 'package:rabbits_challenge/components/experience.dart';
import 'package:rabbits_challenge/components/fruit.dart';
import 'package:rabbits_challenge/components/saw.dart';
import 'package:rabbits_challenge/components/score.dart';
import 'package:rabbits_challenge/components/utils.dart';
import 'package:rabbits_challenge/end_level/end_level_widget.dart';
import 'package:rabbits_challenge/rabbits_challenge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PlayerState {
  idle,
  running,
  doubleJump,
  falling,
  jumping,
  wallJumping,
  hit,
  appearing,
  disappearing,
}

enum Direction { left, right }

class Player extends SpriteAnimationGroupComponent
    with HasGameRef<RabbitsChallenge>, KeyboardHandler, CollisionCallbacks {
  String character;
  late final BuildContext context;

  Player({
    required this.context,
    super.position,
    this.character = 'Snow',
  }) : super();

  final Experience experience = Experience();
  final Queue<String> commandQueue = Queue<String>();
  bool isExecutingCommand = false;

  late final SpriteAnimation idleAnimation;
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation doubleJumpAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation wallJumpAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation disappearingAnimation;

  bool isMoving = false;

//Frame animation time
  final double stepTime = 0.05;

//Gravity and fall controls
  final double _gravity = 9.8;
  final double _jumpForce = 330;
  final double _terminalVelocity = 300;

//Controls the direction of the movement of the player
  double horizontalMovement = 0;
  double moveSpeed = 100;
  Vector2 velocity = Vector2.zero();
  double moveDistance =
      32.0; //Exactly the width of the widget of the block painted as the ground in Tiled - 32 pixels

//Checks collisions and if jumped
  bool isOnGround = false;
  bool hasJumped = false;
  bool gotHit = false;
  bool reachedCheckpoint = false;

//Player's starting spawpoint
  Vector2 startingPosition = Vector2.zero();

  List<CollisionBlock> collisionBlocks = [];

  CustomHitbox hitbox = CustomHitbox(
    offsetX: 10,
    offsetY: 4,
    width: 14,
    height: 28,
  );

  Direction _direction = Direction.right;

  void queueCommand(String command) {
    commandQueue.add(command);
    if (!isExecutingCommand) {
      executeNextCommand();
    }
  }

  Future<void> executeNextCommand() async {
    if (commandQueue.isEmpty) {
      isExecutingCommand = false;
      return;
    }
    isExecutingCommand = true;
    String command = commandQueue.removeFirst();

    switch (command) {
      case 'move_right':
        await _movePlayerOverTime(1);
        break;
      case 'move_left':
        await _movePlayerOverTime(-1);
        break;
    }

    await Future.delayed(const Duration(milliseconds: 100));

    _checkFruitCollisions();
    executeNextCommand();
    //print('Executing command: $command');
  }

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();

    startingPosition = Vector2(position.x, position.y);
    add(RectangleHitbox(
      position: Vector2(hitbox.offsetX, hitbox.offsetY),
      size: Vector2(hitbox.width, hitbox.height),
    ));

    html.window.onMessage.listen((event) {
      if (event.data['action'] == 'change_direction') {
        if (event.data['direction'] == 'left') {
          _direction = Direction.left;
        } else if (event.data['direction'] == 'right') {
          _direction = Direction.right;
        }
      } else if (event.data['action'] == 'move_player') {
        if (event.data['direction'] == 'left') {
          commandQueue.add('move_left');
        } else if (event.data['direction'] == 'right') {
          commandQueue.add('move_right');
        }
        if (!isExecutingCommand) {
          executeNextCommand();
        }
      } else if (event.data['action'] == 'jump') {
        hasJumped = true;
      }
    });

    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (!gotHit && !reachedCheckpoint) {
      _updatePlayerState();
      _updatePlayerPosition(dt);

      _checkHorizontalCollisions();
      _applyGravity(dt);
      _checkVerticalCollisions();

      _checkFruitCollisions();
    }
    super.update(dt);
  }

//player movement - moves the player for only 32 pixels
  void _movePlayer(double distance) {
    position.x += distance;
  }

  Future<void> _movePlayerOverTime(double direction) async {
    _movePlayer(moveDistance * direction);
    await Future.delayed(const Duration(milliseconds: 10));
  }

/*  Future<void> _movePlayerOverTime(double direction) async {
    double stepTime = 0.01; // Smoothness of the movement
    int steps = (moveDistance / moveSpeed / stepTime).toInt();
    double stepDistance = moveDistance / steps;

    for (int i = 0; i < steps; i++) {
      _movePlayer(stepDistance * direction);
      await Future.delayed(const Duration(milliseconds: 10 /*(stepTime * 1000).toInt()*/));
    }
    // Ensure the player is moved exactly _moveDistance pixels
    position.x = (position.x + direction * moveDistance).roundToDouble();
  }
*/
  Score score = Score();

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (!reachedCheckpoint) {
      if (other is Fruit) {
        other.collidedWithPlayer();
        score.incrementFruitsCollected();
        experience.incrementExperincePerFruitCollected();
      }
      if (other is Saw) _respawn();
      if (other is Checkpoint) {
        experience.incrementExperiencePerLevelFinished();
        _reachedCheckpoint(context);
      }
      super.onCollisionStart(intersectionPoints, other);
    }
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation('Idle', 11);
    runningAnimation = _spriteAnimation('Run', 12);
    fallingAnimation = _spriteAnimation('Fall', 1);
    jumpingAnimation = _spriteAnimation('Jump', 1);
    hitAnimation = _spriteAnimation('Hit', 6)
      ..loop = false; //cascade operator, read more about it
    appearingAnimation = _specialSpriteAnimation('Appearing', 7);
    disappearingAnimation = _specialSpriteAnimation('Disappearing', 7);

    // idleAnimation = _spriteAnimation('Idle', 4); //add more frames to bunny on image
    // runningAnimation = _spriteAnimation('Run', 4); //add more frames to bunny on image
    // doubleJumpAnimation = _spriteAnimation('Double Jump', 6);
    // wallJumpAnimation = _spriteAnimation('Wall Jump', 5);

    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      //PlayerState.doubleJump: doubleJumpAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.jumping: jumpingAnimation,
      //PlayerState.wallJumping: wallJumpAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
      PlayerState.disappearing: disappearingAnimation,
    };

    current = PlayerState.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$character/$state (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: 0.05,
        textureSize: Vector2.all(32),
      ),
    );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$state (96x96).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: 0.05,
        textureSize: Vector2.all(96),
        loop: false,
      ),
    );
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;

    if (_direction == Direction.left && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (_direction == Direction.right && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }
    //if player is falling
    if (velocity.y > 0) {
      playerState = PlayerState.falling; //0 can be changed to _gravity
    }

    //if player is jumping
    if (velocity.y < 0) playerState = PlayerState.jumping;

    //If moving, set running animation
    if (velocity.x > 0 || velocity.x < 0) playerState = PlayerState.running;

    current = playerState;
  }

  void _updatePlayerPosition(double dt) {
    if (!gotHit && !reachedCheckpoint) {
      if (velocity.x != 0) {
        position.x += velocity.x * dt;
      }
      if (hasJumped) {
        _playerJump(dt);
        hasJumped = false;
      }
    }
  }

/*  void _updatePlayerPosition(double dt) {
    if (!gotHit && !reachedCheckpoint) {
      horizontalMovement = 0;
      if (_direction == Direction.left) {
        horizontalMovement = -moveSpeed;
      } else if (_direction == Direction.right) {
        horizontalMovement = moveSpeed;
      }
      velocity.x = horizontalMovement;
      position.x += velocity.x * dt;
    }
  }
*/

  void _playerJump(double dt) {
    if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isOnGround = false;
    hasJumped = false;
  }

  void _checkHorizontalCollisions() {
    for (final block in collisionBlocks) {
      if (!block.isPlatform) {
        //handles all the blocks different from the platforms
        if (checkCollision(this, block)) {
          if (velocity.x > 0) {
            velocity.x = 0;
            position.x = block.x - hitbox.offsetX - hitbox.width;
            break;
          }
          if (velocity.x < 0) {
            velocity.x = 0;
            position.x = block.x + block.width + hitbox.width + hitbox.offsetX;
            break;
          }
        }
      }
    }
  }

  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    position.y += velocity.y * dt;
  }

  void _checkFruitCollisions() {
    for (final component in gameRef.children) {
      if (component is Fruit && !component.collected) {
        // Print positions for debugging
        print(
            'Player position: $position, Fruit position: ${component.position}');
        if (checkCollision(this, component)) {
          print('Fruit collected!'); // Debug print
          component.collidedWithPlayer();
        }
      }
    }
  }

  void _checkVerticalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPlatform) {
        //handles the platforms
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isOnGround = true;
            break;
          }
        }
      } else {
        //handles the blocks
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            //falling
            velocity.y = 0; //if the code stops here, you have quicksand!
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isOnGround = true; //for the jumping
            break;
          }
          if (velocity.y < 0) {
            //going up
            velocity.y = 0;
            position.y = block.y + block.height - hitbox.offsetY;
            break;
          }
        }
      }
    }
  }

  void _respawn() async {
    if (game.playSounds) FlameAudio.play('hit.wav', volume: game.soundVolume);
    const canMoveDuration = Duration(milliseconds: 50);
    gotHit = true;
    current = PlayerState.hit;

    await animationTicker?.completed; //used to check if the animation finished
    animationTicker?.reset();

    scale.x = 1;
    position = startingPosition - Vector2.all(32);
    current = PlayerState.appearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    velocity = Vector2.zero();
    position = startingPosition;
    _updatePlayerState();
    Future.delayed(canMoveDuration, () => gotHit = false);
  }

//todo: quero colocar aqui a lógica que sobe para o banco o valor de xp que foi obtido na fase
  void _reachedCheckpoint(BuildContext context) async {
    if (game.playSounds) {
      FlameAudio.play('disappear.wav', volume: game.soundVolume);
    }
    reachedCheckpoint = true;
    if (scale.x > 0) {
      position = position - Vector2.all(32);
    } else if (scale.x < 0) {
      position = position + Vector2(32, -32);
    }

    current = PlayerState.disappearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    reachedCheckpoint = false;
    position = Vector2.all(-640);

    await updateUserExperience();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EndLevelWidget(
          experience: experience
              .getExperienceCollected()
              .toString(), // Pass total experience
          currentLevelExperience:
              getCurrentLevelExperience(), // Pass current level experience
        ),
      ),
    );

/*    const waitToChangeLevelDuration = Duration(seconds: 3);
    Future.delayed(
        waitToChangeLevelDuration,
        // ignore: use_build_context_synchronously
        () => game.loadNextLevel(context)); 
        */
  }

  Future<void> updateUserExperience() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    String? userId = currentUser?.uid;

    if (userId == null) {
      //print("No user is currently logged in.");
      return;
    }

    double totalExperience = experience.getExperienceCollected();
    print("Total Experience to add: $totalExperience");

    DocumentReference userDocRef =
        FirebaseFirestore.instance.collection('user').doc(userId);

    try {
      // Check if the user document exists before starting the transaction
      DocumentSnapshot userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        //print("User  document does not exist.");
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userDocRef);
        if (userDoc.exists) {
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          double currentExperience = userData?['experience'] ?? 0.0;
          double newExperience = currentExperience + totalExperience;
          transaction.update(userDocRef, {'experience': newExperience});
          print("Experience updated in Firestore.");
        } else {
          //print("User  document does not exist during transaction.");
        }
      });
    } catch (e) {
      print("Transaction failed: ${e.toString()}");
      print("Stack trace: ${StackTrace.current}");
    }
  }

  double getCurrentLevelExperience() {
    return experience.getExperienceCollected();
  }

  void resetExperience() {
    experience.resetExperience();
  }

  void resetPosition() {
    position = startingPosition;
  }
}
