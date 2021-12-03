import 'package:flutter/material.dart';
import 'package:webrtc_signaling_server/screens/blind_vs_volunteer_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BlindVSVolunteerScreen(),
    );
  }
}
