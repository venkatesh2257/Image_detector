import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'పాల Predictor'**
  String get appTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageTelugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get languageTelugu;

  /// No description provided for @headerSubtitleReady.
  ///
  /// In en, this message translates to:
  /// **'AI dairy analytics · rear udder capture'**
  String get headerSubtitleReady;

  /// No description provided for @headerSubtitleBooting.
  ///
  /// In en, this message translates to:
  /// **'Booting prediction engine…'**
  String get headerSubtitleBooting;

  /// No description provided for @statusAiOnline.
  ///
  /// In en, this message translates to:
  /// **'AI ONLINE'**
  String get statusAiOnline;

  /// No description provided for @statusBooting.
  ///
  /// In en, this message translates to:
  /// **'BOOTING'**
  String get statusBooting;

  /// No description provided for @flowCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get flowCapture;

  /// No description provided for @flowReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get flowReview;

  /// No description provided for @flowResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get flowResults;

  /// No description provided for @captureHintReady.
  ///
  /// In en, this message translates to:
  /// **'AI ready · Camera / Gallery'**
  String get captureHintReady;

  /// No description provided for @captureHintLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading AI…'**
  String get captureHintLoading;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @uploadedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploaded photo'**
  String get uploadedPhoto;

  /// No description provided for @reviewInstructions.
  ///
  /// In en, this message translates to:
  /// **'Confirm animal health, then proceed to AI analysis.'**
  String get reviewInstructions;

  /// No description provided for @animalHealth.
  ///
  /// In en, this message translates to:
  /// **'Animal health'**
  String get animalHealth;

  /// No description provided for @healthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// No description provided for @healthySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Normal condition, fit for milking assessment'**
  String get healthySubtitle;

  /// No description provided for @notHealthy.
  ///
  /// In en, this message translates to:
  /// **'Not healthy'**
  String get notHealthy;

  /// No description provided for @notHealthySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible illness, injury, or poor condition'**
  String get notHealthySubtitle;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @proceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get proceed;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get analyzing;

  /// No description provided for @editHealthRetry.
  ///
  /// In en, this message translates to:
  /// **'Edit health & retry'**
  String get editHealthRetry;

  /// No description provided for @newPhoto.
  ///
  /// In en, this message translates to:
  /// **'New photo'**
  String get newPhoto;

  /// No description provided for @emptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Capture or upload an image to start recognition'**
  String get emptyStateHint;

  /// No description provided for @errorCameraWindows.
  ///
  /// In en, this message translates to:
  /// **'Camera is not supported on Windows desktop. Please use \"Gallery\" to upload a buffalo photo.'**
  String get errorCameraWindows;

  /// No description provided for @errorPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to open {source}. Please check app permissions.'**
  String errorPickImage(String source);

  /// No description provided for @savedCapture.
  ///
  /// In en, this message translates to:
  /// **'Saved capture {id} (Firestore)'**
  String savedCapture(String id);

  /// No description provided for @firestoreSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Firestore save failed: {error}'**
  String firestoreSaveFailed(String error);

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed. Please try another photo.'**
  String get analysisFailed;

  /// No description provided for @engineMilkMirror.
  ///
  /// In en, this message translates to:
  /// **'Escutcheon geometry (A–B, C–D)'**
  String get engineMilkMirror;

  /// No description provided for @engineMilkMirrorTflite.
  ///
  /// In en, this message translates to:
  /// **'పాల Predictor + AI'**
  String get engineMilkMirrorTflite;

  /// No description provided for @engineTflite.
  ///
  /// In en, this message translates to:
  /// **'TFLite AI'**
  String get engineTflite;

  /// No description provided for @engineTfliteUntrained.
  ///
  /// In en, this message translates to:
  /// **'TFLite (needs training)'**
  String get engineTfliteUntrained;

  /// No description provided for @engineRulesGate.
  ///
  /// In en, this message translates to:
  /// **'Rules gate only'**
  String get engineRulesGate;

  /// No description provided for @overlayAiAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis in progress'**
  String get overlayAiAnalysisTitle;

  /// No description provided for @overlayAiAnalysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Computer vision · Measurement · Prediction engine'**
  String get overlayAiAnalysisSubtitle;

  /// No description provided for @overlayStepCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get overlayStepCapture;

  /// No description provided for @overlayStepCaptureSub.
  ///
  /// In en, this message translates to:
  /// **'Image loaded'**
  String get overlayStepCaptureSub;

  /// No description provided for @overlayStepDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get overlayStepDetect;

  /// No description provided for @overlayStepDetectSub.
  ///
  /// In en, this message translates to:
  /// **'Animal scan'**
  String get overlayStepDetectSub;

  /// No description provided for @overlayStepMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get overlayStepMeasure;

  /// No description provided for @overlayStepMeasureSub.
  ///
  /// In en, this message translates to:
  /// **'Escutcheon'**
  String get overlayStepMeasureSub;

  /// No description provided for @overlayStepPredict.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get overlayStepPredict;

  /// No description provided for @overlayStepPredictSub.
  ///
  /// In en, this message translates to:
  /// **'TFLite'**
  String get overlayStepPredictSub;

  /// No description provided for @showcaseBootingAi.
  ///
  /// In en, this message translates to:
  /// **'BOOTING AI'**
  String get showcaseBootingAi;

  /// No description provided for @showcaseMilkMirror.
  ///
  /// In en, this message translates to:
  /// **'పాల PREDICTOR'**
  String get showcaseMilkMirror;

  /// No description provided for @showcaseBuffaloRearTitle.
  ///
  /// In en, this message translates to:
  /// **'Buffalo rear'**
  String get showcaseBuffaloRearTitle;

  /// No description provided for @showcaseBuffaloRearSub.
  ///
  /// In en, this message translates to:
  /// **'Rear escutcheon'**
  String get showcaseBuffaloRearSub;

  /// No description provided for @showcaseCowRearTitle.
  ///
  /// In en, this message translates to:
  /// **'Cow rear'**
  String get showcaseCowRearTitle;

  /// No description provided for @showcaseCowRearSub.
  ///
  /// In en, this message translates to:
  /// **'Herd comparison'**
  String get showcaseCowRearSub;

  /// No description provided for @showcaseMilkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Milking'**
  String get showcaseMilkingTitle;

  /// No description provided for @showcaseMilkingSub.
  ///
  /// In en, this message translates to:
  /// **'Yield context'**
  String get showcaseMilkingSub;

  /// No description provided for @showcaseAiScanTitle.
  ///
  /// In en, this message translates to:
  /// **'AI scanning'**
  String get showcaseAiScanTitle;

  /// No description provided for @showcaseAiScanSub.
  ///
  /// In en, this message translates to:
  /// **'Neural analysis'**
  String get showcaseAiScanSub;

  /// No description provided for @showcaseHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get showcaseHealthTitle;

  /// No description provided for @showcaseHealthSub.
  ///
  /// In en, this message translates to:
  /// **'Condition check'**
  String get showcaseHealthSub;

  /// No description provided for @showcaseLactationTitle.
  ///
  /// In en, this message translates to:
  /// **'Lactation'**
  String get showcaseLactationTitle;

  /// No description provided for @showcaseLactationSub.
  ///
  /// In en, this message translates to:
  /// **'Stage & DIM'**
  String get showcaseLactationSub;

  /// No description provided for @showcaseMilkYieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Milk yield'**
  String get showcaseMilkYieldTitle;

  /// No description provided for @showcaseMilkYieldSub.
  ///
  /// In en, this message translates to:
  /// **'Liters per day'**
  String get showcaseMilkYieldSub;

  /// No description provided for @alertAnalysisSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Analysis successful'**
  String get alertAnalysisSuccessful;

  /// No description provided for @alertReviewRecommended.
  ///
  /// In en, this message translates to:
  /// **'Review recommended'**
  String get alertReviewRecommended;

  /// No description provided for @alertPredictionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Prediction blocked'**
  String get alertPredictionBlocked;

  /// No description provided for @alertAiInsight.
  ///
  /// In en, this message translates to:
  /// **'AI insight'**
  String get alertAiInsight;

  /// No description provided for @dailyMilkProduction.
  ///
  /// In en, this message translates to:
  /// **'DAILY MILK PRODUCTION'**
  String get dailyMilkProduction;

  /// No description provided for @yieldRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range {min}–{max} L · {band}'**
  String yieldRangeLabel(String min, String max, String band);

  /// No description provided for @metricSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get metricSpecies;

  /// No description provided for @metricLactation.
  ///
  /// In en, this message translates to:
  /// **'Lactation'**
  String get metricLactation;

  /// No description provided for @metricHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get metricHealth;

  /// No description provided for @aiPipeline.
  ///
  /// In en, this message translates to:
  /// **'AI Pipeline'**
  String get aiPipeline;

  /// No description provided for @detectionPanel.
  ///
  /// In en, this message translates to:
  /// **'Detection panel'**
  String get detectionPanel;

  /// No description provided for @detectSexClassification.
  ///
  /// In en, this message translates to:
  /// **'Sex classification'**
  String get detectSexClassification;

  /// No description provided for @detectLactationStage.
  ///
  /// In en, this message translates to:
  /// **'Lactation stage'**
  String get detectLactationStage;

  /// No description provided for @detectSpeciesConfidence.
  ///
  /// In en, this message translates to:
  /// **'Species confidence'**
  String get detectSpeciesConfidence;

  /// No description provided for @dimBadge.
  ///
  /// In en, this message translates to:
  /// **'DIM'**
  String get dimBadge;

  /// No description provided for @productionEstimate.
  ///
  /// In en, this message translates to:
  /// **'Production estimate'**
  String get productionEstimate;

  /// No description provided for @litersPerDay.
  ///
  /// In en, this message translates to:
  /// **'L / day'**
  String get litersPerDay;

  /// No description provided for @confidencePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% confidence'**
  String confidencePercent(int percent);

  /// No description provided for @productionEstimateFootnote.
  ///
  /// In en, this message translates to:
  /// **'Identified from escutcheon measurement and on-device AI ({min}–{max} L scale).'**
  String productionEstimateFootnote(String min, String max);

  /// No description provided for @sessionId.
  ///
  /// In en, this message translates to:
  /// **'Session {id}'**
  String sessionId(String id);

  /// No description provided for @escutcheonVision.
  ///
  /// In en, this message translates to:
  /// **'Escutcheon vision'**
  String get escutcheonVision;

  /// No description provided for @metricAbHeight.
  ///
  /// In en, this message translates to:
  /// **'A–B height'**
  String get metricAbHeight;

  /// No description provided for @metricCdWidth.
  ///
  /// In en, this message translates to:
  /// **'C–D width'**
  String get metricCdWidth;

  /// No description provided for @metricArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get metricArea;

  /// No description provided for @metricSymmetry.
  ///
  /// In en, this message translates to:
  /// **'Symmetry %'**
  String get metricSymmetry;

  /// No description provided for @milkMirrorAnalysis.
  ///
  /// In en, this message translates to:
  /// **'పాల Predictor Analysis'**
  String get milkMirrorAnalysis;

  /// No description provided for @measured.
  ///
  /// In en, this message translates to:
  /// **'MEASURED'**
  String get measured;

  /// No description provided for @centerEstimate.
  ///
  /// In en, this message translates to:
  /// **'Center estimate: {liters} L/day'**
  String centerEstimate(String liters);

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percent}%'**
  String confidenceLabel(String percent);

  /// No description provided for @escutcheonMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Escutcheon measurements'**
  String get escutcheonMeasurements;

  /// No description provided for @heightAb.
  ///
  /// In en, this message translates to:
  /// **'Height (A → B)'**
  String get heightAb;

  /// No description provided for @widthCd.
  ///
  /// In en, this message translates to:
  /// **'Width (C → D)'**
  String get widthCd;

  /// No description provided for @areaHw.
  ///
  /// In en, this message translates to:
  /// **'Area (H × W)'**
  String get areaHw;

  /// No description provided for @symmetryIndex.
  ///
  /// In en, this message translates to:
  /// **'Symmetry index'**
  String get symmetryIndex;

  /// No description provided for @percentOfFrame.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of frame'**
  String percentOfFrame(String percent);

  /// No description provided for @percentBalanced.
  ///
  /// In en, this message translates to:
  /// **'{percent}% balanced'**
  String percentBalanced(String percent);

  /// No description provided for @keyFeaturesExtracted.
  ///
  /// In en, this message translates to:
  /// **'Key features extracted'**
  String get keyFeaturesExtracted;

  /// No description provided for @featureArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get featureArea;

  /// No description provided for @featureSymmetry.
  ///
  /// In en, this message translates to:
  /// **'Symmetry'**
  String get featureSymmetry;

  /// No description provided for @featureFullness.
  ///
  /// In en, this message translates to:
  /// **'Fullness'**
  String get featureFullness;

  /// No description provided for @featureTexture.
  ///
  /// In en, this message translates to:
  /// **'Texture'**
  String get featureTexture;

  /// No description provided for @aiCrossCheck.
  ///
  /// In en, this message translates to:
  /// **'AI cross-check: {liters} L/day ({match}% match)'**
  String aiCrossCheck(String liters, String match);

  /// No description provided for @dailyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Daily revenue'**
  String get dailyRevenue;

  /// No description provided for @monthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly revenue'**
  String get monthlyRevenue;

  /// No description provided for @milkMirrorFootnote.
  ///
  /// In en, this message translates to:
  /// **'* Escutcheon landmarks (C/D) and udder (B) on photo — see overlay in debug. Production scale 1–30 L/day from escutcheon + on-device AI.'**
  String get milkMirrorFootnote;

  /// No description provided for @proofRulesGate.
  ///
  /// In en, this message translates to:
  /// **'Rules gate'**
  String get proofRulesGate;

  /// No description provided for @proofPinBones.
  ///
  /// In en, this message translates to:
  /// **'Rear landmarks detected'**
  String get proofPinBones;

  /// No description provided for @proofEscutcheon.
  ///
  /// In en, this message translates to:
  /// **'Escutcheon measured'**
  String get proofEscutcheon;

  /// No description provided for @proofTfliteRan.
  ///
  /// In en, this message translates to:
  /// **'TFLite ran'**
  String get proofTfliteRan;

  /// No description provided for @inferenceProof.
  ///
  /// In en, this message translates to:
  /// **'Inference proof'**
  String get inferenceProof;

  /// No description provided for @inferenceProofConsole.
  ///
  /// In en, this message translates to:
  /// **'Inference proof (see Debug Console)'**
  String get inferenceProofConsole;

  /// No description provided for @proofSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get proofSession;

  /// No description provided for @proofPredictedBy.
  ///
  /// In en, this message translates to:
  /// **'Predicted by'**
  String get proofPredictedBy;

  /// No description provided for @proofTfliteLoaded.
  ///
  /// In en, this message translates to:
  /// **'TFLite loaded'**
  String get proofTfliteLoaded;

  /// No description provided for @proofInterpreter.
  ///
  /// In en, this message translates to:
  /// **'Interpreter'**
  String get proofInterpreter;

  /// No description provided for @proofInterpreterRun.
  ///
  /// In en, this message translates to:
  /// **'interpreter.run()'**
  String get proofInterpreterRun;

  /// No description provided for @proofPass.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get proofPass;

  /// No description provided for @proofFail.
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get proofFail;

  /// No description provided for @proofMilkMirrorUi.
  ///
  /// In en, this message translates to:
  /// **'పాల Predictor (UI):'**
  String get proofMilkMirrorUi;

  /// No description provided for @proofHeightAb.
  ///
  /// In en, this message translates to:
  /// **'Height A→B'**
  String get proofHeightAb;

  /// No description provided for @proofWidthCd.
  ///
  /// In en, this message translates to:
  /// **'Width C→D'**
  String get proofWidthCd;

  /// No description provided for @proofLitersMeasured.
  ///
  /// In en, this message translates to:
  /// **'Liters (measured)'**
  String get proofLitersMeasured;

  /// No description provided for @proofTfliteClass.
  ///
  /// In en, this message translates to:
  /// **'TFLite class'**
  String get proofTfliteClass;

  /// No description provided for @proofAllClassScores.
  ///
  /// In en, this message translates to:
  /// **'All class scores:'**
  String get proofAllClassScores;

  /// No description provided for @badgeMilkMirrorMeasurement.
  ///
  /// In en, this message translates to:
  /// **'పాల PREDICTOR MEASUREMENT'**
  String get badgeMilkMirrorMeasurement;

  /// No description provided for @badgeAiModelTflite.
  ///
  /// In en, this message translates to:
  /// **'AI MODEL (TFLite)'**
  String get badgeAiModelTflite;

  /// No description provided for @estimatedYield.
  ///
  /// In en, this message translates to:
  /// **'Estimated yield'**
  String get estimatedYield;

  /// No description provided for @dailyRevenueRow.
  ///
  /// In en, this message translates to:
  /// **'Daily Revenue'**
  String get dailyRevenueRow;

  /// No description provided for @monthlyRevenueRow.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get monthlyRevenueRow;

  /// No description provided for @engineLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine: {engine}'**
  String engineLabel(String engine);

  /// No description provided for @litersPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{liters}L / Mo'**
  String litersPerMonth(String liters);

  /// No description provided for @tfliteUntrainedWarning.
  ///
  /// In en, this message translates to:
  /// **'This TFLite file is not trained on your buffalo photos yet. The app always picks a class label, but 0% scores mean the model cannot distinguish 6–10 L bands. Train with training/train_model.py using images like your 10 L/day buffalo.'**
  String get tfliteUntrainedWarning;

  /// No description provided for @couldNotIdentifyBuffalo.
  ///
  /// In en, this message translates to:
  /// **'* Could not identify buffalo from this photo'**
  String get couldNotIdentifyBuffalo;

  /// No description provided for @localBuffaloDebug.
  ///
  /// In en, this message translates to:
  /// **'* Local buffalo — hybrid model with debug inputs above'**
  String get localBuffaloDebug;

  /// No description provided for @localBuffaloPhoto.
  ///
  /// In en, this message translates to:
  /// **'* Local buffalo — estimate from photo only'**
  String get localBuffaloPhoto;

  /// No description provided for @badgeImageBasedModel.
  ///
  /// In en, this message translates to:
  /// **'IMAGE-BASED MODEL'**
  String get badgeImageBasedModel;

  /// No description provided for @visualAnalysisComplete.
  ///
  /// In en, this message translates to:
  /// **'Visual Analysis Complete'**
  String get visualAnalysisComplete;

  /// No description provided for @basedOnImageFeatures.
  ///
  /// In en, this message translates to:
  /// **'Based on image features'**
  String get basedOnImageFeatures;

  /// No description provided for @visualPrediction.
  ///
  /// In en, this message translates to:
  /// **'Visual Prediction'**
  String get visualPrediction;

  /// No description provided for @visualScore.
  ///
  /// In en, this message translates to:
  /// **'Visual Score'**
  String get visualScore;

  /// No description provided for @udderSize.
  ///
  /// In en, this message translates to:
  /// **'Udder size'**
  String get udderSize;

  /// No description provided for @bodyCondition.
  ///
  /// In en, this message translates to:
  /// **'Body condition'**
  String get bodyCondition;

  /// No description provided for @frameSize.
  ///
  /// In en, this message translates to:
  /// **'Frame size'**
  String get frameSize;

  /// No description provided for @buildScoreDebug.
  ///
  /// In en, this message translates to:
  /// **'Build score (debug)'**
  String get buildScoreDebug;

  /// No description provided for @imageBasedFootnote.
  ///
  /// In en, this message translates to:
  /// **'* Based on Visual AI Model (Image Analysis)'**
  String get imageBasedFootnote;

  /// No description provided for @debugHybridInputs.
  ///
  /// In en, this message translates to:
  /// **'DEBUG — hybrid model inputs'**
  String get debugHybridInputs;

  /// No description provided for @localBuffaloOnly.
  ///
  /// In en, this message translates to:
  /// **'Local buffalo only ({type}). Hidden in production.'**
  String localBuffaloOnly(String type);

  /// No description provided for @feedQuality.
  ///
  /// In en, this message translates to:
  /// **'Feed quality'**
  String get feedQuality;

  /// No description provided for @feedHighProtein.
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get feedHighProtein;

  /// No description provided for @feedStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get feedStandard;

  /// No description provided for @feedLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get feedLow;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'Age (yrs)'**
  String get ageYears;

  /// No description provided for @lactationNumber.
  ///
  /// In en, this message translates to:
  /// **'Lactation #'**
  String get lactationNumber;

  /// No description provided for @daysInMilk.
  ///
  /// In en, this message translates to:
  /// **'Days in milk'**
  String get daysInMilk;

  /// No description provided for @labelNoBuffaloDetected.
  ///
  /// In en, this message translates to:
  /// **'No Buffalo Detected'**
  String get labelNoBuffaloDetected;

  /// No description provided for @labelAiModelNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'AI Model Not Loaded'**
  String get labelAiModelNotLoaded;

  /// No description provided for @labelDetectionError.
  ///
  /// In en, this message translates to:
  /// **'Detection Error'**
  String get labelDetectionError;

  /// No description provided for @labelPhotoNotSuitable.
  ///
  /// In en, this message translates to:
  /// **'Photo Not Suitable'**
  String get labelPhotoNotSuitable;

  /// No description provided for @speciesBuffalo.
  ///
  /// In en, this message translates to:
  /// **'Buffalo'**
  String get speciesBuffalo;

  /// No description provided for @speciesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get speciesUnknown;

  /// No description provided for @speciesUncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get speciesUncertain;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @lactationLactating.
  ///
  /// In en, this message translates to:
  /// **'Lactating'**
  String get lactationLactating;

  /// No description provided for @lactationDry.
  ///
  /// In en, this message translates to:
  /// **'Dry / not visible'**
  String get lactationDry;

  /// No description provided for @healthNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get healthNormal;

  /// No description provided for @healthCheckAsymmetry.
  ///
  /// In en, this message translates to:
  /// **'Check asymmetry'**
  String get healthCheckAsymmetry;

  /// No description provided for @healthPoorImageQuality.
  ///
  /// In en, this message translates to:
  /// **'Poor image quality'**
  String get healthPoorImageQuality;

  /// No description provided for @stageEarly.
  ///
  /// In en, this message translates to:
  /// **'Early (0–100 DIM)'**
  String get stageEarly;

  /// No description provided for @stageMid.
  ///
  /// In en, this message translates to:
  /// **'Mid (100–200 DIM)'**
  String get stageMid;

  /// No description provided for @stageLate.
  ///
  /// In en, this message translates to:
  /// **'Late (>200 DIM)'**
  String get stageLate;

  /// No description provided for @stepCaptureImage.
  ///
  /// In en, this message translates to:
  /// **'Capture image'**
  String get stepCaptureImage;

  /// No description provided for @stepRearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Rear udder photo'**
  String get stepRearPhoto;

  /// No description provided for @stepAnimalDetection.
  ///
  /// In en, this message translates to:
  /// **'Animal detection'**
  String get stepAnimalDetection;

  /// No description provided for @stepAnimalDetected.
  ///
  /// In en, this message translates to:
  /// **'Animal detected'**
  String get stepAnimalDetected;

  /// No description provided for @stepFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get stepFailed;

  /// No description provided for @stepSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get stepSpecies;

  /// No description provided for @stepSexCheck.
  ///
  /// In en, this message translates to:
  /// **'Sex check'**
  String get stepSexCheck;

  /// No description provided for @stepLactation.
  ///
  /// In en, this message translates to:
  /// **'Lactation'**
  String get stepLactation;

  /// No description provided for @stepHealthScreen.
  ///
  /// In en, this message translates to:
  /// **'Health screen'**
  String get stepHealthScreen;

  /// No description provided for @stepYieldPredict.
  ///
  /// In en, this message translates to:
  /// **'Yield predict'**
  String get stepYieldPredict;

  /// No description provided for @alertBlockedDefault.
  ///
  /// In en, this message translates to:
  /// **'Prediction blocked — fix photo or animal'**
  String get alertBlockedDefault;

  /// No description provided for @alertMaleBuffalo.
  ///
  /// In en, this message translates to:
  /// **'Male buffalo detected — milk yield prediction is for lactating females only'**
  String get alertMaleBuffalo;

  /// No description provided for @tipMaleBuffalo.
  ///
  /// In en, this message translates to:
  /// **'Use a rear photo of a lactating female with visible udder.'**
  String get tipMaleBuffalo;

  /// No description provided for @alertEscutcheonFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not measure escutcheon — use rear udder view'**
  String get alertEscutcheonFailed;

  /// No description provided for @tipEscutcheon.
  ///
  /// In en, this message translates to:
  /// **'Stand 3–5 ft behind, camera at udder height, full udder in frame.'**
  String get tipEscutcheon;

  /// No description provided for @alertCaution.
  ///
  /// In en, this message translates to:
  /// **'Prediction with caution — train TFLite or retake photo'**
  String get alertCaution;

  /// No description provided for @tipCaution.
  ///
  /// In en, this message translates to:
  /// **'Use a clear rear udder photo; add more labeled training images for accuracy.'**
  String get tipCaution;

  /// No description provided for @alertHighConfidence.
  ///
  /// In en, this message translates to:
  /// **'High-confidence పాల Predictor analysis'**
  String get alertHighConfidence;

  /// No description provided for @tipHighConfidence.
  ///
  /// In en, this message translates to:
  /// **'Maintain nutrition and monitor udder health weekly.'**
  String get tipHighConfidence;

  /// No description provided for @alertComplete.
  ///
  /// In en, this message translates to:
  /// **'Analysis complete — review measurements below'**
  String get alertComplete;

  /// No description provided for @tipComplete.
  ///
  /// In en, this message translates to:
  /// **'Log DIM and parity in farmer inputs for better stage accuracy.'**
  String get tipComplete;

  /// No description provided for @overlayLeftPin.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get overlayLeftPin;

  /// No description provided for @overlayRightPin.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get overlayRightPin;

  /// No description provided for @overlayUdder.
  ///
  /// In en, this message translates to:
  /// **'Udder'**
  String get overlayUdder;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navGalleries.
  ///
  /// In en, this message translates to:
  /// **'Galleries'**
  String get navGalleries;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @latestPrediction.
  ///
  /// In en, this message translates to:
  /// **'Latest Prediction'**
  String get latestPrediction;

  /// No description provided for @quickInsights.
  ///
  /// In en, this message translates to:
  /// **'Quick Insights'**
  String get quickInsights;

  /// No description provided for @recentAnalyses.
  ///
  /// In en, this message translates to:
  /// **'Recent Analyses'**
  String get recentAnalyses;

  /// No description provided for @insightUdderHealth.
  ///
  /// In en, this message translates to:
  /// **'Udder Health'**
  String get insightUdderHealth;

  /// No description provided for @insightSymmetry.
  ///
  /// In en, this message translates to:
  /// **'Symmetry'**
  String get insightSymmetry;

  /// No description provided for @insightBodyCondition.
  ///
  /// In en, this message translates to:
  /// **'Body Condition'**
  String get insightBodyCondition;

  /// No description provided for @insightHeatStress.
  ///
  /// In en, this message translates to:
  /// **'Heat Stress'**
  String get insightHeatStress;

  /// No description provided for @statusGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get statusGood;

  /// No description provided for @statusLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get statusLow;

  /// No description provided for @statusDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statusDash;

  /// No description provided for @estimatedDailyMilkYield.
  ///
  /// In en, this message translates to:
  /// **'Estimated Daily Milk Yield'**
  String get estimatedDailyMilkYield;

  /// No description provided for @highYieldPotential.
  ///
  /// In en, this message translates to:
  /// **'High Yield Potential'**
  String get highYieldPotential;

  /// No description provided for @healthStatus.
  ///
  /// In en, this message translates to:
  /// **'Health Status'**
  String get healthStatus;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @noPredictionsYet.
  ///
  /// In en, this message translates to:
  /// **'No predictions yet'**
  String get noPredictionsYet;

  /// No description provided for @noPredictionsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Scan to capture a rear udder photo and get your first yield estimate.'**
  String get noPredictionsHint;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @emptyRecentHint.
  ///
  /// In en, this message translates to:
  /// **'Your recent analyses will appear here after scanning.'**
  String get emptyRecentHint;

  /// No description provided for @galleriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Galleries'**
  String get galleriesTitle;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @samplePhotos.
  ///
  /// In en, this message translates to:
  /// **'Sample photos'**
  String get samplePhotos;

  /// No description provided for @samplePhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Add photos under assets/images/ in the project, then rebuild the app.'**
  String get samplePhotosHint;

  /// No description provided for @myScans.
  ///
  /// In en, this message translates to:
  /// **'My scans ({count})'**
  String myScans(int count);

  /// No description provided for @myScansEmpty.
  ///
  /// In en, this message translates to:
  /// **'Completed AI analyses appear here after you scan.'**
  String get myScansEmpty;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summary from your recent పాల Predictor analyses.'**
  String get insightsSubtitle;

  /// No description provided for @totalScans.
  ///
  /// In en, this message translates to:
  /// **'Total scans'**
  String get totalScans;

  /// No description provided for @latestYield.
  ///
  /// In en, this message translates to:
  /// **'Latest yield'**
  String get latestYield;

  /// No description provided for @latestConfidence.
  ///
  /// In en, this message translates to:
  /// **'Latest confidence'**
  String get latestConfidence;

  /// No description provided for @insightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Run a scan to unlock personalized dairy insights.'**
  String get insightsEmpty;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'AI Powered Dairy Analytics'**
  String get aboutTagline;

  /// No description provided for @aboutWhatWeDo.
  ///
  /// In en, this message translates to:
  /// **'What we do'**
  String get aboutWhatWeDo;

  /// No description provided for @aboutWhatWeDoBody.
  ///
  /// In en, this message translates to:
  /// **'Analyze rear udder photos of buffalo to estimate daily milk production using on-device AI and escutcheon geometry.'**
  String get aboutWhatWeDoBody;

  /// No description provided for @aboutBuiltFor.
  ///
  /// In en, this message translates to:
  /// **'Built for'**
  String get aboutBuiltFor;

  /// No description provided for @aboutBuiltForBody.
  ///
  /// In en, this message translates to:
  /// **'Local / Desi buffalo — rear udder capture workflow.'**
  String get aboutBuiltForBody;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} పాల Predictor'**
  String aboutCopyright(int year);

  /// No description provided for @choosePhotoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose photo source'**
  String get choosePhotoSource;

  /// No description provided for @choosePhotoSourceSub.
  ///
  /// In en, this message translates to:
  /// **'Capture a new rear photo or pick from your device'**
  String get choosePhotoSourceSub;

  /// No description provided for @cameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a new photo'**
  String get cameraSubtitle;

  /// No description provided for @gallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose from device photos'**
  String get gallerySubtitle;

  /// No description provided for @samplePhotosBundled.
  ///
  /// In en, this message translates to:
  /// **'Sample photos (bundled)'**
  String get samplePhotosBundled;

  /// No description provided for @captureGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Capture Guidelines'**
  String get captureGuidelines;

  /// No description provided for @captureGuidelinesSub.
  ///
  /// In en, this message translates to:
  /// **'Live tips while you scan'**
  String get captureGuidelinesSub;

  /// No description provided for @captureTipClearImage.
  ///
  /// In en, this message translates to:
  /// **'Clear Image = Better Prediction'**
  String get captureTipClearImage;

  /// No description provided for @captureLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get captureLive;

  /// No description provided for @captureTipNofTotal.
  ///
  /// In en, this message translates to:
  /// **'Tip {current} of {total}'**
  String captureTipNofTotal(int current, int total);

  /// No description provided for @guidelineStandBehind.
  ///
  /// In en, this message translates to:
  /// **'Stand 3–5 feet behind the buffalo'**
  String get guidelineStandBehind;

  /// No description provided for @guidelineCameraLevel.
  ///
  /// In en, this message translates to:
  /// **'Keep camera at udder level'**
  String get guidelineCameraLevel;

  /// No description provided for @guidelineFullUdder.
  ///
  /// In en, this message translates to:
  /// **'Capture full udder in frame'**
  String get guidelineFullUdder;

  /// No description provided for @guidelinePortrait.
  ///
  /// In en, this message translates to:
  /// **'Use portrait mode'**
  String get guidelinePortrait;

  /// No description provided for @guidelineLighting.
  ///
  /// In en, this message translates to:
  /// **'Ensure good lighting'**
  String get guidelineLighting;

  /// No description provided for @guidelineCleanUdder.
  ///
  /// In en, this message translates to:
  /// **'Clean udder and tail area'**
  String get guidelineCleanUdder;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @litersPerDayShort.
  ///
  /// In en, this message translates to:
  /// **'{liters} L/day'**
  String litersPerDayShort(String liters);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
