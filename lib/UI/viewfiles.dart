import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:honey_os/UI/homescreen.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:honey_os/UI/file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class Disk {
  final String name;
  final String path;

  Disk({required this.name, required this.path});

  factory Disk.fromJson(Map<String, dynamic> json) {
    return Disk(
      name: json['name'],
      path: json['path'],
    );
  }
}

class ViewFiles extends StatefulWidget {

  const ViewFiles({super.key});


  @override
  State<ViewFiles> createState() => _ViewFilesState();
}

class _ViewFilesState extends State<ViewFiles> {
  final CollectionReference FileSystem = FirebaseFirestore.instance.collection('FileSystem');
  List<Disk>? disks;
  final FlutterTts _flutterTts = FlutterTts();
  bool _flutterTtsInitialized = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = true;
  String _lastWords = '';
  String command =  '';
  bool _isStoppingAndRestarting = false;
  bool _responseSpoken = false; // Add this variable
  late Timer _speechCheckTimer;
  final Duration _checkInterval = const Duration(milliseconds: 10);



  @override
  void initState() {

    super.initState();
    _initTTS();
    _initSpeech();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    _loadDisks().then((disks) {
      setState(() {
        this.disks = disks;
      });
    });
  }

  @override
  void dispose() {

    _speechCheckTimer.cancel(); // Cancel the timer when the screen is disposed
    _speechToText.stop(); // Stop listening when the screen is disposed
    _flutterTts.stop(); // Stop speaking when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color.fromARGB(255, 237, 140, 0)),
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(
            //fit: StackFit.expand,
            children: [
              // Background Image
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 70,
                child: Container(
                  child: Image.asset(
                    'assets/background/FilesBackground.png', // Replace with your image path
                  ),
                ),
              ),



              //Time Widget
              Positioned(
                bottom: constraints.maxHeight * 0.02,
                left: constraints.maxWidth * 0.79,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: size.width,
                    height: size.height * 0.18,
                    child: const TimeWidget(),
                  ),
                ),
              ),

              //Home Button
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                right: constraints.maxWidth * 0.90,
                child: SizedBox(
                  width: size.height * 0.15,
                  height: size.height * 0.15,
                  child: IconButton(
                    icon: Image.asset(
                      'assets/buttons/botton.png',
                      fit: BoxFit.scaleDown,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const Homescreen(firstTime: false)),
                      );
                    },
                  ),
                ),
              ),

              //Header Text
              Positioned(
                top: constraints.maxHeight * 0.02,
                left: constraints.maxWidth * 0.05,
                child: SizedBox(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.1,
                  child: const Text(
                    'This PC',
                    style: TextStyle(
                      fontFamily: 'ABeeZee',
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),



              //disks
              Positioned(
                top: constraints.maxHeight * 0.13,
                left: constraints.maxWidth * 0.05,
                child: Container(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.67,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(157, 138, 105, 83),
                    borderRadius: BorderRadius.circular(20),

                  ),
                  child: disks == null ? const Center(
                    child:
                    CircularProgressIndicator(),

                  ) : Row(

                      children: [
                        for (int i = 0; i < disks!.length; i++)

                          Padding(
                            padding: EdgeInsets.only(left: constraints.maxWidth * 0.13, top: constraints.maxHeight * 0.13),
                            child:

                          SizedBox(
                              width: constraints.maxWidth * 0.12,
                              height: constraints.maxHeight * 0.9,
                              child: Column(
                                children: [
                                 SizedBox(
                                      width: constraints.maxWidth * 0.8,
                                      height: constraints.maxHeight * 0.30,
                                      child: IconButton(
                                        icon: Image.asset(
                                          'assets/Drive.png',
                                          fit: BoxFit.scaleDown,
                                        ),
                                        onPressed: () {

                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (context) => Files(
                                              headerName: disks![i].name ?? '',
                                              currentPath: '${disks![i].path}/${disks![i].name}'?? '',
                                            )),
                                          );
                                        },

                                    ),
                                  ),
                                  Text(
                                    'Local Disk ${disks![i].name}',
                                    style: const TextStyle(
                                      fontFamily: 'ABeeZee',
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                      ],


                    ),


                  ),
                ),




            ],

          );

        }),
      ),
    );
  }

  Future<List<Disk>> _loadDisks() async {
    List<Disk> disks = [];
    try {
      QuerySnapshot querySnapshot = await FileSystem.get();
      // Get documents with the type of 'disk'
      for (var doc in querySnapshot.docs) {
        if (doc['path'] == '/FileSystem') {
          disks.add(Disk(
          name: doc['name'],
          path: doc['path'],
        ));
        }
      }


    } catch (e) {
      print("Error loading disks: $e");
    }
    return disks;
  }



  //voice Functions
  String trimStringFromWord(String input, String word) {
    int index = input.indexOf(word);
    if (index != -1) {
      return input.substring(index);
    } else {
      // Word not found, return the original string
      return input;
    }
  }
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {
      _startListening();
    });
  }

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

  Future<void> followCommand(String command, BuildContext context) async {
    _interruptSpeaking();
    Timer(const Duration(milliseconds: 500), () async {

      if(command.contains('home')){

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Homescreen(firstTime: false)),
        );
      }

      else if (command.contains('open drive')) {
        String driveName = command.substring(command.indexOf('drive') + 6, command.indexOf(' please'));

        Disk? drive = disks?.firstWhere((disk) => disk.name == driveName, orElse: () => Disk(name: '', path: ''));

        if (drive!.name != '' && drive.path != '') {
          // If a Disk with the given name is found, navigate to the Files screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => Files(
              headerName: drive.name,
              currentPath: '${drive.path}/${drive.name}',
            )),
          );
        } else {
          // If no Disk with the given name is found, speak an error message
          _speak("I'm sorry, honey. I couldn't find a drive with the name $driveName.");
        }
      }

      else if (command.contains('help')) {
        _speak("You can say 'open drive please'  to open a drive. You can also say 'home' to go back to the home screen.");
      } else if (command.contains("Sir Robert")){
        _speak("Sir Robert is a very handsome and intelligent person. He is the best teacher in the world.");
      } else if (command.contains("stop")) {
        _speak("Stopping, honey.");
      }  else if (command.contains("time")) {
        _speak("The current time is ${DateTime.now().hour}:${DateTime.now().minute} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}");
      }

      else {
        _speak("I'm sorry, honey. I didn't understand that.");
      }
    });
  }


  void _initTTS() async {
    try {
      await _flutterTts.setVoice({"name": "Microsoft Aria Online (Natural) - English (United States)", "locale": "en-US"});
      await _flutterTts.setSpeechRate(1.25);
      setState(() {
        _flutterTtsInitialized = true; // Update the initialization status
      });
      // First time only
      Timer(const Duration(milliseconds: 500), () => _speak("You are now in the view files screen."));


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
        setState(() {});
        _responseSpoken = false; // Reset the flag
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
      if (!_speechToText.isListening && !_isStoppingAndRestarting) {
        // If speech recognition is not listening and not in the process of stopping and restarting
        _stopAndRestartListening();
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
}

// Time
class TimeWidget extends StatefulWidget {
  const TimeWidget({super.key});

  @override
  _TimeWidgetState createState() => _TimeWidgetState();
}

class _TimeWidgetState extends State<TimeWidget> {
  late String _currentTime;
  late String _greeting;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    //Initialize time
    _updateTime();
    _updateGreeting();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      _updateGreeting();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _updateTime() {
    DateTime now = DateTime.now();
    setState(() {
      // Format hours and minutes to always display two digits
      String hours = '${now.hour}'.padLeft(2, '0');
      String minutes = '${now.minute}'.padLeft(2, '0');
      _currentTime = '$hours:$minutes';
    });
  }

  void _updateGreeting() {
    DateTime now = DateTime.now();
    int hour = now.hour;
    if (hour >= 0 && hour < 12) {
      setState(() {
        _greeting = 'morning';
      });
    } else if (hour >= 12 && hour < 18) {
      setState(() {
        _greeting = 'afternoon';
      });
    } else {
      setState(() {
        _greeting = 'evening';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      child: Row(
        children: [
          Text(
            _currentTime,
            style: const TextStyle(
              fontFamily: 'ABeeZee',
              fontSize: 50,
              color: Colors.white,
            ),
          ),
          const VerticalDivider(
            color: Colors.white, // Set the color of the divider
            thickness: 4, // Set the thickness of the divider,
            width: 5,
            indent: 30, // Set the space before the divider
            endIndent: 30, // Set the space after the divider
          ),
          const SizedBox(
            width: 10,
          ),
          Container(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Text(
                  _greeting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'BukhariScript',
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'honey',
                  style: TextStyle(
                    fontFamily: 'BukhariScript',
                    fontSize: 50,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




