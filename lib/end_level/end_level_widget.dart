import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_spinkit/flutter_spinkit.dart';
//import 'package:google_fonts/google_fonts.dart';
//import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'end_level_model.dart';
export 'end_level_model.dart';

class EndLevelWidget extends StatefulWidget {
  const EndLevelWidget({
    super.key,
    required this.experience,
    required this.currentLevelExperience,
  });

  final String? experience;
  final double currentLevelExperience;

  @override
  State<EndLevelWidget> createState() => _EndLevelWidgetState();
}

class _EndLevelWidgetState extends State<EndLevelWidget> {
  late EndLevelModel _model;
  double _experience = 0.0;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchExperience();

    _model = createModel(context, () => EndLevelModel());

    //WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  Future<void> _fetchExperience() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String userId = currentUser.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        setState(() {
          _experience =
              userData?['experience'] ?? 0.0; // Update the experience variable
        });
      } else {
        print("User  document does not exist.");
      }
    } else {
      print("No user is currently logged in.");
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).customColor3,
          automaticallyImplyLeading: false,
          actions: const [],
          centerTitle: false,
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0, 0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/bunnies.png',
                    width: 581,
                    height: 334,
                    fit: BoxFit.cover,
                  ),
                ),
                Text(
                  'Nível finalizado!',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Readex Pro',
                        fontSize: 50,
                        letterSpacing: 0.0,
                      ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                  child: Text(
                     '${widget.currentLevelExperience} XP obtido',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Readex Pro',
                          fontSize: 30,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 30, 0, 0),
                  child: FFButtonWidget(
                    onPressed: () async {
                      context.pushNamed('HomePage');
                    },
                    text: 'Continuar',
                    options: FFButtonOptions(
                      height: 40,
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                      iconPadding:
                          const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                      color: FlutterFlowTheme.of(context).customColor3,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
                                fontFamily: 'Readex Pro',
                                color: Colors.white,
                                letterSpacing: 0.0,
                              ),
                      elevation: 0,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
