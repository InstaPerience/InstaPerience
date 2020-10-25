import 'package:InstaPerience/domain/image_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'main.dart';
import 'dart:io';
import 'location.dart';
import 'package:geocoder/geocoder.dart';
import 'package:path/path.dart';
import 'package:photofilters/photofilters.dart';
import 'package:image/image.dart' as imageLib;

class Uploader extends StatefulWidget {
  final ImageRepository imageRepository;

  const Uploader({Key key, this.imageRepository}) : super(key: key);
  _Uploader createState() => _Uploader(imageRepository);
}

class _Uploader extends State<Uploader> {
  DomainImage file;
 final ImageRepository imageRepository;

  String fileName;
  List<Filter> filters = presetFiltersList;
  //Strings required to save address
  Address address;

  Map<String, double> currentLocation = Map();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  bool uploading = false;
  bool editing = false;
  _Uploader(this.imageRepository);

  @override
  initState() {
    //variables with location assigned as 0.0
    currentLocation['latitude'] = 0.0;
    currentLocation['longitude'] = 0.0;
    initPlatformState(); //method to call location
    super.initState();
  }

  //method to get Location and save into variables
  initPlatformState() async {
    Address first = await getUserLocation();
    setState(() {
      address = first;
    });
  }

  Future getImage(context) async {

    var image = await file.getContent()
            .then((bytes) => imageLib.decodeImage(bytes))
            .then((image) => imageLib.copyResize(image, width : 600));

    Map imagefile = await Navigator.push(
      context,
      new MaterialPageRoute(
        builder: (context) => new PhotoFilterSelector(
          title: Text("Edit"),
          image: image,
          filename: '',
          filters: presetFiltersList,
          loader: Center(child: CircularProgressIndicator()),
          fit: BoxFit.contain,
        ),
      ),
    );
    if (imagefile != null && imagefile.containsKey('image_filtered')) {
      setState(() {
        file = imagefile['image_filtered'];
      });
    }
  }

  Widget build(BuildContext context) {
    return file == null
        ? IconButton(
            icon: Icon(Icons.file_upload, size: 100),
            focusColor: Colors.amberAccent,
            onPressed: () => {_selectImage(context)})
        : editing == false
        ? Scaffold(
          resizeToAvoidBottomPadding: false,
          appBar: AppBar(
            backgroundColor: Colors.white70,
            leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black),
                onPressed: clearImage),
            title: const Text(
              'Post to...',
              style: const TextStyle(color: Colors.black),
            ),
            actions: <Widget>[
              FlatButton(
                  onPressed: () => editImage(context),
                  child: Text(
                    "Edit",
                    style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0),
                  )),
              FlatButton(
                  onPressed: postImage,
                  child: Text(
                    "Post",
                    style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0),
                  ))
            ],
          ),
          body: ListView(
            children: <Widget>[
              PostForm(
                imageFile: file,
                descriptionController: descriptionController,
                locationController: locationController,
                loading: uploading,
              ),
              Divider(), //scroll view where we will show location to users
              (address == null)
                  ? Container()
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(right: 5.0, left: 5.0),
                child: Row(
                  children: <Widget>[
                    buildLocationButton(address.featureName),
                    buildLocationButton(address.subLocality),
                    buildLocationButton(address.locality),
                    buildLocationButton(address.subAdminArea),
                    buildLocationButton(address.adminArea),
                    buildLocationButton(address.countryName),
                  ],
                ),
              ),
              (address == null) ? Container() : Divider(),
            ],
          ))
        : Scaffold(
      // edit image scaffold
        resizeToAvoidBottomPadding: false,
        appBar: AppBar(
          backgroundColor: Colors.white70,
          leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: clearImage),
          title: const Text(
            'Edit',
            style: const TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            FlatButton(
                onPressed: finishEditImage,
                child: Text(
                  "Next",
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0),
                )),
          ],
        ),
        body: Center(
          child: new Container(
            child: file == null ? Center(child: new Text('No image selected.'),) : file.toRenderableWidget(),
          ),
        ),
        floatingActionButton: new FloatingActionButton(
          onPressed: () => getImage(context),
          tooltip: 'Pick Image',
          child: new Icon(Icons.add_a_photo),
        ),
      );
    }

  //method to build buttons with location.
  buildLocationButton(String locationName) {
    if (locationName != null ?? locationName.isNotEmpty) {
      return InkWell(
        onTap: () {
          locationController.text = locationName;
        },
        child: Center(
          child: Container(
            //width: 100.0,
            height: 30.0,
            padding: EdgeInsets.only(left: 8.0, right: 8.0),
            margin: EdgeInsets.only(right: 3.0, left: 3.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Center(
              child: Text(
                locationName,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  Future<DomainImage> _fetchDomainImage(ImageSource imageSource) {
      var imagePicker = ImagePicker();
      return imagePicker.getImage(source : imageSource, maxWidth: 1920, maxHeight: 1200, imageQuality: 80)
              .then((pickedFile) => File(pickedFile.path))
              .then((file) => FileDomainImage(file));
  }

  _selectImage(BuildContext parentContext) async {

    return showDialog<Null>(
      context: parentContext,
      barrierDismissible: false, // user must tap button!

      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Create a Post'),
          children: <Widget>[
            SimpleDialogOption(
                child: const Text('Take a photo'),
                onPressed: () async {
                  Navigator.pop(context);
                  _fetchDomainImage(ImageSource.camera).then((image) => setImage(image));
                }),
            SimpleDialogOption(
                child: const Text('Choose from Gallery'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  _fetchDomainImage(ImageSource.gallery).then((image) => setImage(image));
                }),
            SimpleDialogOption(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          ],
        );
      },
    );
  }

  void clearImage() {
    setState(() {
      file = null;
    });
  }

  void editImage(context) {
    setState(() {
      editing = true;
    });
    getImage(context);
  }

  void finishEditImage() {
    setState(() {
      editing = false;
    });
  }

  void setImage(DomainImage domainImage) {
      setState(() {
          file = domainImage;
      });
  }

  Future<void> multiUpload(DomainImage imageFile) async {

      var futureIpfsHash = imageRepository.saveImage(imageFile).then((image) => image.imageId);
      var futureFirebaseUrl = fireBaseImageUpload(imageFile);

      var ipfsHash = await futureIpfsHash;
      var firebaseUrl = await futureFirebaseUrl;

      await postToFireStore(mediaUrl: firebaseUrl,
                            ipfsHash: ipfsHash,
                            description: descriptionController.text,
                            location: locationController.text);
      setState(() {
          file = null;
          uploading = false;
          pageController.jumpToPage(4);
      });
  }

  Future<String> fireBaseImageUpload(DomainImage domainImage) async {
      var uuid = Uuid().v1();
      StorageReference ref = FirebaseStorage.instance.ref().child("post_$uuid.jpg");
      var futureContent = domainImage.getContent();
      var content =  await domainImage.getContent();

      var uploadTask =  ref.putData(content);
      var completion = await uploadTask.onComplete;
      return await completion.ref.getDownloadURL();
//      Future<String> url = await domainImage.getContent()
//              .then((bytes) => ref.putData(bytes))
//              .then((task) async => await task.onComplete)
//              .then((var snapshot) async => await snapshot.ref.getDownloadURL());

//      return url;
  }

  void postImage() {
    setState(() {
      uploading = true;
    });

    multiUpload(file);
  }
}

class PostForm extends StatelessWidget {
  final DomainImage imageFile;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final bool loading;
  PostForm(
      {this.imageFile,
      this.descriptionController,
      this.loading,
      this.locationController});

  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        loading
            ? LinearProgressIndicator()
            : Padding(padding: EdgeInsets.only(top: 0.0)),
        Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            CircleAvatar(
              backgroundImage: NetworkImage(currentUserModel.photoUrl),
            ),
            Container(
              width: 250.0,
              child: TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                    hintText: "Write a caption...", border: InputBorder.none),
              ),
            ),
            Container(
              height: 45.0,
              width: 45.0,
              child: AspectRatio(
                aspectRatio: 487 / 451,
                child: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                    fit: BoxFit.fill,
                    alignment: FractionalOffset.topCenter,
                    image: imageFile.toImageProvider()
                  )),
                ),
              ),
            ),
          ],
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.pin_drop),
          title: Container(
            width: 250.0,
            child: TextField(
              controller: locationController,
              decoration: InputDecoration(
                  hintText: "Where was this photo taken?",
                  border: InputBorder.none),
            ),
          ),
        )
      ],
    );
  }
}
Future<void> postToFireStore({String mediaUrl, String ipfsHash,  String location, String description}) async {
  var reference = Firestore.instance.collection('insta_posts');

  return reference.add({
    "username": currentUserModel.username,
    "location": location,
    "likes": {},
    "mediaUrl": mediaUrl,
    "mediaIPFSHash" : ipfsHash,
    "description": description,
    "ownerId": googleSignIn.currentUser.id,
    "timestamp": DateTime.now(),
  }).then((DocumentReference doc) {
    String docId = doc.documentID;
    reference.document(docId).updateData({"postId": docId});
  });
}
