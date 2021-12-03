import 'package:flutter/material.dart';
import 'package:webrtc_signaling_server/screens/call_screen_blind.dart';
import 'package:webrtc_signaling_server/screens/call_screen_volunteer.dart';

class BlindVSVolunteerScreen extends StatefulWidget {
  @override
  State<BlindVSVolunteerScreen> createState() => _BlindVSVolunteerScreenState();
}

class _BlindVSVolunteerScreenState extends State<BlindVSVolunteerScreen> {
  bool isBlind = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                isBlind = true;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallScreenBlind(isBlind: isBlind),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.blue,
                minimumSize: Size.fromWidth(double.infinity),
              ),
              child: Text(
                'Blind',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 32.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                isBlind = false;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallScreenVolunteer(isBlind: isBlind),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.purple,
                minimumSize: Size.fromWidth(double.infinity),
              ),
              child: Text(
                'Volunteer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 32.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
