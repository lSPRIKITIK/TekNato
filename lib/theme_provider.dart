import 'package:flutter_riverpod/flutter_riverpod.dart';

// A simple state provider that holds a boolean for dark mode
final darkModeProvider = StateProvider<bool>((ref) => false);
