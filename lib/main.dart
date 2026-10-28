import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_toolkit/app.dart';
import 'package:pdf_toolkit/utils/ad_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final stopwatch = Stopwatch()..start();

  // 1. Initialize AdMob and UMP Consent with a safety timeout.
  // This MUST happen before we try to load any ads.
  try {
    await _initializeAds().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
          "AdMob Initialization: Timeout reached. Proceeding with init...",
        );
        MobileAds.instance.initialize();
      },
    );
  } catch (e) {
    debugPrint("AdMob Initialization: Critical error: $e");
    MobileAds.instance.initialize();
  }

  // 2. Pre-load ads now that the SDK is guaranteed to be initialized.
  await AdHelper.preLoadAds();

  // 3. Ensure the native splash/logo is visible for at least 1 second.
  final int elapsed = stopwatch.elapsedMilliseconds;
  if (elapsed < 1000) {
    await Future.delayed(Duration(milliseconds: 1000 - elapsed));
  }

  stopwatch.stop();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const PdfToolKitApp(),
    ),
  );
}

Future<void> _initializeAds() async {
  final params = ConsentRequestParameters();
  final completer = Completer<void>();

  try {
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            debugPrint("UMP Consent Error: ${error.message}");
          }
          MobileAds.instance.initialize().then((_) {
            if (!completer.isCompleted) completer.complete();
          });
        });
      },
      (FormError error) {
        debugPrint("UMP Request Error: ${error.message}");
        MobileAds.instance.initialize().then((_) {
          if (!completer.isCompleted) completer.complete();
        });
      },
    );
  } catch (e) {
    debugPrint("AdMob _initializeAds Error: $e");
    MobileAds.instance.initialize().then((_) {
      if (!completer.isCompleted) completer.complete();
    });
  }

  return completer.future;
}
