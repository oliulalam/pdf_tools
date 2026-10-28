import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf_toolkit/app.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Fast app startup! We initialize Ads AFTER runApp to keep launch time minimal.
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const PdfToolKitApp(),
    ),
  );

  // Initialize Ads and Consent in background to prevent UI blocking
  AdHelper.initializeMobileAdsAndConsent();
}
