import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexagon/hexagon.dart';
import 'package:honey_os/UI/userscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:honey_os/UI/homescreen.dart';

class userLogin extends StatefulWidget {
  const userLogin({super.key, this.userName, this.userId, this.profileImage});
  final String? userName;
  final String? userId;
  final String? profileImage;
  @override
  State<userLogin> createState() => _userLoginState();
}

class _userLoginState extends State<userLogin> {
  final TextEditingController _passController = TextEditingController();
  String _password = '';
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final FlutterTts _flutterTts = FlutterTts();
  bool _flutterTtsInitialized = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = true;
  String _lastWords = '';
  String command =  '';
  bool _isStoppingAndRestarting = false;
  bool _responseSpoken = false; // Add this variable
  bool stopRepeated = false;
  late Timer _speechCheckTimer;
  String fetchedPassword = '';
  bool loadedState = false;


  final Duration _checkInterval = const Duration(milliseconds: 10); // Adjust the interval as needed

  String trimStringFromWord(String input, String word) {
    int index = input.indexOf(word);
    if (index != -1) {
      return input.substring(index);
    } else {
      // Word not found, return the original string
      return input;
    }
  }

  @override
  void initState() {
    _initSpeech();
    _initTTS();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    super.initState();
    _responseSpoken = false;
    fetchPassword();
    Timer(const Duration(milliseconds: 500), () =>
    _speak("Hello, ${widget.userName}. Please tell me your secret."));
  }

  void fetchPassword() async {
    // Get the user document with the document id

    final DocumentSnapshot userSnapshot = await users.doc(widget.userId).get();

    // Check if any documents were returned
    if (userSnapshot.exists) {
      // If a document was found, get the password
      fetchedPassword = userSnapshot.get('password');
      print('Password for ${widget.userName} is $fetchedPassword');
    } else {
      // If no document was found, handle the error (e.g., set password to null, show an error message, etc.)
      fetchedPassword = '';
      print('No user found with the username ${widget.userName}');

    }
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
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
      _flutterTtsInitialized = true;
      setState(() {});

    } catch (e) {
      print("Error initializing TTS: $e");
    }
  }


  Future<void> _speak(text) async{
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print("Error speaking: $e");
    }
  }

  Future<void> _interruptSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print("Error stopping speaking: $e");
    }
  }

  Future<void> _startListening() async {
    try {
      if (!_speechToText.isListening) { // Ensure recognition is not already active
        await _speechToText.listen(onResult: _onSpeechResult);
        _responseSpoken = false; // Reset the flag
        setState(() {});
      } else {
        print("Speech recognition is already active."); // Log a message if recognition is already active
      }
    } catch (e) {
      print("Error starting listening: $e");
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() {});
    } catch (e) {
      print("Error stopping listening: $e");
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
      print("Error stopping and restarting listening: $e");
    } finally {
      _isStoppingAndRestarting = false; // Reset flag after completion
    }
  }

  Future<void> followCommand(String command, BuildContext context) async {
    _interruptSpeaking();
    Timer(const Duration(milliseconds: 500), () async {
      if (command.contains("password is")) {

        String password = command.substring(command.indexOf("password is") + 11, command.indexOf(" please"));
        if (password == fetchedPassword) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => Homescreen(firstTime: true, name: widget.userName)));
        } else {
          _speak("I'm sorry, that's not the correct password.");
        }
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

    if (!_speechToText.isListening && loadedState == false || fetchedPassword == '') {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 237, 140, 0),
        body: Center(
            child: Stack(
              children: [
                Center(

                  child: Container(

                    child: Image.asset(
                      'assets/background/HomePageBackground.png', // Replace with your image path
                      fit: BoxFit.fitHeight,
                    ),
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
                                        Image.network(
                                            widget.profileImage!,
                                            fit: BoxFit.fitHeight
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
                              onSubmitted: (value) {
                                if (_password == fetchedPassword) {
                                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) =>  Homescreen(firstTime: true, name: widget.userName)));
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Error'),
                                        content: Text("Wrong Password."),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text('OK'),
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
                              },
                            ),
                          ),

                           const SizedBox(height: 10,),


                            Text(
                          '["${widget.userName}, [password], please"]',
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