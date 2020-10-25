import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:ipfs_client/ipfs_client.dart';

abstract class ImageRepository {
  Future<DomainImage> saveImage(DomainImage domainImage);

  Future<DomainImage> findImageById(String id);
}

class IpfsImageRepository extends ImageRepository {

  final IpfsClient _ipfsClient;

  IpfsImageRepository(this._ipfsClient);

  @override
  Future<DomainImage> findImageById(String hashId) {
      return _ipfsClient.catAsBytes(HashNode(hashId))
                        .then((var bytes) => InMemoryImage(bytes, hashId));
  }

  @override
  Future<DomainImage> saveImage(DomainImage domainImage) async {
    var hashNode =  domainImage.getContent().then((bytes) => ByteArrayStream.from(bytes)).then((stream) => _ipfsClient.addContent(stream));
    var bytes = await domainImage.getContent();

    return hashNode.then((node) {
      print("ipfs node $node");
      return node;
    }).then((hashNode) => InMemoryImage(bytes, hashNode.hash)).whenComplete(() => print("saved to ipfs"));
  }
}

abstract class DomainImage {
  final String _imageId;
  DomainImage({imageId = ''}) : _imageId = imageId;
  Widget toRenderableWidget();
  ImageProvider toImageProvider();
  Future<Uint8List> getContent();
  String get imageId => _imageId;

}

class FileDomainImage extends DomainImage {
  final File _file;
  
  FileDomainImage(this._file, {String id : ''}) : super(imageId: id);
  FileDomainImage.fromPath(String path, {String id : ''}) : _file = File(path), super(imageId:  id);
  
  @override
  Future<Uint8List> getContent() {
    return _file.readAsBytes();
  }

  @override
  Widget toRenderableWidget() {
    return Image.file(_file);
  }

  @override
  ImageProvider<Object> toImageProvider() {
    // TODO: implement toImageProvider
    return FileImage(_file);
  }
}

class InMemoryImage extends DomainImage {
  final Uint8List _contentAsBytes;
  InMemoryImage(this._contentAsBytes, String hashId) : super(imageId: hashId);
  
  @override
  Widget toRenderableWidget() {
    return Image.memory(_contentAsBytes);
  }

  @override
  Future<Uint8List> getContent() {
    return Future.value(_contentAsBytes);
  }

  @override
  ImageProvider<Object> toImageProvider() {
    return MemoryImage(_contentAsBytes);
  }
}
