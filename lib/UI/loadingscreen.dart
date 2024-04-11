import 'dart:async';
import 'package:flutter/material.dart';
import 'package:honey_os/UI/userscreen.dart';

class LoadingScreen extends StatefulWidget{
  const LoadingScreen({super.key});

  @override
  _LoadingScreen createState() => _LoadingScreen();
}

class _LoadingScreen extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Start the timer in initState
    startTimer();
  }

  void startTimer() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) { // Check if the widget is still mounted before pushing
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UserScreen())
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Image.asset('newloadingscreen.gif', fit: BoxFit.fill),
        ),
      ),
    );
  }
}
