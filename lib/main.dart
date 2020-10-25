import 'package:InstaPerience/domain/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ipfs_client/ipfs_client.dart';
import 'package:provider/provider.dart';
import 'feed_v2.dart';
import 'upload_page.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import 'search_page.dart';
import 'activity_feed.dart';
import 'create_account.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import 'models/user.dart';

final auth = FirebaseAuth.instance;
final googleSignIn = GoogleSignIn();
final ref = Firestore.instance.collection('insta_users');
final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

User currentUserModel;

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // after upgrading flutter this is now necessary

  // enable timestamps in firebase
  Firestore.instance.settings().then((_) {
    print('[Main] Firestore timestamps in snapshots set');
  }, onError: (_) => print('[Main] Error setting timestamps in snapshots'));
  runApp(InstaPerience());
}

Future<Null> _ensureLoggedIn(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently();
  }
  if (user == null) {
    await googleSignIn.signIn();
    await tryCreateUserRecord(context);
  }

  if (await auth.currentUser() == null) {
    final GoogleSignInAccount googleUser = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await auth.signInWithCredential(credential);
  }
}

Future<Null> _silentLogin(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;

  if (user == null) {
    user = await googleSignIn.signInSilently();
    await tryCreateUserRecord(context);
  }

  if (await auth.currentUser() == null && user != null) {
    final GoogleSignInAccount googleUser = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await auth.signInWithCredential(credential);
  }
}

Future<Null> _setUpNotifications() async {
  if (Platform.isAndroid) {
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print('on message $message');
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
      },
    );

    _firebaseMessaging.getToken().then((token) {
      print("Firebase Messaging Token: " + token);

      Firestore.instance
          .collection("insta_users")
          .document(currentUserModel.id)
          .updateData({"androidNotificationToken": token});
    });
  }
}

Future<void> tryCreateUserRecord(BuildContext context) async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    return null;
  }
  DocumentSnapshot userRecord = await ref.document(user.id).get();
  if (userRecord.data == null) {
    // no user record exists, time to create

    String userName = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Center(
                child: Scaffold(
                    appBar: AppBar(
                      leading: Container(),
                      title: Text('Fill out missing data',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.white,
                    ),
                    body: ListView(
                      children: <Widget>[
                        Container(
                          child: CreateAccount(),
                        ),
                      ],
                    )),
              )),
    );

    if (userName != null || userName.length != 0) {
      ref.document(user.id).setData({
        "id": user.id,
        "username": userName,
        "photoUrl": user.photoUrl,
        "email": user.email,
        "displayName": user.displayName,
        "bio": "",
        "followers": {},
        "following": {},
      });
    }
    userRecord = await ref.document(user.id).get();
  }

  currentUserModel = User.fromDocument(userRecord);
  return null;
}

class InstaPerience extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: IpfsClient.newClient('18.218.250.68', 5001)),
        ProxyProvider<IpfsClient, ImageRepository>(
          update: (context, ipfsClient, imageRepository) =>
              new IpfsImageRepository(ipfsClient),
        )
      ],
      child: MaterialApp(
        title: 'InstaPerience',
        theme: ThemeData(
            primarySwatch: Colors.blue,
            buttonColor: Colors.pink,
            primaryIconTheme: IconThemeData(color: Colors.black),
            textTheme: Theme.of(context)
                .textTheme
                .apply(bodyColor: Colors.white, displayColor: Colors.black)),
        home: HomePage(title: 'InstaPerience'),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

PageController pageController;

class _HomePageState extends State<HomePage> {
  int _page = 0;
  bool triedSilentLogin = false;
  bool setupNotifications = false;

  Scaffold buildLoginPage() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 240.0),
          child: Column(
            children: <Widget>[
              Text(
                'InstaPerience',
                style: TextStyle(
                    fontSize: 60.0,
                    fontFamily: "Billabong",
                    color: Colors.black),
              ),
              Padding(padding: const EdgeInsets.only(bottom: 100.0)),
              GestureDetector(
                onTap: login,
                child: Image.asset(
                  "assets/images/google_signin_button.png",
                  width: 225.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get bottomNavigationbar => CupertinoTabBar(
        backgroundColor: Colors.amberAccent,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home,
                  color: (_page == 0) ? Colors.black : Colors.black),
              title: Container(height: 0.0),
              backgroundColor: Colors.white),
          BottomNavigationBarItem(
              icon: Icon(Icons.search,
                  color: (_page == 1) ? Colors.black : Colors.black),
              title: Container(height: 0.0),
              backgroundColor: Colors.white),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle,
                  color: (_page == 2) ? Colors.black : Colors.black),
              title: Container(height: 0.0),
              backgroundColor: Colors.white),
          BottomNavigationBarItem(
              icon: Icon(Icons.star,
                  color: (_page == 3) ? Colors.black : Colors.black),
              title: Container(height: 0.0),
              backgroundColor: Colors.white),
          BottomNavigationBarItem(
              icon: Icon(Icons.person,
                  color: (_page == 4) ? Colors.black : Colors.black),
              title: Container(height: 0.0),
              backgroundColor: Colors.white),
        ],
        onTap: navigationTapped,
        currentIndex: _page,
      );

  @override
  Widget build(BuildContext context) {
    if (triedSilentLogin == false) {
      silentLogin(context);
    }

    if (setupNotifications == false && currentUserModel != null) {
      setUpNotifications();
    }

    return (googleSignIn.currentUser == null || currentUserModel == null)
        ? buildLoginPage()
        : Scaffold(
            backgroundColor: Colors.black,
            body: PageView(
              children: [
                Container(
                  color: Colors.lightBlue,
                  child: Feed(),
                ),
                Container(color: Colors.white, child: SearchPage()),
                Container(
                  color: Colors.white,
                  child: Uploader(imageRepository : Provider.of<ImageRepository>(context, listen : false)),
                ),
                Container(
                    color: Colors.white, child: ActivityFeedPage()),
                Container(
                    color: Colors.white,
                    child: ProfilePage(
                      userId: googleSignIn.currentUser.id,
                    )),
              ],
              controller: pageController,
              physics: NeverScrollableScrollPhysics(),
              onPageChanged: onPageChanged,
            ),
            bottomNavigationBar: bottomNavigationbar,
          );
  }

  void login() async {
    await _ensureLoggedIn(context);
    setState(() {
      triedSilentLogin = true;
    });
  }

  void setUpNotifications() {
    _setUpNotifications();
    setState(() {
      setupNotifications = true;
    });
  }

  void silentLogin(BuildContext context) async {
    await _silentLogin(context);
    setState(() {
      triedSilentLogin = true;
    });
  }

  void navigationTapped(int page) {
    //Animating Page
    pageController.jumpToPage(page);
  }

  void onPageChanged(int page) {
    setState(() {
      this._page = page;
    });
  }

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }
}
