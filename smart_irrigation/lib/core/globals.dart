import 'dart:typed_data';
import 'package:flutter/material.dart';

// --- Translation Globals ---
final ValueNotifier<String> languageNotifier = ValueNotifier("English");
final ValueNotifier<int> translationTrigger = ValueNotifier(0);

// --- Profile & UI Globals ---
final ValueNotifier<Uint8List?> userProfileImageNotifier = ValueNotifier(null);
final ValueNotifier<bool> openEditProfileNotifier = ValueNotifier(false);

// --- User Session Globals ---
final ValueNotifier<String> currentUserName = ValueNotifier("Loading...");
final ValueNotifier<String> currentUserEmail = ValueNotifier("Loading...");
final ValueNotifier<String> currentUserPhone = ValueNotifier("Loading...");
final ValueNotifier<String> currentUserLocation = ValueNotifier("Loading...");