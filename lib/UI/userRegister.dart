import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexagon/hexagon.dart';
import 'package:honey_os/UI/userscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';


class userRegister extends StatefulWidget {
  const userRegister({super.key});

  @override
  State<userRegister> createState() => _userRegisterState();
}

class _userRegisterState extends State<userRegister> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _password = '';
  String _name = '';
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
  String defaultUri = '';
  String imagePath = '';
  bool loadedState = false;
  Uint8List? imageBytes;
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
    fetchDefaultUri();
    _initSpeech();
    _initTTS();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    super.initState();
    _responseSpoken = false;
    Timer(const Duration(milliseconds: 500), () {
      _speak("Welcome to Honey OS. I am your personal assistant, Honey. I am here to help you register. Please provide me with your username and password.");
    });
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    _startListening();
    setState(() {

    });
  }

  void fetchDefaultUri () async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref().child("DEPOLTIMEJ.jpg");
    defaultUri = await ref.getDownloadURL();
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
      if (command.contains("username is")) {
        _name = command.substring(command.indexOf("username is") + 11, command.indexOf( "please"));
        _speak("Your username is $_name. Is this correct?");
      } else if (command.contains("password is")) {
        _password = command.substring(command.indexOf("password is") + 11, command.indexOf( "please"));
        _speak("Your password is $_password. Is this correct?");
      } else if (command.contains("register me")) {

        if (_name.isEmpty && _password.isEmpty) {
          _speak("I'm sorry. You need to provide a username and password.");
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return FutureBuilder<void>(
                future: registerUser(),
                builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AlertDialog(
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text('Registering...'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    if (snapshot.hasError) {
                      return AlertDialog(
                        title: const Text('Error'),
                        content: Text('${snapshot.error}'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    } else {
                      return AlertDialog(
                        title: const Text('Success'),
                        content: const Text('User registered successfully'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    }
                  }
                },
              );
            },
          );
        }
      } else if (command.contains("stop")) {
        _speak("Stopping, honey.");

      }

      else {
        _speak("I'm sorry. I didn't understand that.");
      }
    });
  }

  Future<void> registerUser() async {
    _speak("Registering you now.");
    // Upload
    if (imageBytes != null) {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child("profile_pictures/$_name.jpg");
      await ref.putData(imageBytes!);
      await users.add({
        'name': _name,
        'password': _password,
        'profile_picture': await ref.getDownloadURL(),
      });
    } else {
      var response = await http.get(Uri.parse(defaultUri));
      Uint8List defaultImageBytes = response.bodyBytes;

      // Upload the default image to Firebase Storage
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child("profile_pictures/$_name.jpg");
      await ref.putData(defaultImageBytes);
      await users.add({
        'name': _name,
        'password': _password,
        'profile_picture': await ref.getDownloadURL(),
      });
    }
    _speak("You have been registered successfully. {$_name}, you can now log in.");
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserScreen()));
  }


  @override
  Widget build(BuildContext context) {


    Size size = MediaQuery.of(context).size;
    if (!_speechToText.isListening && loadedState == false || defaultUri == '') {
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
                // Back Button

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

                      // Background Image
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
                                  child: InkWell(
                                    onTap: () {
                                      FilePicker.platform.pickFiles().then((value) {
                                        if (value != null) {
                                          Uint8List? bytes = value.files.single.bytes;
                                          if (bytes != null) {
                                            setState(() {
                                              imageBytes = bytes;
                                            });
                                          }
                                        }
                                      });
                                    },
                                    child: imageBytes != null
                                        ? Image.memory(
                                      imageBytes!,
                                      fit: BoxFit.fitHeight,
                                    )
                                        : Image.network(
                                      defaultUri,
                                      fit: BoxFit.fitHeight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30,),

                          const Text(
                            'honey, tell me your name',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                            child: TextFormField(
                              controller: _nameController,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                hintText: 'Enter username',
                                border: InputBorder.none, // Hide defau// lt border
                              ),
                              onChanged: (value) {
                                _name = value;
                              },
                              onFieldSubmitted: (value) {
                                if (_name.isNotEmpty && _password.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return FutureBuilder<void>(
                                        future: registerUser(),
                                        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const AlertDialog(
                                              content: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(),
                                                  Padding(
                                                    padding: EdgeInsets.only(left: 10),
                                                    child: Text('Registering...'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            if (snapshot.hasError) {
                                              return AlertDialog(
                                                title: const Text('Error'),
                                                content: Text('${snapshot.error}'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('OK'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            } else {
                                              return AlertDialog(
                                                title: const Text('Success'),
                                                content: const Text('User registered successfully'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('OK'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            }
                                          }
                                        },
                                      );
                                    },
                                  );
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Error'),
                                        content: Text("Please provide both username and password."),
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
                                  _speak("I'm sorry. You need to provide a username and password.");
                                }
                              },
                            ),
                          ),
                     
                          
                          const SizedBox(height: 30,),

                          const Text(
                            'honey, tell me your secret',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                            child: TextFormField(
                              controller: _passController,
                              maxLength: 10,
                              obscureText: true,

                              decoration: const InputDecoration(
                                hintText: 'Enter password',
                                border: InputBorder.none, // Hide default border

                              ),
                              onChanged: (value) {
                                _password = value;
                              },
                              onFieldSubmitted: (value) {
                                if (_name.isNotEmpty && _password.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return FutureBuilder<void>(
                                        future: registerUser(),
                                        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const AlertDialog(
                                              content: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(),
                                                  Padding(
                                                    padding: EdgeInsets.only(left: 10),
                                                    child: Text('Registering...'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            if (snapshot.hasError) {
                                              return AlertDialog(
                                                title: const Text('Error'),
                                                content: Text('${snapshot.error}'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('OK'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            } else {
                                              return AlertDialog(
                                                title: const Text('Success'),
                                                content: const Text('User registered successfully'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('OK'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            }
                                          }
                                        },
                                      );
                                    },
                                  );

                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Error'),
                                        content: Text("Please provide both username and password."),
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
                                  _speak("I'm sorry. You need to provide a username and password.");
                                }

                              },
                            ),
                          ),

                           const SizedBox(height: 40,),


                          const Text(
                          '["honey, [username] [password], please"]',   
                            textAlign: TextAlign.center,
                            style: TextStyle(
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