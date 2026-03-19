import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

final ValueNotifier<String> languageNotifier = ValueNotifier<String>("English");

final ValueNotifier<int> translationTrigger = ValueNotifier<int>(0);