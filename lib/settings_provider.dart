import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;

  void setNotifications(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }
}
