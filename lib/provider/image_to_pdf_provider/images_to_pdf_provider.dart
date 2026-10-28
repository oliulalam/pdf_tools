import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum PageSizeOption { a4, letter, fitImage }

enum PageOrientationOption { portrait, landscape }

class ImagesProvider extends ChangeNotifier {
  final List<XFile> _images = [];
  String _statusMessage = '';

  PageSizeOption _pageSize = PageSizeOption.a4;
  PageOrientationOption _orientation = PageOrientationOption.portrait;

  List<XFile> get images => _images;
  bool get hasImages => _images.isNotEmpty;
  int get count => _images.length;
  String get statusMessage => _statusMessage;
  PageSizeOption get pageSize => _pageSize;
  PageOrientationOption get orientation => _orientation;

  void addImages(List<XFile> newImages) {
    _images.addAll(newImages);
    _statusMessage = '';
    notifyListeners();
  }

  void addImage(XFile image) {
    _images.add(image);
    _statusMessage = '';
    notifyListeners();
  }

  void clearImages() {
    _images.clear();
    _statusMessage = '';
    notifyListeners();
  }

  void setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void removedImage(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      notifyListeners();
    }
  }

  void moveImageUp(int index) {
    if (index > 0 && index < _images.length) {
      final img = _images.removeAt(index);
      _images.insert(index - 1, img);
      notifyListeners();
    }
  }

  void moveImageDown(int index) {
    if (index >= 0 && index < _images.length - 1) {
      final img = _images.removeAt(index);
      _images.insert(index + 1, img);
      notifyListeners();
    }
  }

  void setPageSize(PageSizeOption size) {
    _pageSize = size;
    notifyListeners();
  }

  void setOrientation(PageOrientationOption orient) {
    _orientation = orient;
    notifyListeners();
  }
}
