import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexagon/hexagon.dart';
import 'package:honey_os/UI/userLogin.dart';
import 'package:honey_os/UI/userRegister.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class User {
  final String id;
  final String name;
  final String password;
  final String profilePicture;

  User({required this.id, required this.name, required this.password, required this.profilePicture});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      password: json['password'],
      profilePicture: json['profilePicture'],
    );
  }



}


class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<User>? usersInfo;
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
  bool loadedState = false;
  String profilePicture = '';
  List <String> profilePictures = [];
  late Timer _speechCheckTimer;


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
    fetchUsers();
    _speak("Welcome to Honey OS. Login or register a new user.");
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

  void fetchUsers() async {
    final QuerySnapshot snapshot = await users.get();
    List<User> usersInfo = [];
    snapshot.docs.forEach((doc) async {
      print(doc['profile_picture']);
      usersInfo.add(User(
        id: doc.id,
        name: doc['name'],
        password: doc['password'],
        profilePicture: doc['profile_picture'],
      ));
    });
    setState(() {
      this.usersInfo = usersInfo;
    });
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
                    'assets/Desktop-12(1).png', // Replace with your image path
                    fit: BoxFit.fitHeight,
                  ),
                ),

                //User
                Positioned(
                  top: constraints.maxHeight * 0.478,
                  left: constraints.maxWidth * 0.37,
                  child: usersInfo != null && usersInfo!.isNotEmpty ? UserIcon(size.width *0.127, usersInfo?[0].profilePicture ?? '', usersInfo?[0].id ?? '', usersInfo?[0].name ?? '') : UserIcon(size.width *0.127, '', '', ''),
                ),

                //Add User 1
                Positioned(
                  top: constraints.maxHeight * 0.37,
                  left: constraints.maxWidth * 0.29,
                  child: usersInfo != null && usersInfo!.length > 1 ? UserIcon(size.width *0.1, usersInfo?[1].profilePicture ?? '', usersInfo?[1].id ?? '', usersInfo?[1].name ?? '') : UserIcon(size.width *0.1, '', '', '')
                ),

                //Add User 2
                Positioned(
                  top: constraints.maxHeight * 0.569,
                  left: constraints.maxWidth * 0.276,
                  child: usersInfo != null && usersInfo!.length > 2 ? UserIcon(size.width *0.07, usersInfo?[2].profilePicture ?? '', usersInfo?[2].id ?? '', usersInfo?[2].name ?? '') : UserIcon(size.width *0.07, '', '', '')
                ),


                //Add User 3
                Positioned(
                  top: constraints.maxHeight * 0.236,
                  left: constraints.maxWidth * 0.375,
                  child: usersInfo != null && usersInfo!.length > 3 ? UserIcon(size.width *0.12, usersInfo?[3].profilePicture ?? '', usersInfo?[3].id ?? '', usersInfo?[3].name ?? '') : UserIcon(size.width *0.12, '', '', '')
                ),

                //Add User 4
                Positioned(
                  top: constraints.maxHeight * 0.73,
                  left: constraints.maxWidth * 0.3998,
                  child: usersInfo != null && usersInfo!.length > 4 ? UserIcon(size.width *0.088, usersInfo?[4].profilePicture ?? '', usersInfo?[4].id ?? '', usersInfo?[4].name ?? '') : UserIcon(size.width *0.088, '', '', '')
                ),

                //Add User 5
                Positioned(
                  top: constraints.maxHeight * 0.347,
                  left: constraints.maxWidth * 0.479,
                  child: usersInfo != null && usersInfo!.length > 5 ? UserIcon(size.width *0.1275, usersInfo?[5].profilePicture ?? '', usersInfo?[5].id ?? '', usersInfo?[5].name ?? '') : UserIcon(size.width *0.1275, '', '', '')
                ),

                //Add User 6
                Positioned(
                  top: constraints.maxHeight * 0.605,
                  left: constraints.maxWidth * 0.48,
                  child: usersInfo != null && usersInfo!.length > 6 ? UserIcon(size.width *0.128, usersInfo?[6].profilePicture ?? '', usersInfo?[6].id ?? '', usersInfo?[6].name ?? '') : UserIcon(size.width *0.128, '', '', '')
                ),

                //Add User 7
                Positioned(
                  top: constraints.maxHeight * 0.2774,
                  left: constraints.maxWidth * 0.5974,
                  child: usersInfo != null && usersInfo!.length > 7 ? UserIcon(size.width *0.0948, usersInfo?[7].profilePicture ?? '', usersInfo?[7].id ?? '', usersInfo?[7].name ?? '') : UserIcon(size.width *0.0948, '', '', '')
                ),

                //Add User 8
                Positioned(
                  top: constraints.maxHeight * 0.474,
                  left: constraints.maxWidth * 0.589,
                  child: usersInfo != null && usersInfo!.length > 8 ? UserIcon(size.width *0.13, usersInfo?[8].profilePicture ?? '', usersInfo?[8].id ?? '', usersInfo?[8].name ?? '') : UserIcon(size.width *0.13, '', '', '')
                ),

                //Add User 9
                Positioned(
                  top: constraints.maxHeight * 0.73,
                  left: constraints.maxWidth * 0.599,
                  child: usersInfo != null && usersInfo!.length > 9 ? UserIcon(size.width *0.08, usersInfo?[9].profilePicture ?? '', usersInfo?[9].id ?? '', usersInfo?[9].name ?? '') : UserIcon(size.width *0.08, '', '', '')
                ),

              ]
            );
          }
        )
      )
    );
  }


  Widget UserIcon (double size, String image, String id, String userName){
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: HexagonWidget.flat(
        color: const Color.fromARGB(0, 232, 118, 61),
        width: size,
        //height: size.height * 0.1,
        //padding: 4,
        child: image == '' 
        ? IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const userRegister())),
            color: Colors.white, // Set the icon color
            iconSize: 50, // Set the icon size
          )
        :AspectRatio(
          aspectRatio: HexagonType.FLAT.ratio,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: InkWell(
              onTap: (){
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => userLogin(userName: userName, userId: id, profileImage: image)));
              },
              child: Image.network(image, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

