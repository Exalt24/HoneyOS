import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:honey_os/UI/homescreen.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:honey_os/UI/file.dart';

class TextUndoRedoController {
  final TextEditingController textEditingController = TextEditingController();
  final ListQueue<String> undoStack = ListQueue<String>();
  final ListQueue<String> redoStack = ListQueue<String>();

  void performAction(String newText) {
    if (undoStack.isEmpty) {
      undoStack.addFirst('');
    }

      undoStack.addFirst(newText);
      textEditingController.text = newText;
      redoStack.clear();

  }
  void undo() {
    if (undoStack.length > 1){
      if (textEditingController.text != "") {
        redoStack.addFirst(textEditingController.text);
        }
      if(undoStack.first == textEditingController.text){
        undoStack.removeFirst();
      }
      textEditingController.text = undoStack.first;

    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      if (textEditingController.text != "") {
        undoStack.addFirst(textEditingController.text);
      }
      textEditingController.text = redoStack.removeFirst();
    }
  }
}

class Folder {
  final String id;
  final String name;
  final String path;
  final String userId;

  Folder({required this.id, required this.name, required this.path, required this.userId});

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      userId: json['userId'],
    );
  }

}

class File {

  final String id;
  final String name;
  final String path;
  final String content;

  File({required this.id, required this.name, required this.path, required this.content});

  factory File.fromJson(Map<String, dynamic> json) {
    return File(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      content: json['content'],
    );
  }
}


class FileScreen extends StatefulWidget {
  const FileScreen({super.key, this.fileName, this.fileContent, this.fileOpened, this.saveLocation, this.fileId, required this.userId });


  final String? fileName;
  final String? fileContent;
  final bool? fileOpened;
  final String? saveLocation;
  final String? fileId;
  final String userId;


  @override
  State<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends State<FileScreen> {
  final TextUndoRedoController _controller = TextUndoRedoController();
  bool changesOnText = false;
  late String _fileName;
  late String _fileId;

  final CollectionReference FileSystem = FirebaseFirestore.instance.collection('FileSystem');
  List<Folder>? folders;

  String? fileContent;
  final FlutterTts _flutterTts = FlutterTts();
  bool _flutterTtsInitialized = false;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = true;
  String _lastWords = '';
  String command =  '';
  bool _isStoppingAndRestarting = false;
  bool _responseSpoken = false; // Add this variable
  bool fileNameWidgetShown = false;
  bool fileExplorerShown = false;
  late Timer _speechCheckTimer;
  final Duration _checkInterval = const Duration(milliseconds: 10);
  bool fileOpened = false;
  late String saveLocation;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _initTTS();
    _initSpeech();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    _fileName = widget.fileName != null ? (widget.fileName!.length > 20 ? widget.fileName!.substring(0, 20) : widget.fileName!) : 'Untitled';
    fileContent = widget.fileContent ?? '';
    _controller.textEditingController.text = fileContent ?? '';
    fileOpened = widget.fileOpened ?? false;
    saveLocation = widget.saveLocation ?? '';
    _fileId = widget.fileId ?? '';
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
              Center(
                child: Container(
                  child: Image.asset(
                    'assets/background/FilesBackground.png', // Replace with your image path
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),

              //Time Widget
              Positioned(
                top: constraints.maxHeight * 0.02,
                left: constraints.maxWidth * 0.79,
                child: Container(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: size.width,
                    height: size.height * 0.18,
                    child: const TimeWidget(),
                  ),
                ),
              ),

              //Buttons Container
              Positioned(
                  top: constraints.maxHeight * 0.05,
                  left: constraints.maxWidth * 0.03,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: SizedBox(
                        width: size.width * 0.1,
                        height: size.height * 0.9,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                              color: Color.fromARGB(210, 242, 194, 22)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              //Open Button
                              InkWell(
                                onTap: () {},
                                child: SizedBox(
                                  width: size.height * 0.15,
                                  height: size.height * 0.15,
                                  child: IconButton(
                                    icon: Image.asset(
                                      'assets/buttons/Open_Files_Button.png',
                                      fit: BoxFit.scaleDown,
                                      //color: Color.fromARGB(255, 255, 177, 0),
                                    ),
                                    onPressed: () {
                                      openFile();
                                    },
                                  ),
                                ),
                              ),

                              //Create Button
                              SizedBox(
                                width: size.height * 0.15,
                                height: size.height * 0.15,
                                child: IconButton(
                                  icon: Image.asset(
                                    'assets/buttons/Create_File_Button.png',
                                    fit: BoxFit.scaleDown,
                                    //color: Color.fromARGB(255, 255, 177, 0),
                                  ),
                                  onPressed: () {
                                    createFile();


                                  },
                                ),
                              ),

                              //Save Button
                              SizedBox(
                                width: size.height * 0.15,
                                height: size.height * 0.15,
                                child: IconButton(
                                  icon: Image.asset(
                                    changesOnText || fileOpened
                                        ? 'assets/buttons/Save_Button.png'
                                        : 'assets/buttons/Save_Disabled.png',
                                    fit: BoxFit.scaleDown,
                                    //color: Color.fromARGB(255, 255, 177, 0),
                                  ),
                                  onPressed: () {

                                    saveFile();
                                  },
                                ),
                              ),

                              //Save As Button
                              SizedBox(
                                width: size.height * 0.15,
                                height: size.height * 0.15,
                                child: IconButton(
                                  icon: Image.asset(
                                    changesOnText || fileOpened
                                        ? 'assets/buttons/SaveAs_Button.png'
                                        : 'assets/buttons/SaveAs_Disabled.png',
                                    fit: BoxFit.scaleDown,
                                    //color: Color.fromARGB(255, 255, 177, 0),
                                  ),
                                  onPressed: () {
                                    saveAsFile();
                                  },
                                ),
                              ),

                              //Undo Button
                              SizedBox(
                                width: size.height * 0.15,
                                height: size.height * 0.15,
                                child: IconButton(
                                  icon: Image.asset(
                                    (changesOnText && _controller.undoStack.length > 1)?'assets/buttons/Undo_Button.png':'assets/buttons/Undo_Disabled.png',
                                    fit: BoxFit.scaleDown,
                                    //color: Color.fromARGB(255, 255, 177, 0),
                                  ),
                                  onPressed: () {
                                    changesOnText && _controller.undoStack.length > 1? _controller.undo() : null;// Only enable the button if there are changes to undo
                                    setState(() {
                                    });
                                  },
                                ),
                              ),

                              //Redo Button
                              SizedBox(
                                width: size.height * 0.15,
                                height: size.height * 0.15,
                                child: IconButton(
                                  icon: Image.asset(
                                    (_controller.redoStack.isNotEmpty)?'assets/buttons/Redo_Button.png':'assets/buttons/Redo_Disabled.png',
                                    fit: BoxFit.scaleDown,
                                    //color: Color.fromARGB(255, 255, 177, 0),
                                  ),
                                  onPressed: () {
                                    changesOnText && _controller.redoStack.isNotEmpty ? _controller.redo() : null;
                                    setState(() {
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        )),
                  )),

              //Home Button
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                left: constraints.maxWidth * 0.90,
                child: SizedBox(
                      width: size.height * 0.15,
                      height: size.height * 0.15,
                      child: IconButton(
                        icon: Image.asset(
                          'assets/buttons/homebttn.png',
                          fit: BoxFit.scaleDown,
                          //color: Color.fromARGB(255, 255, 177, 0),
                        ),
                        onPressed: () async {
                          // Prompt for save if changes are made
                          if (changesOnText == true) {
                            await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Save Changes?'),
                                  content: const Text('Do you want to save the changes you made to the file?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await saveFile();
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Yes'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => Homescreen(firstTime: false, userId: widget.userId)),
                          );
                        },
                      ),
                    ),
              ),

              //TextField

              Positioned(
                  left: constraints.maxWidth * 0.15,
                  top: constraints.maxHeight * 0.09,
                  // child: Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _changeFileName(context);
                    },

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //TAB
                      Container(
                        width: constraints.maxWidth * 0.2, // Limit the width of the container
                        height: constraints.maxHeight * 0.06,
                        decoration: const BoxDecoration(
                          color: Color(0xffFCCD73),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(20.0),
                            topLeft: Radius.circular(20.0),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.file_present,
                              size: constraints.maxHeight * 0.030,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$_fileName.txt",
                                maxLines: 1, // Limit to one line
                                overflow: TextOverflow.ellipsis, // Show ellipsis when text overflows
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: constraints.maxHeight * 0.025,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),


                      //TextArea
                      Container(
                        width: constraints.maxWidth * 0.65,
                        height: constraints.maxHeight * 0.80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xffFCCD73),
                            width: 20,
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(
                                20.0), // Specify top right radius
                            bottomLeft: Radius.circular(
                                20.0), // Specify bottom left radius
                            bottomRight: Radius.circular(
                                20.0), // Specify bottom right radius
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                        child: textWidget(),
                      ),
                    ],
                  ))),
              // ),

            ],
          );
        }),
      ),
    );
  }



  //the textfield
  Widget textWidget() {
    return TextField(
      controller: _controller.textEditingController,
      decoration: const InputDecoration(
        border: InputBorder.none, // Remove default border
      ),
      textInputAction:
      TextInputAction.newline, // Set text input action to newline
      keyboardType: TextInputType.multiline, // Enable multiline input
      maxLines: null, // Allow unlimited number of lines
      onSubmitted: (String value) {
        // Handle submitted text
      },
      onChanged: (value) {
        String trimmedFileContent = normalizeText(fileContent!);
        String trimmedValue = normalizeText(value);

        setState(() {
          changesOnText = trimmedValue != trimmedFileContent;
          print(changesOnText);
          _controller.performAction(value);
        });
      },
      onEditingComplete: () {
        // Handle editing complete event
      },
    );
  }

  Future<void> _loadFolders() async {
    List<Folder> folders = [];
    try {
      QuerySnapshot querySnapshot = await FileSystem.get();
      for (var doc in querySnapshot.docs) {
        if (doc['type'] == 'disk') {
          folders.add(Folder(id: doc.id, name: doc['name'], path: doc['path'], userId: widget.userId));
        } else if (doc['type'] == 'folder' && doc['userId'] == widget.userId) {
          folders.add(Folder(id: doc.id, name: doc['name'], path: doc['path'], userId: doc['userId']));
        }
      }

      setState(() {
        this.folders = folders;
      });

    } catch (e) {
      print("Error loading files and folders: $e");
    }
  }

  void _changeFileName(BuildContext context) {
    _speak("Enter the new file name, honey.");
    Timer(const Duration(seconds: 1), () {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FileNameWidget(fileName: _fileName,
          onFileNameChanged: (String newFileName) async {
            setState(() {
              _fileName = newFileName;
            });

            if (widget.fileName != null && widget.fileContent != null && widget.fileId != null && widget.saveLocation != null) {
              await FileSystem.doc(widget.fileId).update({
                'name': newFileName,
              });

            }

            if (newFileName.length > 20) {
              _speak("The file name has been changed to ${newFileName.substring(0, 20)}.");
            } else {
              _speak("The file name has been changed to $newFileName.");
            }
          },

        );
      },
    );
    });
  }

  //openfile
  Future<void> openFile() async {
    fileExplorerShown = true;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      allowMultiple: false,
    );


    if (result != null && result.files.isNotEmpty) {
     PlatformFile file = result.files.first;
      fileContent = file.bytes != null ? utf8.decode(file.bytes!) : null;
      _fileName = file.name.length > 20 ? file.name.substring(0, 20) : file.name;




      // Do something with the file content (e.g., display it in TextField)
      _controller.textEditingController.text = normalizeText(fileContent!);
      fileOpened = true;
      fileExplorerShown = false;
      _responseSpoken = false;
      changesOnText = false;
      setState(() {});

    } else {
      fileOpened=false;
      _speak("Honey, no file was selected.");
      fileExplorerShown = false;
    }
  }

  String normalizeText(String text) {
    // Replace all occurrences of '\r\n' or '\r' with '\n'
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Trim leading and trailing whitespace
    return text.trim();
  }

  //createfile
  void createFile() {
    _controller.textEditingController.clear();
    _controller.performAction('');
    _fileName = 'Untitled';
    fileOpened = false;
    changesOnText = false;
    setState(() {});
  }

  //save
  Future<void> saveFile() async {
    String folderName = saveLocation != ''  ? saveLocation.substring(saveLocation.lastIndexOf('/') + 1) : '';
  try {
    if (saveLocation != '' && _fileId != '') {

        await FileSystem.doc(_fileId).update({
          'content': _controller.textEditingController.text,
          'name': _fileName,
        });
        _speak("The file has been saved.");
        changesOnText = false;



        // Go to the file

    } else if (saveLocation != ''){
      String baseName = _fileName;
      int duplicateCount = 0;
      bool nameExists = true;

      while (nameExists) {
        // Query Firestore for a folder with the same name and path
        var querySnapshot = await FileSystem
            .where('name', isEqualTo: _fileName)
            .where('path', isEqualTo: saveLocation)
            .where('type', isEqualTo: 'file')
            .get();

        // Check if the query returned any documents
        if (querySnapshot.docs.isEmpty) {
          // If no documents were returned, the name doesn't exist
          nameExists = false;
        } else {
          // If any documents were returned, increment the duplicate count and append it to the base name
          duplicateCount++;
          _fileName = '$baseName($duplicateCount)';
        }
      }

      await FileSystem.add({
        'content': _controller.textEditingController.text,
        'name': _fileName,
        'path': saveLocation,
        'type': 'file',
        'userId': widget.userId,
      });
      _speak("The file has been saved.");
    } else {
      String? selectedFolder = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return FolderPickerDialog(
            userId: widget.userId,
            folders: folders,
            onPathSelected: (String path) {
              Navigator.pop(context, path);
            },
          );
        },
      );

      if (selectedFolder != null) {
        saveLocation = selectedFolder;
        folderName = saveLocation.substring(saveLocation.lastIndexOf('/') + 1);
        String baseName = _fileName;
        int duplicateCount = 0;
        bool nameExists = true;

        while (nameExists) {
          // Query Firestore for a folder with the same name and path
          var querySnapshot = await FileSystem
              .where('name', isEqualTo: _fileName)
              .where('path', isEqualTo: saveLocation)
              .where('type', isEqualTo: 'file')
              .where('userId', isEqualTo: widget.userId)
              .get();

          // Check if the query returned any documents
          if (querySnapshot.docs.isEmpty) {
            // If no documents were returned, the name doesn't exist
            nameExists = false;
          } else {
            // If any documents were returned, increment the duplicate count and append it to the base name
            duplicateCount++;
            _fileName = '$baseName($duplicateCount)';
          }
        }

        await FileSystem.add({
          'content': _controller.textEditingController.text,
          'name': _fileName,
          'path': saveLocation,
          'type': 'file',
          'userId': widget.userId,
        });
        _speak("The file has been saved.");
        changesOnText = false;
      } else {
        _speak("No location was selected.");
        return;
      }
    }

    Timer(const Duration(seconds: 1), () {
      if (mounted) { // Check if the State is still mounted
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Files(
            headerName: folderName,
            currentPath: saveLocation,
            userId: widget.userId
          )
          ),
        );
      }
    });
  } catch (e) {
    print("Error saving file: $e");
  }

  }

  //saveAs
  Future<void> saveAsFile() async {
    String? selectedFolder = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return FolderPickerDialog(
          userId: widget.userId,
          folders: folders,
          onPathSelected: (String path) {
            Navigator.pop(context, path);
          },
        );
      },
    );

    if (selectedFolder != null) {
      saveLocation = selectedFolder;
      String folderName = saveLocation.substring(saveLocation.lastIndexOf('/') + 1);
      String baseName = _fileName;
      int duplicateCount = 0;
      bool nameExists = true;

      while (nameExists) {
        // Query Firestore for a folder with the same name and path
        var querySnapshot = await FileSystem
            .where('name', isEqualTo: _fileName)
            .where('path', isEqualTo: saveLocation)
            .where('type', isEqualTo: 'file')
            .where('userId', isEqualTo: widget.userId)
            .get();

        // Check if the query returned any documents
        if (querySnapshot.docs.isEmpty) {
          // If no documents were returned, the name doesn't exist
          nameExists = false;
        } else {
          // If any documents were returned, increment the duplicate count and append it to the base name
          duplicateCount++;
          _fileName = '$baseName($duplicateCount)';
        }
      }

      await FileSystem.add({
        'content': _controller.textEditingController.text,
        'name': _fileName,
        'path': saveLocation,
        'type': 'file',
        'userId': widget.userId,
      });
      _speak("The file has been saved.");
      changesOnText = false;
      Timer(const Duration(seconds: 1), () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Files(
          headerName: folderName,
          currentPath: saveLocation,
          userId: widget.userId,
        )
        ),
      ));
    } else {
      _speak("No location was selected.");
      return;
    }




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
    if(command.contains('create a file')){

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is already open.");
        return;
      }

      _speak("Creating a new file.");
      createFile();
    }

    else if(command.contains('open')){
      if (fileExplorerShown) {
        _speak("Honey, the file explorer is already open.");
        return;
      }

        _speak("Please choose a file to open.");
        Timer(const Duration(seconds: 2), () => openFile());

    }

    else if(command.contains('save')){

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      //savefunctions
      saveFile();
    }

    else if(command.contains('save as')){

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      saveAsFile();

    }

    else if(command.contains('undo the changes')){

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      if (changesOnText && _controller.undoStack.length > 1) {
        _speak("Undoing the changes.");
        _controller.undo();
        setState(() {});
      } else {
        _speak("Honey, there are no changes to undo.");
      }
    }

    else if(command.contains('redo the changes')){

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      if (changesOnText && _controller.redoStack.isNotEmpty) {
        _speak("Redoing the changes.");
        _controller.redo();
        setState(() {});
      } else {
        _speak("Honey, there are no changes to redo.");
      }
    }

    else if(command.contains('home')){
      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (changesOnText == true) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Save Changes?'),
              content: const Text('Do you want to save the changes you made to the file?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    await saveFile();
                    Navigator.pop(context);
                  },
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Homescreen(firstTime: false, userId: widget.userId)),
      );
    }

    else if (command.contains('clear all')) {

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      _controller.textEditingController.clear();
      _controller.performAction('');
      fileOpened = false;
      changesOnText = false;
      _speak("All text has been cleared.");
    }

    else if (command.contains('write the following')) {
      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      String textToWrite = command.substring(command.indexOf("write the following") + 19, command.indexOf(" please"));
      // Add the text to the text field not replacing the previous text if any
      _controller.textEditingController.text += textToWrite;
      _controller.performAction(_controller.textEditingController.text);
      changesOnText = true;
      _speak("The text has been written.");
    }

    else if (command.contains('read the text')) {

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      if (_controller.textEditingController.text.isEmpty) {
        _speak("Honey, there is no text to read.");
      } else {
        _speak(_controller.textEditingController.text);
      }

    }

    else if (command.contains('help')) {
      _speak("You can create a file, open a file, save, save as, undo the changes, redo the changes, clear all text, write the following, read the following, or go home.");
    }

    else if (command.contains('name it')) {

      if (fileExplorerShown) {
        _speak("Honey, the file explorer is open. Please close it first.");
        return;
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }


      String newName = command.substring(command.indexOf("name it") + 8, command.indexOf(" please"));
      _fileName = newName;

      setState(() {});
      Timer(const Duration(milliseconds: 500), () => _speak("The file has been renamed to $newName."));
    } else if (command.contains("Sir Robert")){
      _speak("Sir Robert is a very handsome and intelligent person. He is the best teacher in the world.");
    } else if (command.contains("stop")) {
      _speak("Stopping, honey.");

    } else if (command.contains("file name")) {
      _speak("The file name is $_fileName.");
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
      Timer(const Duration(milliseconds: 500), () => _speak("You are now in the file screen."));


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
      alignment: Alignment.topCenter,
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

class FileNameWidget extends StatefulWidget {
  final String fileName;
  final Function(String) onFileNameChanged;

  const FileNameWidget({super.key, required this.fileName, required this.onFileNameChanged});


  @override
  _FileNameWidgetState createState() => _FileNameWidgetState();
}

class _FileNameWidgetState extends State<FileNameWidget> {
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  late String fileName;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    fileName = widget.fileName;
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
    TextEditingController controller =
    TextEditingController(text: fileName);

    return Scaffold( // Wrap your widget with Scaffold
      backgroundColor: Colors.transparent, // Set the background color to transparent
      body: Center(
        child: Stack(
          children: [
            // Background Image
            Center(
              child: Image.asset(
                'assets/background/name_background.png', // Replace with your image path
              ),
            ),
            // Text Input Field
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 130.0, 20.0, 10.0),
                child: TextField(
                  controller: controller,
                  maxLength: 20, // Set maximum length of the text field
                  decoration: const InputDecoration(
                    border: InputBorder.none, // Remove default border
                  ),
                  style: const TextStyle(
                    color: Colors.white, // Text color
                    fontSize: 55.0, // Text size
                    fontFamily: 'ABeeZee', // Text font
                  ),
                  textAlign: TextAlign.center, // Center-align text
                  textInputAction: TextInputAction.done, // Set text input action to done
                  keyboardType: TextInputType.text, // Enable text input
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                  ],
                ),
              ),
            ),
            // Dialog Actions
            Positioned(
              left: 20.0,
              right: 20.0,
              bottom: 10.0,
              top: 350.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(

                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel',
                      style: TextStyle(
                        color: Color.fromARGB(255, 237, 140, 0),
                        fontSize: 20.0,
                        fontFamily: 'ABeeZee',
                      ),
                  ),
                  ),
                  TextButton(
                    onPressed: () {
                      String newFileName = controller.text.trim();
                      if (newFileName.isEmpty) {
                        newFileName = "Untitled";
                      }

                      onFileNameChanged(newFileName);

                      Navigator.pop(context);
                    },
                    child: const Text('Save',
                      style: TextStyle(
                        color: Color.fromARGB(255, 237, 140, 0),
                        fontSize: 20.0,
                        fontFamily: 'ABeeZee',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onFileNameChanged(String newFileNameWithExtension) {
    widget.onFileNameChanged(newFileNameWithExtension);
  }
}


class FolderPickerDialog extends StatefulWidget {
  final List<Folder>? folders;
  final Function(String) onPathSelected;
  final String? userId;

  const FolderPickerDialog({super.key, required this.folders, required this.onPathSelected, this.userId});

  @override
  _FolderPickerDialogState createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late FlutterTts _flutterTts;
  late List<Folder>? folders;
  String currentPath = '/FileSystem';

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    folders = widget.folders;
    _speak("Please select a location to save the file.");
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
    List<Folder> subfolders = folders!.where((folder) => folder.path == currentPath).toList();

    return AlertDialog(
      title: const Text('Select a location to save the file'),
      content: SizedBox(
        width: 300.0,
        height: 300.0,
        child: Column(
          children: [
            if (currentPath != '/FileSystem') // Show back button if not at root
              ElevatedButton(
                onPressed: () {
                  currentPath = currentPath.substring(0, currentPath.lastIndexOf('/'));
                  setState(() {});
                },
                child: const Text('Back'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: subfolders.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    title: Text(subfolders[index].name),
                    onTap: () {
                      currentPath = '${subfolders[index].path}/${subfolders[index].name}';
                      setState(() {});
                    },
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                if (currentPath != '/FileSystem') // Show save button if not at root
                ElevatedButton(
                  onPressed: () {
                    widget.onPathSelected(currentPath);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0), // Adjust the value as needed
              child: Text(
                'Selected Path: $currentPath',
                style: const TextStyle(
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



