import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:honey_os/UI/homescreen.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:honey_os/UI/viewfiles.dart';
import 'package:honey_os/UI/filescreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class File {

  final String id;
  final String name;
  final String path;
  final String content;
  final String userId;

  File({required this.id, required this.name, required this.path, required this.content, required this.userId});

  factory File.fromJson(Map<String, dynamic> json) {
    return File(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      content: json['content'],
      userId: json['userId'],
    );
  }

  @override
  String toString() {
    return 'File{id: $id, name: $name, path: $path, content: $content, userId: $userId}';
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

class Files extends StatefulWidget {

  const Files({super.key, this.headerName, this.currentPath, required this.userId});

  final String? headerName;
  final String? currentPath;
  final String userId;

  @override
  State<Files> createState() => _FilesState();
}

class _FilesState extends State<Files> {
  late String _headerName;
  final CollectionReference FileSystem = FirebaseFirestore.instance.collection('FileSystem');
  List<File>? files;
  List<Folder>? folders;
  late String _fileName;
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
  bool fileOpened = false;
  String fileContent = '';




  @override
  void initState() {

    super.initState();
    _loadFoldersAndFiles();
    _initTTS();
    _initSpeech();
    _startSpeechCheckTimer(); // Start the timer when the screen is initialized
    _headerName = widget.headerName ?? "";

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
                        MaterialPageRoute(builder: (context) => Homescreen(firstTime: false, userId: widget.userId,)),
                      );
                    },
                  ),
                ),
              ),

              //Back Button
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                right: constraints.maxWidth * 0.70,
                child: SizedBox(
                  width: size.height * 0.15,
                  height: size.height * 0.15,
                  child: IconButton(
                    icon: Image.asset(
                      'assets/buttons/Back.png',
                      fit: BoxFit.scaleDown,
                    ),
                    onPressed: () {

                      int count = widget.currentPath!.split('/').length - 1;
                      print(count);
                      if (count > 2) {
                        // Remove the last component of the path
                        List<String> pathComponents = widget.currentPath!.split('/');
                        print (pathComponents);
                        pathComponents.removeLast();
                        String newPath = pathComponents.join('/');
                        print(newPath);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => Files(
                            headerName: pathComponents[count - 1],
                            currentPath: newPath,
                            userId: widget.userId,
                          )),
                        );
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => ViewFiles(userId: widget.userId)),
                        );
                      }
                    },
                  ),
                ),
              ),

              //Header
              Positioned(
                top: constraints.maxHeight * 0.02,
                left: constraints.maxWidth * 0.05,
                child: SizedBox(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.1,
                  child: Text(
                    _headerName,
                    style: const TextStyle(
                      fontFamily: 'ABeeZee',
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Files and Folders
              Positioned(
                top: constraints.maxHeight * 0.13,
                left: constraints.maxWidth * 0.05,
                child: Container(
                  width: constraints.maxWidth * 0.907,
                  height: constraints.maxHeight * 0.67,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(157, 138, 105, 83),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: files == null && folders == null
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : files!.isEmpty && folders!.isEmpty

                      ?

                  const Center(

                    child: Text(
                      'No files or folders',
                      style: TextStyle(
                        fontFamily: 'ABeeZee',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  )

                      :


                  SingleChildScrollView(
                    child: ListView.builder(
                      shrinkWrap: true, // Ensure that ListView takes only the space it needs
                      physics: const NeverScrollableScrollPhysics(), // Disable scrolling for the inner ListView
                      itemCount: ((folders!.length + files!.length) / 9).ceil(),
                      itemBuilder: (context, rowIndex) {
                        return Row(

                          children: [
                            for (int i = 0; i < 9; i++)
                              if (rowIndex * 9 + i < folders!.length)

                                GestureDetector(
                                    onLongPress: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                title: const Text('Delete'),
                                                onTap: () async {
                                                  try {
                                                    await FileSystem.doc(folders?[rowIndex * 9 + i].id).delete();
                                                    _loadFoldersAndFiles();
                                                    Navigator.of(context).pop();
                                                  } catch (e) {
                                                    print('Error deleting folder: $e');
                                                  }
                                                },
                                              ),
                                              ListTile(
                                                title: const Text('Rename'),
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text('Rename Folder'),
                                                        content: TextField(
                                                          decoration: const InputDecoration(
                                                            hintText: 'Folder Name',
                                                          ),
                                                          maxLength: 20,
                                                          controller: TextEditingController(text: folders?[rowIndex * 9 + i].name),
                                                          onChanged: (value) {
                                                            _fileName = value;
                                                          },
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: const Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () async {
                                                              try {
                                                                String baseName = _fileName;
                                                                int duplicateCount = 0;
                                                                bool nameExists = true;

                                                                while (nameExists) {
                                                                  // Query Firestore for a folder with the same name and path
                                                                  var querySnapshot = await FileSystem
                                                                      .where('name', isEqualTo: _fileName)
                                                                      .where('path', isEqualTo: widget.currentPath)
                                                                      .where('type', isEqualTo: 'folder')
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

                                                                await FileSystem.doc(folders?[rowIndex * 9 + i].id).update({'name': _fileName});
                                                                _loadFoldersAndFiles();
                                                                while (Navigator.canPop(context)) {
                                                                  Navigator.pop(context);
                                                                }
                                                              } catch (e) {
                                                                print('Error renaming folder: $e');
                                                              }
                                                            },
                                                            child: const Text('Submit'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },

                                    child: SizedBox(
                                  width: constraints.maxWidth * 0.1,
                                  height: constraints.maxHeight * 0.24,
                                  child: Column(
                                    children: [
                                      IconButton(
                                        icon: Image.asset(
                                          'assets/Folder.png',
                                          fit: BoxFit.scaleDown,
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (context) => Files(
                                              userId: widget.userId,
                                              headerName: folders?[rowIndex * 9 + i].name,
                                              currentPath: '${folders?[rowIndex * 9 + i].path}/${folders?[rowIndex * 9 + i].name}',
                                            )),
                                          );
                                        },
                                      ),

                                      Text(
                                        folders![rowIndex * 9 + i].name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'ABeeZee',
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),

                                )
                                )


                              else if (rowIndex * 9 + i - folders!.length < files!.length)
                        GestureDetector(
                          onLongPress: () {
                            // Position the menu close to the long-pressed item
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext context) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('Delete'),
                                      onTap: () async {
                                        try {

                                          await FileSystem.doc(files![rowIndex * 9 + i - folders!.length].id).delete();
                                          _loadFoldersAndFiles();
                                          Navigator.of(context).pop();

                                        } catch (e) {
                                          print('Error deleting file: $e');
                                        }
                                      },
                                    ),
                                    ListTile(
                                      title: const Text('Rename'),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('Rename File'),
                                              content: TextField(
                                                decoration: const InputDecoration(
                                                  hintText: 'File Name',
                                                ),
                                                controller: TextEditingController(text: files![rowIndex * 9 + i - folders!.length].name),
                                                maxLength: 20,
                                                onChanged: (value) {
                                                  _fileName = value;
                                                },
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    try {
                                                      String baseName = _fileName;
                                                      int duplicateCount = 0;
                                                      bool nameExists = true;

                                                      while (nameExists) {
                                                        // Query Firestore for a folder with the same name and path
                                                        var querySnapshot = await FileSystem
                                                            .where('name', isEqualTo: _fileName)
                                                            .where('path', isEqualTo: widget.currentPath)
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

                                                      await FileSystem.doc(files![rowIndex * 9 + i - folders!.length].id).update({'name': _fileName});
                                                      _loadFoldersAndFiles();
                                                      while (Navigator.canPop(context)) {
                                                        Navigator.pop(context);
                                                      }
                                                    } catch (e) {
                                                      print('Error renaming file: $e');
                                                    }
                                                  },
                                                  child: const Text('Submit'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },

                          child:
                                SizedBox(
                                  width: constraints.maxWidth * 0.1,
                                  height: constraints.maxHeight * 0.24,
                                  child: Column(
                                    children: [
                                      IconButton(
                                        icon: Image.asset(
                                          'assets/File.png',
                                          fit: BoxFit.scaleDown,
                                        ),
                                        onPressed: () async {

                                          while (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          }

                                          _fileName = files![rowIndex * 9 + i - folders!.length].name;
                                          fileContent = files![rowIndex * 9 + i - folders!.length].content;

                                          setState(() {
                                            fileOpened = true;
                                          });

                                       Timer(const Duration(milliseconds: 100), () async {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return OpenedFile(
                                                fileName: _fileName,
                                                fileContent: fileContent,
                                                saveLocation: widget.currentPath!,
                                                fileId: files![rowIndex * 9 + i - folders!.length].id,
                                                userId: widget.userId!,
                                              );
                                            },
                                          ).then((value) => fileOpened = false);
                                        });
                                        },
                                      ),
                                      Text(
                                        '${files![rowIndex * 9 + i - folders!.length].name}.txt',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'ABeeZee',
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                        )
                              else
                                SizedBox(
                                  width: constraints.maxWidth * 0.1,
                                  height: constraints.maxHeight * 0.24,
                                ),

                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              //Add Folder
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                right: constraints.maxWidth * 0.60,
                child: SizedBox(
                  width: size.height * 0.15,
                  height: size.height * 0.15,
                  child: IconButton(
                    icon: Image.asset(
                      'assets/buttons/CreateFolder.png',
                      fit: BoxFit.scaleDown,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Add Folder'),
                            content: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Folder Name',
                              ),
                              controller: TextEditingController(text: 'Untitled'),
                              maxLength: 20,
                              onChanged: (value) {
                                _fileName = value;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    String baseName = _fileName;
                                    int duplicateCount = 0;
                                    bool nameExists = true;

                                    while (nameExists) {
                                      // Query Firestore for a folder with the same name and path
                                      var querySnapshot = await FileSystem
                                          .where('name', isEqualTo: _fileName)
                                          .where('path', isEqualTo: widget.currentPath)
                                          .where('type', isEqualTo: 'folder')
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

                                    // Add the new folder with the unique name
                                    await FileSystem.add({'name': _fileName, 'path': widget.currentPath, 'type': 'folder', 'userId': widget.userId});
                                    _loadFoldersAndFiles();
                                    Navigator.of(context).pop();
                                    _speak("The folder $_fileName has been created, honey.");
                                  } catch (e) {
                                    print('Error adding folder: $e');
                                  }
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              //Add File
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                right: constraints.maxWidth * 0.50,
                child: SizedBox(
                  width: size.height * 0.15,
                  height: size.height * 0.15,
                  child: IconButton(
                    icon: Image.asset(
                      'assets/buttons/CreateFile.png',
                      fit: BoxFit.scaleDown,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => FileScreen(
                        userId: widget.userId,
                        saveLocation: widget.currentPath,
                      )));
                    },
                  ),
                ),
              ),

            ],
          );
        }),
      ),
    );
  }

  Future<void> _loadFoldersAndFiles() async {
    List<File> files = [];
    List<Folder> folders = [];
    try {
      QuerySnapshot querySnapshot = await FileSystem.where('path', isEqualTo: widget.currentPath).get();
      for (var doc in querySnapshot.docs) {
        if (doc['type'] == 'folder' && doc['userId'] == widget.userId) {
          folders.add(Folder(id: doc.id, name: doc['name'], path: doc['path'], userId: doc['userId']));
        } else if (doc['type'] == 'file' && doc['userId'] == widget.userId) {
          files.add(File(id: doc.id, name: doc['name'], path: doc['path'], content: doc['content'], userId: doc['userId']));
        }
      }

      setState(() {
        this.files = files;
        this.folders = folders;
      });



    } catch (e) {
      print("Error loading files and folders: $e");
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

      if(command.contains('home')){

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Homescreen(firstTime: false, userId: widget.userId)),
        );
      }

      else if (command.contains('open the file')) {
        if (fileOpened) {
          _speak("A file is already open, honey.");
        } else {
          String fileName = command.substring(command.indexOf('file') + 5, command.indexOf(' please')).trim();
          try {

            File? file = files?.firstWhere((element) => element.name.toLowerCase() == fileName.toLowerCase(), orElse: () => File(id: '', name: '', path: '', content: '', userId: ''));
            if (file!.name != '' && file.content != '' && file.path != '') {
              _speak("The file $fileName has been opened, honey.");
              setState(() {
                fileOpened = true;
              });

              Timer(const Duration(milliseconds: 100), () async {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return OpenedFile(
                      fileName: file.name,
                      fileContent: file.content,
                      saveLocation: widget.currentPath!,
                      fileId: file.id,
                      userId: widget.userId!,
                    );
                  },
                ).then((value) => fileOpened = false);
              });
            } else {
              _speak("The file $fileName does not exist, honey.");
            }
          } catch (e) {
            print('Error opening file: $e');
          }
        }
      } else if (command.contains("open the folder")) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Timer(const Duration(milliseconds: 500), () async {
          String folderName = command.substring(command.indexOf('folder') + 7, command.indexOf(' please')).trim();
          try {

            Folder? folder = folders?.firstWhere((element) => element.name.toLowerCase() == folderName.toLowerCase(), orElse: () => Folder(id: '', name: '', path: '', userId: ''));

            if (folder!.name != '' && folder.path != '') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => Files(
                  userId: widget.userId,
                  headerName: folder.name,
                  currentPath: '${folder.path}/${folder.name}',
                )),
              );

            } else {
              _speak("The folder $folderName does not exist, honey.");
            }
          } catch (e) {
            print('Error opening folder: $e');
          }
        });


      }

      else if (command.contains('close the file')) {
        if (fileOpened && Navigator.canPop(context)) {
          Navigator.pop(context);
          _speak("The file has been closed, honey.");
          fileOpened = false;
        } else {
          _speak("There is no file open, honey.");
        }
      }

        else if (command.contains('create a new file')) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => FileScreen(
          userId: widget.userId,
          saveLocation: widget.currentPath,
        )));
        }

        else if (command.contains('create a new folder')) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

          // Extract the folder name from the command and limit it to only 20 characters truncate if necessary
          String fileName = command.substring(command.indexOf('folder') + 7, command.indexOf(' please'));
          fileName = fileName.length > 20 ? fileName.substring(0, 20) : fileName;
          
          try {
            String baseName = fileName;
            int duplicateCount = 0;
            bool nameExists = true;

            while (nameExists) {
              // Query Firestore for a folder with the same name and path
              var querySnapshot = await FileSystem
                  .where('name', isEqualTo: fileName)
                  .where('path', isEqualTo: widget.currentPath)
                  .where('type', isEqualTo: 'folder')
                  .where('userId', isEqualTo: widget.userId)
                  .get();

              // Check if the query returned any documents
              if (querySnapshot.docs.isEmpty) {
                // If no documents were returned, the name doesn't exist
                nameExists = false;
                _speak("The folder $fileName has been created, honey.");
              } else {
                // If any documents were returned, increment the duplicate count and append it to the base name
                duplicateCount++;
                fileName = '$baseName($duplicateCount)';
              }
            }
            
            

            // Add the new folder with the unique name
            await FileSystem.add({'name': fileName, 'path': widget.currentPath, 'type': 'folder', 'userId': widget.userId});
            _loadFoldersAndFiles();
          } catch (e) {
            print('Error adding folder: $e');
          }
          
        }

      else if (command.contains('delete the file')) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        String fileName = command.substring(command.indexOf('file') + 5, command.indexOf(' please')).trim();
        try {
      
          File? file = files!.firstWhere((element) => element.name.toLowerCase() == fileName.toLowerCase(), orElse: () => File(id: '', name: '', path: '', content: '', userId: ''));
          if (file.name != '' && file.content != '' && file.path != '') {
            await FileSystem.doc(file.id).delete();
            _loadFoldersAndFiles();
            _speak("The file $fileName has been deleted, honey.");
          } else {
            _speak("The file $fileName does not exist, honey.");
          }

          
        } catch (e) {
          print('Error deleting file: $e');
        }
      }

        else if (command.contains('delete the folder')) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        String fileName = command.substring(command.indexOf('folder') + 7, command.indexOf(' please')).trim();
        try {
   
          Folder? folder = folders!.firstWhere((element) => element.name.toLowerCase() == fileName.toLowerCase(), orElse: () => Folder(id: '', name: '', path: '', userId: ''));
          if (folder.name != '' && folder.path != '') {
            await FileSystem.doc(folder.id).delete();
            _loadFoldersAndFiles();
            _speak("The folder $fileName has been deleted, honey.");
          } else {
            _speak("The folder $fileName does not exist, honey.");
          }
        } catch (e) {
          print('Error deleting folder: $e');
        }
      }
        
        else if (command.contains('rename the file')) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

          String existingFileName = command.substring(command.indexOf('file') + 5, command.indexOf(' to'));
          String newFileName = command.substring(command.indexOf('to') + 3, command.indexOf(' please'));
          String existingFileId = '';
          try {
           File? file = files!.firstWhere((element) => element.name.toLowerCase() == existingFileName.toLowerCase(), orElse: () => File(id: '', name: '', path: '', content: '', userId: ''));
            if (file.name != '' && file.content != '' && file.path != '') {
              existingFileId = file.id;
              String baseName = newFileName;
              int duplicateCount = 0;
              bool nameExists = true;

              while (nameExists) {
                // Query Firestore for a folder with the same name and path
                var querySnapshot = await FileSystem
                    .where('name', isEqualTo: newFileName)
                    .where('path', isEqualTo: widget.currentPath)
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
                  newFileName = '$baseName($duplicateCount)';
                }
              }

              await FileSystem.doc(existingFileId).update({'name': newFileName});
              _loadFoldersAndFiles();
            } else {
              _speak("The file $existingFileName does not exist, honey.");
            }
          }catch (e) {
              print('Error renaming file: $e');
            }
            
          }
        

        else if (command.contains('rename the folder')) {

          while (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          String existingFolderName = command.substring(command.indexOf('folder') + 7, command.indexOf(' to'));
          String newFolderName = command.substring(command.indexOf('to') + 3, command.indexOf(' please'));
          String existingFolderId = '';
          try {
            Folder? folder = folders!.firstWhere((element) => element.name.toLowerCase() == existingFolderName.toLowerCase(), orElse: () => Folder(id: '', name: '', path: '', userId: ''));
            if (folder.name != '' && folder.path != '') {
              existingFolderId = folder.id;
              String baseName = newFolderName;
              int duplicateCount = 0;
              bool nameExists = true;

              while (nameExists) {
                // Query Firestore for a folder with the same name and path
                var querySnapshot = await FileSystem
                    .where('name', isEqualTo: newFolderName)
                    .where('path', isEqualTo: widget.currentPath)
                    .where('type', isEqualTo: 'folder')
                    .where('userId', isEqualTo: widget.userId)
                    .get();

                // Check if the query returned any documents
                if (querySnapshot.docs.isEmpty) {
                  // If no documents were returned, the name doesn't exist
                  nameExists = false;
                } else {
                  // If any documents were returned, increment the duplicate count and append it to the base name
                  duplicateCount++;
                  newFolderName = '$baseName($duplicateCount)';
                }
              }

              await FileSystem.doc(existingFolderId).update({'name': newFolderName});
              _loadFoldersAndFiles();
            } else {
              _speak("The folder $existingFolderName does not exist, honey.");
            }
          }catch (e) {
            print('Error renaming folder: $e');
          }
        }
        
      

      else if (command.contains('read the file')) {
        String fileName = command.substring(command.indexOf('file') + 5, command.indexOf(' please')).trim();
        try {
          File? file = files?.firstWhere((element) => element.name.toLowerCase() == fileName.toLowerCase(), orElse: () => File(id: '', name: '', path: '', content: '', userId: ''));
          if (file!.name != '' && file.content != '' && file.path != '') {
            _speak("The file $fileName has been opened, honey.");
            setState(() {
              fileOpened = true;
            });

            Timer(const Duration(milliseconds: 500), () async {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return OpenedFile(
                    fileName: file.name,
                    fileContent: file.content,
                    saveLocation: widget.currentPath!,
                    fileId: file.id,
                    userId: widget.userId!,
                  );
                },
              ).then((value) => fileOpened = false);
            });
            
          } else {
            _speak("The file $fileName does not exist, honey.");
          }
        } catch (e) {
          print('Error reading file: $e');
        }
      }

      else if (command.contains('read the text')) {
        if (fileOpened) {
          _speak(fileContent);
        } else {
          _speak("There is no file open, honey.");
        }
      }

      else if(command.contains('file name')) {
        if (fileOpened) {
          _speak("The file name is $_fileName, honey.");
        } else {
          _speak("There is no file open, honey.");
        }
      }

      else if (command.contains('help')) {
        _speak("You can create a new file, create a new folder, delete a file, delete a folder, rename a file, rename a folder, open a file, close a file, read the file, read the text, or go back, honey.");
      } else if (command.contains("Sir Robert")){
        _speak("Sir Robert is a very handsome and intelligent person. He is the best teacher in the world.");
      } else if (command.contains("go back")) {

        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        int count = widget.currentPath!.split('/').length - 1;
        if (count > 2) {
          List<String> pathComponents = widget.currentPath!.split('/');
          pathComponents.removeLast();
          String newPath = '${pathComponents.join('/')}/';
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) =>
                Files(
                  userId: widget.userId,
                  headerName: pathComponents[count - 1],
                  currentPath: newPath,
                )),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ViewFiles(userId: widget.userId)),
          );
        }
      } else if (command.contains("stop")) {
        _speak("Stopping, honey.");

      }  else if (command.contains("time")) {
        _speak("The current time is ${DateTime.now().hour}:${DateTime.now().minute} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}");
      } else {
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
      Timer(const Duration(milliseconds: 500), () => _speak("You are now inside $_headerName"));


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

class OpenedFile extends StatefulWidget {
  const OpenedFile({super.key, required this.fileName, required this.fileContent, required this.saveLocation, required this.fileId, required this.userId});

  final String fileName;
  final String fileContent;
  final String saveLocation;
  final String fileId;
  final String userId;

  @override
  _OpenedFileState createState() => _OpenedFileState();
}

class _OpenedFileState extends State<OpenedFile> {

  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();

    _speak("You are now viewing ${widget.fileName}. ${widget.fileContent}");
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: [
              // File Name
              Positioned(
                top: constraints.maxHeight * 0.02,
                left: constraints.maxWidth * 0.05,
                child: SizedBox(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.1,
                  child: Text(
                    widget.fileName,
                    style: const TextStyle(
                      fontFamily: 'ABeeZee',
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // File Content
              Positioned(
                top: constraints.maxHeight * 0.13,
                left: constraints.maxWidth * 0.05,
                child: Container(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.67,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 237, 140, 0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                    child: Text(
                      widget.fileContent,
                      style: const TextStyle(

                        fontFamily: 'ABeeZee',
                        fontSize: 20,
                        color: Colors.white,
                      )
                    ),
                    ),
                  ),
                ),
              ),
              // Edit Button
              Positioned(
                bottom: constraints.maxHeight * 0.03,
                right: constraints.maxWidth * 0.45,
                child: SizedBox(
                  width: 200,
                  height: 75,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 237, 140, 0),
                      backgroundColor: const Color.fromARGB(255, 237, 140, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => FileScreen(
                        userId: widget.userId,
                        saveLocation: widget.saveLocation,
                        fileName: widget.fileName,
                        fileContent: widget.fileContent,
                        fileId: widget.fileId,
                      )));
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'ABeeZee',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),


              // Close Button
              Positioned(
                top: constraints.maxHeight * 0.02,
                right: constraints.maxWidth * 0.05,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}



