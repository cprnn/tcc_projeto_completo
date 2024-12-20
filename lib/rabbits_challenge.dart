import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:rabbits_challenge/components/level.dart';
import 'package:rabbits_challenge/components/player.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RabbitsChallenge extends FlameGame
    with HasKeyboardHandlerComponents, DragCallbacks, HasCollisionDetection {
  @override
  Color backgroundColor() => const Color(0xFF211F30);
  late CameraComponent cam;
  late Player player;
  late JoystickComponent joystick;
  bool showJoystick = false;
  bool playSounds = true;
  double soundVolume = 1.0;

  final String levelName;

  //List<String> levelNames = [
  //  'Level-01',
  //  'Level-03',
  // 'Level-02',
  //];
  int currentLevelIndex = 0;
  Level? currentLevel;
  double currentLevelExperience = 0.0;
  double totalExperience = 0.0;

  RabbitsChallenge(BuildContext context, this.levelName) {
    _initializePlayer(context);
  }

  Future<void> _initializePlayer(BuildContext context) async {
    String character = 'Smoke'; // Default character

    User? currentUser = FirebaseAuth.instance.currentUser;
    String? userId = currentUser?.uid;

    if (userId == null) {
      //print("No user is currently logged in.");
      return;
    }

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('user').doc(userId).get();

    if (userDoc.exists) {
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? bunnyType = userData?['type_bunny'];

      switch (bunnyType) {
        case 'Branco':
          character = 'Snow';
          break;
        case 'Caramelo':
          character = 'Caramel';
          break;
        case 'Cinza':
          character = 'Smoke';
          break;
        default:
          character = 'Smoke';
      }
    }

    // ignore: use_build_context_synchronously
    player = Player(context: context, character: character);
  }

  @override
  FutureOr<void> onLoad() async {
    //loading all images to cache
    await images.loadAllImages();

    _loadLevel(levelName);

    // if (showJoystick) {
    //    addJoystick();
    // }
    return super.onLoad();
  }

//joystick
/*
  @override
  void update(double dt) {
    if (showJoystick) {
      updateJoystick();
    }
    super.update(dt);
  }

  void addJoystick() {
    joystick = JoystickComponent(
      knob: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Knob.png'),
        ),
      ),
      background: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Joystick.png'),
        ),
      ),
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    );

    add(joystick);
  }

  void updateJoystick() {
    switch (joystick.direction) {
      case JoystickDirection.left:
      case JoystickDirection.upLeft:
      case JoystickDirection.downLeft:
        player.horizontalMovement = -1;
        break;
      case JoystickDirection.right:
      case JoystickDirection.upRight:
      case JoystickDirection.downRight:
        player.horizontalMovement = 1;
        break;
      default:
        player.horizontalMovement = 0;
        break;
    }
  }
*/

//Functions that control the level system, add loading screens and control access by the

/*  void loadNextLevel(BuildContext context) {
    if (currentLevelIndex < levelNames.length - 1) {
      currentLevelIndex++;
      _loadLevel(levelNames[currentLevelIndex]);
    } else {
      // No more levels, navigate to the EndLevelWidget
      double currentExperience =
          player.getCurrentLevelExperience(); // Get current level experience
      player.resetExperience(); // Reset experience for the next level
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EndLevelWidget(
            experience: totalExperience.toString(), // Pass total experience
            currentLevelExperience:
                currentExperience, // Pass current level experience
          ),
        ),
      );
    }
  }
*/

  void _loadLevel(String levelName) {
    Future.delayed(const Duration(seconds: 1), () {
      // Create a new Level instance and assign it to currentLevel
      currentLevel = Level(
        player: player,
        levelName: levelName,
      );

      // Create a camera component with fixed resolution
      cam = CameraComponent.withFixedResolution(
        world: currentLevel!,
        width: 480,
        height: 560,
      );
      cam.viewfinder.anchor = Anchor.topLeft;

      // Add the camera and the current level to the game
      addAll([cam, currentLevel!]);
    });
  }

  void clearBlocklyWorkspace() {
    context['Blockly'].callMethod('getMainWorkspace').callMethod('clear');
    player.resetPosition();
    currentLevel?.resetFruits();
  }
}
