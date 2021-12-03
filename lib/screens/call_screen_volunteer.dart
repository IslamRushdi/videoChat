import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:webrtc_signaling_server/utils/utils.dart';

class CallScreenVolunteer extends StatefulWidget {
  final bool isBlind;

  const CallScreenVolunteer({
    Key? key,
    required this.isBlind,
  }) : super(key: key);

  @override
  _CallScreenVolunteerState createState() => _CallScreenVolunteerState();
}

class _CallScreenVolunteerState extends State<CallScreenVolunteer> {
  String? _blindId;
  String? _volunteerId;

  String? _volunteerSdp;
  Map<String, dynamic>? _firstCandidate;

  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  late Socket socket;

  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    socket.disconnect();

    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    _initSocketConnection();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });

    // _getUserMedia();
    super.initState();
  }

  initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _initSocketConnection() {
    //ws://ad30-41-234-2-218.ngrok.io/
    socket = io(
      'http://localhost:5000',
      OptionBuilder().setTransports(['websocket']) // for Flutter or Dart VM
          .build(),
    ).open();
    socket.onConnect((_) {
      print("connected");
      _volunteerId = socket.id;
      print("connected to room with id:$_volunteerId");

      print("isBlind: ${widget.isBlind}");
      socket.emit("volunteer: connect to room");
      socket
          .on("server: send blind connection to all volunteers to create offer",
              (blindData) {
        blindData = blindData as Map<String, dynamic>;
        final String blindSdp = blindData['sdp']! as String;
        _blindId = blindData['id']! as String;

        // print("blindSdp: $blindSdp");
        //print("id: $_blindId");
        print('recieving sdp');
        _setRemoteDescription(blindSdp);
      });
    });
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (RTCIceCandidate e) {
      if (e.candidate != null && _firstCandidate == null) {
        Map<String, dynamic> candidateConstraints = {
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        };

        _firstCandidate = candidateConstraints;

        print(candidateConstraints);
        print("_blindId= $_blindId");

        if (_blindId != null) {
          Map<String, dynamic> candidateInvitation = {
            "candidate": candidateConstraints,
            "sdp": _volunteerSdp,
            "blindId": _blindId!,
          };

          socket.emit(
            'volunteer: send sdp, candidate and blind id',
            candidateInvitation,
          );
          print('sending sdp...');
        }
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;

    return stream;
  }

  void _createAnswer() async {
    //_handleReceivingBlindCandidate();

    RTCSessionDescription description =
        await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});
    if (description.sdp != null) _volunteerSdp = description.sdp;

    _peerConnection!.setLocalDescription(description);
  }

  void _setRemoteDescription(String sdp) async {
    // RTCSessionDescription description =
    //     new RTCSessionDescription(session['sdp'], session['type']);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');

    await _peerConnection!.setRemoteDescription(description);
    print('remote description is set');
  }

  void _handleReceivingBlindCandidate() {
    socket.on('server: send blind candidate', (blindCandidate) async {
      blindCandidate = blindCandidate as Map<String, dynamic>;

      print(blindCandidate['candidate']);
      RTCIceCandidate candidate = new RTCIceCandidate(
        blindCandidate['candidate'],
        blindCandidate['sdpMid'],
        blindCandidate['sdpMlineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    });
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        Flexible(
          child: new Container(
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)),
        ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton(
          onPressed: () {
            _createAnswer();

            /* 
              
              ### Since volunteer client: ###
              
              1. offers his candidate on initialization
              2. listens to blind sdp and sets it from connect (connect uses setRemoteDescription)
              3. offers his sdp using create answer 
              4. listens to volunteer candidate and sets it from add candidate
              
              ### Therefore volunteer client: ###
              
               Ready and good to go 

               */
          },
          child: Text('Answer & join call'),
          style: ElevatedButton.styleFrom(primary: Colors.blue),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Video Conference'),
        ),
        body: Container(
            child: Container(
                child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
          ],
        ))
            // new Stack(
            //   children: [
            //     new Positioned(
            //       top: 0.0,
            //       right: 0.0,
            //       left: 0.0,
            //       bottom: 0.0,
            //       child: new Container(
            //         child: new RTCVideoView(_localRenderer)
            //       )
            //     )
            //   ],
            // ),
            ));
  }
}
