import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:honey_os/UI/filescreen.dart';
import 'package:honey_os/UI/viewfiles.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';


class Homescreen extends StatefulWidget {


  const Homescreen({super.key, this.firstTime, this.name});
  final bool? firstTime; // Add a parameter to indicate if it's the first time
  final String? name;

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _flutterTtsInitialized = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = true;
  String _lastWords = '';
  String command =  '';
  bool _isStoppingAndRestarting = false;
  bool _responseSpoken = false; // Add this variable
  bool honeyWidgetShown = false;
  bool dateWidgetShown = false;
  bool fileExplorerShown = false;
  bool stopRepeated = false;
  String _fileName = '';
  bool loadedState = false;
  late String fileContent = '';
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
    fileContent = '';
    _fileName = '';
    _responseSpoken = false;

    if (widget.firstTime == true) {
        Timer(const Duration(milliseconds: 500), () {
          _speak("Hello ${widget.name}. How can I help you today?");
        });
    } else {
      Timer(const Duration(milliseconds: 500), () {
        _speak("You are now back in the home screen.");
      });
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

  Future<void> followCommand(String command, BuildContext context) async {
    _interruptSpeaking();
    Timer(const Duration(milliseconds: 500), () async {
      if (command.contains('create a file')) {
        _speak("Sure");
        Timer(const Duration(seconds: 1), () {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FileScreen()));
        });
      }

      else if (command.contains('view files')) {
        _speak("Sure");
        Timer(const Duration(seconds: 1), () {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ViewFiles()));
        });
      }

      else if (command.contains('tell me about honey')) {
        const text = "I'm a voice operated Operating System designed to cater to your needs. You can activate me by saying honey and end with please";
        if (fileExplorerShown == true) {
          _speak("Honey, the file explorer is open. Please close it first");
        } else if (Navigator.canPop(context)) {
          if (honeyWidgetShown == true) {
            _interruptSpeaking();
            Timer(const Duration(milliseconds: 100), () {
              _speak("Honey, it is already displayed in the screen.");
            });
          } else {
            _speak("Sure");

            Timer(const Duration(seconds: 1), () {
              Navigator.pop(context);
              dateWidgetShown = false;
              honeyWidgetShown = true;
              Timer(const Duration(milliseconds: 500), () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const HoneyWidget(
                        text: text);
                  },
                );
              });
            });
          }
        } else {
          _speak("Sure");
          honeyWidgetShown = true;
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const HoneyWidget(
                  text: text);
            },
          );
        }
      }

      else if (command.contains('open a file')) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (fileExplorerShown == true) {
          _interruptSpeaking();
          Timer(const Duration(milliseconds: 100), () {
            _speak("Honey, the file explorer is already open.");
          });
        } else {
          _speak("Please choose a file to open.");
          fileExplorerShown = true; // Update the state to trigger UI update

          Timer(const Duration(milliseconds: 500), () async {

          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['txt'],
          );


          if (result != null) {
            Uint8List fileBytes = result.files.first.bytes!;
            _fileName = result.files.first.name;
            // Convert file bytes to string

            fileContent = String.fromCharCodes(fileBytes);
            _speak("I have opened the file.");
            // Move to the fileScreen

            fileExplorerShown = false;
            _responseSpoken = false;
            Timer(const Duration(seconds: 2), () {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) =>
                          FileScreen(
                            fileName: _fileName,
                            fileContent: fileContent,
                            fileOpened: true,
                          )
                  )
              );
            });
          } else {
            _speak("Honey, no file was selected.");
            fileExplorerShown = false;
            setState(() {

            });
          }
        });
        }
      }

      else if (command.contains('tell me the date')) {
        if (fileExplorerShown == true) {
          _speak("Honey, the file explorer is open. Please close it first");
        }
        else if (Navigator.canPop(context)) {
          if (dateWidgetShown == true) {
            _interruptSpeaking();
            Timer(const Duration(milliseconds: 100), () {
              _speak("Honey, it is already displayed in the screen.");
            });
          } else {
            _speak("Sure");

            Timer(const Duration(seconds: 1), () {
              Navigator.pop(context);
              honeyWidgetShown = false;
              dateWidgetShown = true;
              Timer(const Duration(milliseconds: 500), () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const DateWidget();
                  },
                );
              });
            });
          }
        } else {
          _speak("Sure");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const DateWidget();
            },
          );
        }
      }

      else if (command.contains("go back")) {
        if (fileExplorerShown == true) {
          _speak(
              "Honey, I cannot close the file explorer for you. Please close it yourself.");
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
          Timer(const Duration(milliseconds: 500), () {
            _speak("Honey, you are now back in the home screen.");
          });
          honeyWidgetShown = false;
          dateWidgetShown = false;
        } else {
          _speak("Honey, you are already on the home screen.");
        }
      }

      else if (command.contains("buzz out")) {
        _speak("Are you sure honey?");
        // Exit the tab/window after a delay
        bool confirmed = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation'),
              content: const Text('Are you sure you want to close this window?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (confirmed) {
          Timer(const Duration(milliseconds: 500), () {
            _speak("Goodbye, honey.");
            Timer(const Duration(seconds: 2), () {
              js.context.callMethod('open', ['about:blank', '_self']);
              js.context.callMethod('close');
            });
          });
        } else {
          _speak("I'm glad you decided to stay.");
        }
      } else if (command.contains("help")) {
        _speak("You can create a file, open a file, view files, tell me about honey, tell me the date, go back, or buzz out.");
      } else if (command.contains("Sir Robert")){
        _speak("Sir Robert is a very handsome and intelligent person. He is the best teacher in the world.");
      } else  if (command.contains("handsome")) {
        _speak("Daniel Alexis Cruz is the most handsome person in the world.");
      } else if (command.contains("Jovel")) {
        _speak("Jovel is fat and is jutay.");
      } else if (command.contains("stop")) {
        _speak("Stopping, honey.");

      } else if (command.contains("time")) {
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
                Center(
                  child: Container(
                    child: Image.asset(
                      'assets/background/HomePageBackground.png', // Replace with your image path
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                ),

                //Time Widget
                Positioned(
                  top: constraints.maxHeight * 0.05,
                  left: constraints.maxWidth * 0.28,
                  child: Container(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: size.width,
                      height: constraints.maxHeight * 0.3,
                      child: const TimeWidget(),
                    ),
                  ),
                ),


                // Icon Buttons
                //Create File
                Positioned(
                  top: constraints.maxHeight * 0.535, //317+79
                  left: constraints.maxWidth * 0.438, //559+118
                  child: SizedBox(
                    width: size.width * 0.25,
                    height: size.height * 0.25,
                    child: IconButton(
                      icon: Image.asset(
                        'assets/homeButtons/Create a File.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                      ),
                      onPressed: () {

                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const FileScreen()));
                      },
                    ),
                  ),
                ),

                  //Open File
                  Positioned(
                    top: constraints.maxHeight * 0.385,
                    left: constraints.maxWidth * 0.315,
                    child: SizedBox(
                      width: size.width * 0.25,
                      height: size.height * 0.25,
                      child: IconButton(
                        icon: Image.asset('assets/homeButtons/Open a File.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: () async {
                          _interruptSpeaking();
                          Timer(const Duration(milliseconds: 100), () async {
                            fileExplorerShown = true;
                           _speak("Please choose a file to open.");
                           FilePickerResult? result = await FilePicker.platform.pickFiles(
                             type: FileType.custom,
                              allowedExtensions: ['txt'],
                           );

                           if (result != null) {
                             Uint8List fileBytes = result.files.first.bytes!;
                             _fileName = result.files.first.name;
                             // Convert file bytes to string
                             fileContent = String.fromCharCodes(fileBytes);
                             _speak("I have opened the file.");
                             // Move to the fileScreen
                             fileExplorerShown = false;
                             Timer(const Duration(seconds: 1), () {
                               Navigator.of(context).pushReplacement(
                                   MaterialPageRoute(
                                       builder: (context) =>
                                           FileScreen(
                                             fileName: _fileName,
                                             fileContent: fileContent,
                                             fileOpened: true,
                                           )
                                   )
                               );
                             });
                           } else {
                             _speak("Honey, no file was selected.");
                             fileExplorerShown = false;
                           }
                          });
                        },
                      ),
                    )
                  ),

                  //Buzz Out
                  Positioned(
                    bottom: constraints.maxHeight * 0.06,
                    right: constraints.maxWidth * 0.187,
                    child: SizedBox(
                      width: size.width * 0.25,
                      height: size.height * 0.25,
                      child: IconButton(
                        icon: Image.asset('assets/homeButtons/BuzzOut.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: () async {
                          _interruptSpeaking();
                          Timer(const Duration(milliseconds: 100), () async {
                          _speak("Are you sure honey?");
                          // Exit the tab/window after a delay
                          bool confirmed = await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirmation'),
                              content: const Text('Are you sure you want to close this window?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            );
                          },
                          );

                          if (confirmed) {
                            Timer(const Duration(milliseconds: 500), () {
                              _speak("Goodbye, honey.");
                              Timer(const Duration(seconds: 2), () {
                                js.context.callMethod('open', ['about:blank', '_self']);
                                js.context.callMethod('close');
                              });
                            });
                          } else {
                            _speak("I'm glad you decided to stay.");
                          }
                        });
                        },
                      ),
                    )
                  ),

                  //Tell me About Honey
                  Positioned(
                    top: constraints.maxHeight * 0.533,
                    left: constraints.maxWidth * 0.186,
                    child: SizedBox(
                      width: size.width * 0.25,
                      height: size.height * 0.25,
                      child: IconButton(
                        icon: Image.asset('assets/homeButtons/Tell me About Honey.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: (){
                          _interruptSpeaking();
                          Timer(const Duration(milliseconds: 100), () {
                            honeyWidgetShown = true;
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return const HoneyWidget(text: "I'm a voice operated Operating System designed to cater to your needs. You can activate me by saying honey and end with please");
                              },
                            ).then((value) => honeyWidgetShown = false);
                          });

                        },
                      ),
                    )
                  ),

                  //Tell me the Date
                  Positioned(
                    top: constraints.maxHeight * 0.394,
                    right: constraints.maxWidth * 0.187,
                    child: SizedBox(
                      width: size.width * 0.25,
                      height: size.height * 0.25,
                      child: IconButton(
                        icon: Image.asset('assets/homeButtons/Tell me the Date.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: (){
                          _interruptSpeaking();
                          Timer(const Duration(milliseconds: 100), () {
                          dateWidgetShown = true;
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return const DateWidget();
                            },
                          ).then((value) => dateWidgetShown = false);
                        },
                        );
                        },
                      ),
                    )
                  ),

                  //View Files
                  Positioned(
                    bottom: size.height * 0.066,
                    left: size.width * 0.315,
                    child: SizedBox(
                      width: size.width * 0.25,
                      height: size.height * 0.25,
                      child: IconButton(
                        icon: Image.asset('assets/homeButtons/View Files.png',
                        fit: BoxFit.scaleDown,
                        //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: (){
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const ViewFiles()));
                        },
                      ),
                    )
                  ),
                ],
              );
          }
        ),
      ),
    );
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
  late Timer _timer; // Add a Timer variable to hold the periodic timer


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
      alignment: Alignment.topCenter,
      child: Row(
        children: [
          Text(
            _currentTime,
            style: const TextStyle(
              fontFamily: 'ABeeZee',
              fontSize: 100,
              color: Colors.white,
            ),
          ),
          const VerticalDivider(
            color: Colors.white, // Set the color of the divider
            thickness: 4, // Set the thickness of the divider
            indent: 30, // Set the space before the divider
            endIndent: 30, // Set the space after the divider
          ),
          const SizedBox(width: 10,),
          Container(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Text(
                    _greeting,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'BukhariScript',
                      fontSize: 40,
                      color: Colors.white,
                      
                    ),
                  ),
                  const Text(
                    'honey',
                    style: TextStyle(
                      fontFamily: 'BukhariScript',
                      fontSize: 100,
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

//Date
class DateWidget extends StatefulWidget {
  const DateWidget({super.key});

  @override
  State<DateWidget> createState() => _DateWidgetState();
}

class _DateWidgetState extends State<DateWidget> {
  late FlutterTts _flutterTts;
  // Function to get the day of the week
  String getDayOfWeek(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String getMonth(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
      return 'August';
      case 9:
      return 'September';
      case 10:
      return 'October';
      case 11:
      return 'November';
      case 12:
      return 'December';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _speak('Today is ${getDayOfWeek(DateTime.now().weekday)}, ${getMonth(DateTime.now().month)} ${DateTime.now().day}, ${DateTime.now().year}');
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current date
    DateTime now = DateTime.now();

    // Get the current day
    String day = getDayOfWeek(now.weekday);

    // Get the current month
    String month = getMonth(now.month);

    // Get the current date
    String date = '$month ${now.day}, ${now.year}';
    
    return Center(
      child: Stack(
        children: [
          Center(
            child: Container(
              child: Image.asset(
                'assets/background/date_background.png', // Replace with your image path
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
                //alignment: Alignment.topCenter,
                children: [
                  const SizedBox(height: 50,),
                  Text(
                  'Its $day today!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ABeeZee',
                    fontSize: 40,
                    color: Colors.white,
                  ),
                ),
                //const SizedBox(height: 50,),
                Text(
                  date,
                  style: const TextStyle(
                    fontFamily: 'ABeeZee',
                    fontSize: 80,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

//Honey
class HoneyWidget extends StatefulWidget{
  final String text;

  const HoneyWidget({super.key, required this.text});


  @override
  State<HoneyWidget> createState() => _HoneyWidgetState();
}



class _HoneyWidgetState extends State<HoneyWidget>{
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();

    _speak(widget.text);
  }

  @override
  void dispose() {
    _flutterTts.stop();

    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Center(
            child: Container(
              child: Image.asset(
                'assets/background/honey_background.png', // Replace with your image path
              ),
            ),
          ),
        ],
      ),
    );
  }


}