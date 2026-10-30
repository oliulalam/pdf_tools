import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_toolkit/provider/file_history_provider.dart';
import 'package:pdf_toolkit/provider/pdf_compressor_provider/pdf_compressor_provider.dart';
import 'package:pdf_toolkit/provider/pdf_merger_provider/pdf_merger_provider.dart';
import 'package:pdf_toolkit/provider/pdf_page_delete_provider/pdf_page_delete_provider.dart';
import 'package:pdf_toolkit/provider/pdf_split_provider/pdf_split_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_image_provider/pdf_to_image_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_word_provider/pdf_to_word_provider.dart';
import 'package:pdf_toolkit/provider/pdf_to_excel_provider/pdf_to_excel_provider.dart';
import 'package:pdf_toolkit/provider/pdf_presenter_provider/pdf_presenter_provider.dart';
import 'package:pdf_toolkit/provider/pdf_security_provider/pdf_security_provider.dart';
import 'package:pdf_toolkit/provider/pdf_organize_provider/pdf_organize_provider.dart';
import 'package:pdf_toolkit/provider/pdf_watermark_provider/pdf_watermark_provider.dart';
import 'package:pdf_toolkit/provider/pdf_scanner_provider/pdf_scanner_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf_toolkit/provider/theme_provider.dart';
import 'package:pdf_toolkit/screen/splash_screen.dart';
import 'package:pdf_toolkit/provider/image_to_pdf_provider/images_to_pdf_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:pdf_toolkit/screen/pdf_viewer_screen/pdf_viewer_screen.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'dart:async';

class PdfToolKitApp extends StatefulWidget {
  const PdfToolKitApp({super.key});

  @override
  State<PdfToolKitApp> createState() => _PdfToolKitAppState();

  static String? pendingSharedPdfPath;

  static void checkAndOpenPendingSharedFile(BuildContext context) {
    if (pendingSharedPdfPath != null) {
      final path = pendingSharedPdfPath!;
      pendingSharedPdfPath = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              path: path,
              title: p.basename(path),
            ),
          ),
        );
      });
    }
  }
}

class _PdfToolKitAppState extends State<PdfToolKitApp> {
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    
    // Clear any FilePicker temp files on startup to free up space
    FilePicker.clearTemporaryFiles().catchError((e) {
      debugPrint("Error clearing file picker temp files: $e");
      return false; 
    });

    // For sharing images/PDFs coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _handleSharedFiles(value);
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing images/PDFs coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedFiles(value, isInitial: true);
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files, {bool isInitial = false}) {
    if (files.isEmpty) return;
    
    // Check if the file is a PDF
    for (var file in files) {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        if (isInitial) {
          // Store pending path to be handled after splash screen
          PdfToolKitApp.pendingSharedPdfPath = file.path;
        } else {
          // Find top level navigator and push viewer if app is already running
          if (mounted) {
             _navigatorKey.currentState?.push(
               MaterialPageRoute(
                 builder: (_) => PdfViewerScreen(
                   path: file.path,
                   title: p.basename(file.path),
                 ),
               ),
             );
          }
        }
        
        // Reset the intent so it doesn't trigger again on subsequent app resumes
        ReceiveSharingIntent.instance.reset();
        break; // Just open the first PDF for now
      }
    }
  }

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ImagesProvider()),
        ChangeNotifierProvider(create: (_) => PdfToImageProvider()),
        ChangeNotifierProvider(create: (_) => PdfSplitProvider()),
        ChangeNotifierProvider(create: (_) => PdfMergerProvider()),
        ChangeNotifierProvider(create: (_) => PdfPageDeleteProvider()),
        ChangeNotifierProvider(create: (_) => PdfCompressorProvider()),
        ChangeNotifierProvider(create: (_) => PdfToWordProvider()),
        ChangeNotifierProvider(create: (_) => PdfToExcelProvider()),
        ChangeNotifierProvider(create: (_) => PdfPresenterProvider()),
        ChangeNotifierProvider(create: (_) => FileHistoryProvider()),
        ChangeNotifierProvider(create: (_) => PdfSecurityProvider()),
        ChangeNotifierProvider(create: (_) => PdfOrganizeProvider()),
        ChangeNotifierProvider(create: (_) => PdfWatermarkProvider()),
        ChangeNotifierProvider(create: (_) => PdfScannerProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              fontFamily: 'Poppins',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
                primary: Colors.indigo[700],
                surface: Colors.white,
                surfaceContainerHighest: Colors.grey[200],
              ),
              scaffoldBackgroundColor: const Color(0xFFF8F9FA),
              cardColor: Colors.white,
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
              ),
              appBarTheme: AppBarTheme(
                centerTitle: false,
                backgroundColor: const Color(0xFFF8F9FA),
                foregroundColor: Colors.indigo[900],
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFFF8F9FA),
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: Color(0xFFF8F9FA),
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
                titleTextStyle: const TextStyle(
                  fontWeight:
                      FontWeight.w800, // ExtraBold for Professional feel
                  fontSize: 22,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600, // SemiBold
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo[700],
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  side: BorderSide(color: Colors.indigo[700]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              fontFamily: 'Poppins',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
                primary: Colors.indigoAccent,
                surface: const Color(0xFF1E1E26),
              ),
              scaffoldBackgroundColor: const Color(0xFF121216),
              cardColor: const Color(0xFF1E1E26),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFF1E1E26),
              ),
              appBarTheme: AppBarTheme(
                centerTitle: false,
                backgroundColor: const Color(0xFF1E1E26),
                foregroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFF1E1E26),
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                  systemNavigationBarColor: Color(0xFF121216),
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
                titleTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  side: const BorderSide(
                    color: Colors.indigoAccent,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            home: SplashScreen(),
          );
        },
      ),
    );
  }
}
