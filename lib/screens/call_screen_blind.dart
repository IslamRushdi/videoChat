import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:webrtc_signaling_server/utils/utils.dart';

class CallScreenBlind extends StatefulWidget {
  final bool isBlind;

  const CallScreenBlind({
    Key? key,
    required this.isBlind,
  }) : super(key: key);

  @override
  _CallScreenBlindState createState() => _CallScreenBlindState();
}

class _CallScreenBlindState extends State<CallScreenBlind> {
  String? blindId;

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
      blindId = socket.id;
      print("connected to server with id:$blindId");

      print("isBlind: ${widget.isBlind}");
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

  void _createOffer() async {
    _handleReceivingNoVolunteerFound();

    RTCSessionDescription description =
        await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    String blindSdp = description.sdp!;
    socket.emit("blind: send sdp", blindSdp);
    print("sending sdp...");
    _offer = true;
    _peerConnection!.setLocalDescription(description);
    _handleReceivingVolunteerCandidate();
  }

  void _handleReceivingNoVolunteerFound() {
    socket.on("server: no volunteer found", (_) {
      showSnackBar(context, "No volunteer found");
    });
  }

  void _handleReceivingVolunteerCandidate() {
    socket.on('server: send volunteer candidate and sdp',
        (volunteerCandidateAndSdp) async {
      Map<String, dynamic> volunteerCandidate =
          volunteerCandidateAndSdp['candidate'] as Map<String, dynamic>;

      String volunteerSdp = volunteerCandidateAndSdp['sdp'] as String;

      RTCIceCandidate candidate = new RTCIceCandidate(
        volunteerCandidate['candidate'],
        volunteerCandidate['sdpMid'],
        volunteerCandidate['sdpMlineIndex'],
      );
      print('recieving sdp...');
      await _setRemoteDescription(volunteerSdp);
      print('Remote sdp is set');
      await _peerConnection!.addCandidate(candidate);
      print('candidate is set');
    });
  }

  Future<void> _setRemoteDescription(String sdp) async {
    // RTCSessionDescription description =
    //     new RTCSessionDescription(session['sdp'], session['type']);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print('Remote Description is set');

    await _peerConnection!.setRemoteDescription(description);
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
          // onPressed: () {
          //   return showDialog(
          //       context: context,
          //       builder: (context) {
          //         return AlertDialog(
          //           content: Text(sdpController.text),
          //         );
          //       });
          // },
          onPressed: () {
            // blind client creates the offer by sending his own sdp
            _createOffer();
            // blind client awaits for getting volunteer sdp
            // blind client listens and sets the volunteer sdp parameters in call
            // blind client  listens and sets the volunteer candidate parameters in call
            // _addCandidate();

            /* 
              
              ### Since blind client: ###
              
              1. offers his candidate on initialization
              2. offers his sdp using create offer
              3. listens to volnteer sdp and sets it when pressing button using setRemoteDescription 
              4. listens to volunteer candidate and sets it using add candidate
              
              ### Therefore blind client: ###

               Ready and good to go 

               */
          },
          child: Text('Offer & join call'),
          style: ElevatedButton.styleFrom(primary: Colors.green),
        ),
      ]);

  // Row sdpCandidateButtons() =>
  //     Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
  //       // ElevatedButton(
  //       //   onPressed: _setRemoteDescription,
  //       //   child: Text('Set Remote Desc'),
  //       //   style: ElevatedButton.styleFrom(primary: Colors.deepOrange),
  //       // ),
  //       ElevatedButton(
  //         onPressed: _addCandidate,
  //         child: Text('Add Candidate'),
  //         style: ElevatedButton.styleFrom(primary: Colors.blueGrey),
  //       )
  //     ]);

  // Padding sdpCandidatesTF() => Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: TextField(
  //         controller: sdpController,
  //         keyboardType: TextInputType.multiline,
  //         maxLines: 4,
  //         maxLength: TextField.noMaxLength,
  //       ),
  //     );

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
            // sdpCandidatesTF(),
            // sdpCandidateButtons(),
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
