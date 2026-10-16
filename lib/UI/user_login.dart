import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexagon/hexagon.dart';
import 'package:honey_os/UI/userscreen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:honey_os/UI/homescreen.dart';
import 'package:honey_os/core/avatar.dart';
import 'package:honey_os/core/voice.dart';
import 'package:honey_os/services/accounts.dart';

class UserLogin extends StatefulWidget {
  const UserLogin({super.key, this.userName, required this.userId, this.profileImage});
  final String? userName;
  final String userId;
  final String? profileImage;
  @override
  State<UserLogin> createState() => _UserLoginState();
}

class _UserLoginState extends State<UserLogin> {
  final TextEditingController _passController = TextEditingController();
  String _password = '';
  final Accounts _accounts = Accounts();
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  String _lastWords = '';
  String command =  '';
  bool _isStoppingAndRestarting = false;
  bool _responseSpoken = false; // Add this variable
  bool stopRepeated = false;
  late Timer _speechCheckTimer;
  bool loadedState = false;


  final Duration _checkInterval = const Duration(milliseconds: 10); // Adjust the interval as needed

  @override
  void initState() {
    _initSpeech();
    _initTTS();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    super.initState();
    _responseSpoken = false;
    Timer(const Duration(milliseconds: 500), () =>
    _speak("Hello, ${widget.userName}. Tell me your secret."));
  }

  /// Signs in through Firebase Authentication. Returns true and opens the home
  /// screen on success; on a wrong password it shows the error dialog.
  Future<void> _attemptLogin(String password) async {
    try {
      final String uid = await _accounts.signIn(username: widget.userName ?? '', password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => Homescreen(firstTime: true, name: widget.userName, userId: uid)));
    } on AccountException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text(e.message),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      _speak("I'm sorry, that's not the correct password.");
    }
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    await _speechToText.initialize();
    if (!mounted) return;
    _startListening();
    setState(() {

    });
  }

  @override
  void dispose() {
    _speechCheckTimer.cancel(); // Cancel the timer when the screen is disposed
    _speechToText.stop(); // Stop listening when the screen is disposed
    _flutterTts.stop(); // Stop speaking when the screen is disposed
    super.dispose();
  }

  /// Each time to start a speech recognition session


  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return; // a late result for a screen that is already gone
    String recognizedWords = result.recognizedWords.toLowerCase();

    if (recognizedWords.contains("honey")) {
      setState(() {
        command = '';
        _lastWords = trimStringFromWord(result.recognizedWords, "honey");
      });
    }

    if (recognizedWords.contains("please") && !_responseSpoken) { // Check if the response hasn't been spoken already
      setState(() {
        command = _lastWords;
        _lastWords = '';
        _responseSpoken = true; // Set the flag to true after speaking the response
      });
      followCommand(command, context);
      _stopAndRestartListening();
    }
  }

  void _initTTS() async {
    try {
      await _flutterTts.setVoice({"name": "Microsoft Aria Online (Natural) - English (United States)", "locale": "en-US"});
      await _flutterTts.setSpeechRate(1.25);
      if (!mounted) return;
      setState(() {});

    } catch (e) {
      debugPrint("Error initializing TTS: $e");
    }
  }


  Future<void> _speak(String text) async{
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error speaking: $e");
    }
  }

  Future<void> _interruptSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping speaking: $e");
    }
  }

  Future<void> _startListening() async {
    try {
      if (!_speechToText.isListening) { // Ensure recognition is not already active
        await _speechToText.listen(onResult: _onSpeechResult);
        if (!mounted) return;
        _responseSpoken = false; // Reset the flag
        setState(() {});
      } else {
        debugPrint("Speech recognition is already active."); // Log a message if recognition is already active
      }
    } catch (e) {
      debugPrint("Error starting listening: $e");
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("Error stopping listening: $e");
    }
  }

  void _startSpeechCheckTimer() {
    _speechCheckTimer = Timer.periodic(_checkInterval, (Timer timer) {
      setState(() {});
      if (!_speechToText.isListening && !_isStoppingAndRestarting) {
        // If speech recognition is not listening and not in the process of stopping and restarting
        _stopAndRestartListening();
        setState(() {});

      }
    });

  }

  void _stopAndRestartListening() async {
    if (_isStoppingAndRestarting) return; // If already in progress, return

    try {

      _isStoppingAndRestarting = true; // Set flag to indicate in progress
      await _stopListening(); // Stop listening
      await Future.delayed(const Duration(milliseconds: 500)); // Delay for a short period
      await _startListening(); // Restart listening
    } catch (e) {
      debugPrint("Error stopping and restarting listening: $e");
    } finally {
      _isStoppingAndRestarting = false; // Reset flag after completion
    }
  }

  Future<void> followCommand(String command, BuildContext context) async {
    _interruptSpeaking();
    Timer(const Duration(milliseconds: 500), () async {
      if (command.contains("password is")) {

        final String password = (valueAfter(command, "password is") ?? '').replaceAll(" ", "");
        await _attemptLogin(password);
      } else if (command.contains("stop")) {
        _speak("Stopping, honey.");

      }
       else {
        _speak("I'm sorry, I didn't understand that command.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    if (!_speechToText.isListening && loadedState == false) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 237, 140, 0),
        body: Center(
            child: Stack(
              children: [
                Center(

                  child: Image.asset(
                      'assets/background/HomePageBackground.png', // Replace with your image path
                      fit: BoxFit.fitHeight,
                    ),
                ),
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        // Set the color of the progress indicator to yellow
                        color: Colors.yellow,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Bzzzing...',
                        style: TextStyle(
                          fontFamily: 'ABeeZee',
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )

        ),
      );
    }
    loadedState = true;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color.fromARGB(255, 237, 140, 0)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              //fit: StackFit.expand,
              children: [

                // Background Image
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Image.asset(
                    'assets/User_Log_In.png', // Replace with your image path
                    fit: BoxFit.fill,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side of Screen
                    Container(
                    width: size.width*0.5,
                    alignment: Alignment.center,

                      child: SizedBox(
                        width: size.height * 0.50,
                        height: size.height * 0.50,
                        child: IconButton(
                          icon: Image.asset('assets/buttons/Back.png'),
                          onPressed: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserScreen()));
                          },
                          color: Colors.white, // Set the icon color
                          iconSize: 30,
                        ),

                      ),

                    ),

                    //Right Side of Screen
                    Container(
                      width: size.width*0.5,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 50,),
                          
                          // for User Pic
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              //Border for User Pic
                              Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: HexagonWidget.flat(
                                    width: size.width *0.25,
                                    //height: size.height * 0.1,
                                    //padding: 4,
                                    child: AspectRatio(
                                      aspectRatio: HexagonType.FLAT.ratio,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(color: Color.fromARGB(255, 232, 118, 61)),
                                      )
                                    ),
                                  ),
                                ),
                              
                              //User Picture
                              Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: HexagonWidget.flat(
                                    width: size.width *0.24,
                                    //height: size.height * 0.1,
                                    //padding: 4,
                                    child: AspectRatio(
                                      aspectRatio: HexagonType.FLAT.ratio,
                                      child:
                                        Image.memory(
                                            decodeAvatar(widget.profileImage ?? ''),
                                            fit: BoxFit.fitHeight,
                                            gaplessPlayback: true,
                                        ),

                                            //color: Color.fromARGB(255, 255, 177, 0),

                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Username
                          Text(
                            '${widget.userName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'BreeSerif',
                              fontSize: 40,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 80,),

                          Text(
                            '${widget.userName}, tell me your secret',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'BukhariScript',
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10,),

                          // Password textfield
                          Container(
                            width: size.width*0.3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25.0), // Set border radius
                              color: Colors.grey[200], // Set background color
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding
                            child: TextField(
                              controller: _passController,
                              obscureText: true,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                hintText: 'Enter password',
                                border: InputBorder.none, // Hide default border
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _password = value;
                                });
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r"\s")),
                              ],
                              onSubmitted: (value) => _attemptLogin(_password),
                            ),
                          ),

                           const SizedBox(height: 10,),


                            Text(
                          '["Honey, the password is [password], please"]',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'ABeeZee',
                              fontSize: 20,
                              color: Colors.white,
                              )
                          ),
                        ],
                      ),
                    )
                  ],
                ),              
              
              ]
            );
          }
        )
      )
    );
  }
}