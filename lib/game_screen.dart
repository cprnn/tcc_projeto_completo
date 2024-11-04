import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blockly/flutter_blockly.dart';
import 'package:rabbits_challenge/content.dart';
import 'package:rabbits_challenge/rabbits_challenge.dart';
import 'dart:js';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  String? customBlocks; // Use nullable type to handle loading state

  @override
  void initState() {
    super.initState();
    _loadCustomBlocks();
  }

  Future<void> _loadCustomBlocks() async {
    try {
      String blocks =
          await rootBundle.loadString('../assets/js/custom_blocks.js');
      setState(() {
        customBlocks = blocks; // Update the state with the loaded blocks
      });
    } catch (e) {
      // Handle error if needed
      if (kDebugMode) {
        print('Error loading custom blocks: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (customBlocks == null) {
      // Show a loading indicator while the blocks are loading
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Initialize the game
    final RabbitsChallenge game = RabbitsChallenge(context);

    // Define the Blockly options
    final BlocklyOptions workspaceConfiguration =
        BlocklyOptions.fromJson(const {
      'grid': {
        'spacing': 20,
        'length': 3,
        'colour': '#ccc',
        'snap': true,
      },
      'toolbox': initialToolboxJson,
      // null safety example
      'collapse': null,
      'comments': null,
      'css': null,
      'disable': null,
      'horizontalLayout': null,
      'maxBlocks': null,
      'maxInstances': null,
      'media': null,
      'modalInputs': null,
      'move': null,
      'oneBasedIndex': null,
      'readOnly': null,
      'renderer': null,
      'rendererOverrides': null,
      'rtl': null,
      'scrollbars': null,
      'sounds': null,
      'theme': null,
      'toolboxPosition': null,
      'trashcan': null,
      'maxTrashcanContents': null,
      'plugins': null,
      'zoom': null,
      'parentWorkspace': null,
    });

    // Define the callbacks
    void onInject(BlocklyData data) {
      debugPrint('onInject: ${data.xml}\n${jsonEncode(data.json)}');
    }

    void onChange(BlocklyData data) {
      debugPrint(
          'onChange: ${data.xml}\n${jsonEncode(data.json)}\n${data.dart}');
    }

    void onDispose(BlocklyData data) {
      debugPrint('onDispose: ${data.xml}\n${jsonEncode(data.json)}');
    }

    void onError(dynamic err) {
      debugPrint('onError: $err');
    }

    return Scaffold(
      appBar: AppBar(
        //title: const Text("Game Screen"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen
          },
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GameWidget(game: game),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _compileAndRunBlockly,
                      child: const Text("Compilar e Executar Código"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        game.clearBlocklyWorkspace();
                      },
                      child: const Text("Limpar Workspace"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              color: const Color(0x253A5633),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight,
                    child: BlocklyEditorWidget(
                      workspaceConfiguration: workspaceConfiguration,
                      initial: null,
                      onInject: onInject,
                      onChange: onChange,
                      onDispose: onDispose,
                      onError: onError,
                      style: null,
                      script: '''
                        $customBlocks''', // Use the loaded custom blocks
                      editor: null,
                      packages: null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _compileAndRunBlockly() {
    if (kIsWeb) {
      var workspace = context['Blockly'].callMethod('getMainWorkspace');
      if (workspace != null) {
        final codeGenerator = context['Blockly']['JavaScript'];
        final blocklyCode =
            codeGenerator.callMethod('workspaceToCode', [workspace]);
        print('Generated JavaScript code:');
        print(blocklyCode);
        try {
          context.callMethod('eval', [blocklyCode]);
        } catch (e) {
          print('Error evaluating JavaScript code:');
          print(e);
        }
      } else {
        if (kDebugMode) {
          print('Failed to retrieve main Blockly workspace.');
        }
      }
    } else {
      if (kDebugMode) {
        print('JavaScript execution is only available on Flutter Web.');
      }
    }
  }
}
