// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'పాల Predictor';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageTelugu => 'Telugu';

  @override
  String get headerSubtitleReady => 'AI dairy analytics · rear udder capture';

  @override
  String get headerSubtitleBooting => 'Booting prediction engine…';

  @override
  String get statusAiOnline => 'AI ONLINE';

  @override
  String get statusBooting => 'BOOTING';

  @override
  String get flowCapture => 'Capture';

  @override
  String get flowReview => 'Review';

  @override
  String get flowResults => 'Results';

  @override
  String get captureHintReady => 'AI ready · Camera / Gallery';

  @override
  String get captureHintLoading => 'Loading AI…';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get uploadedPhoto => 'Uploaded photo';

  @override
  String get reviewInstructions =>
      'Confirm animal health, then proceed to AI analysis.';

  @override
  String get animalHealth => 'Animal health';

  @override
  String get healthy => 'Healthy';

  @override
  String get healthySubtitle => 'Normal condition, fit for milking assessment';

  @override
  String get notHealthy => 'Not healthy';

  @override
  String get notHealthySubtitle => 'Visible illness, injury, or poor condition';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get proceed => 'Proceed';

  @override
  String get analyzing => 'Analyzing…';

  @override
  String get editHealthRetry => 'Edit health & retry';

  @override
  String get newPhoto => 'New photo';

  @override
  String get emptyStateHint =>
      'Capture or upload an image to start recognition';

  @override
  String get errorCameraWindows =>
      'Camera is not supported on Windows desktop. Please use \"Gallery\" to upload a buffalo photo.';

  @override
  String errorPickImage(String source) {
    return 'Failed to open $source. Please check app permissions.';
  }

  @override
  String savedCapture(String id) {
    return 'Saved capture $id (Firestore)';
  }

  @override
  String firestoreSaveFailed(String error) {
    return 'Firestore save failed: $error';
  }

  @override
  String get analysisFailed => 'Analysis failed. Please try another photo.';

  @override
  String get engineMilkMirror => 'Escutcheon geometry (A–B, C–D)';

  @override
  String get engineMilkMirrorTflite => 'పాల Predictor + AI';

  @override
  String get engineTflite => 'TFLite AI';

  @override
  String get engineTfliteUntrained => 'TFLite (needs training)';

  @override
  String get engineRulesGate => 'Rules gate only';

  @override
  String get overlayAiAnalysisTitle => 'AI Analysis in progress';

  @override
  String get overlayAiAnalysisSubtitle =>
      'Computer vision · Measurement · Prediction engine';

  @override
  String get overlayStepCapture => 'Capture';

  @override
  String get overlayStepCaptureSub => 'Image loaded';

  @override
  String get overlayStepDetect => 'Detect';

  @override
  String get overlayStepDetectSub => 'Animal scan';

  @override
  String get overlayStepMeasure => 'Measure';

  @override
  String get overlayStepMeasureSub => 'Escutcheon';

  @override
  String get overlayStepPredict => 'Predict';

  @override
  String get overlayStepPredictSub => 'TFLite';

  @override
  String get showcaseBootingAi => 'BOOTING AI';

  @override
  String get showcaseMilkMirror => 'పాల PREDICTOR';

  @override
  String get showcaseBuffaloRearTitle => 'Buffalo rear';

  @override
  String get showcaseBuffaloRearSub => 'Rear escutcheon';

  @override
  String get showcaseCowRearTitle => 'Cow rear';

  @override
  String get showcaseCowRearSub => 'Herd comparison';

  @override
  String get showcaseMilkingTitle => 'Milking';

  @override
  String get showcaseMilkingSub => 'Yield context';

  @override
  String get showcaseAiScanTitle => 'AI scanning';

  @override
  String get showcaseAiScanSub => 'Neural analysis';

  @override
  String get showcaseHealthTitle => 'Health';

  @override
  String get showcaseHealthSub => 'Condition check';

  @override
  String get showcaseLactationTitle => 'Lactation';

  @override
  String get showcaseLactationSub => 'Stage & DIM';

  @override
  String get showcaseMilkYieldTitle => 'Milk yield';

  @override
  String get showcaseMilkYieldSub => 'Liters per day';

  @override
  String get alertAnalysisSuccessful => 'Analysis successful';

  @override
  String get alertReviewRecommended => 'Review recommended';

  @override
  String get alertPredictionBlocked => 'Prediction blocked';

  @override
  String get alertAiInsight => 'AI insight';

  @override
  String get dailyMilkProduction => 'DAILY MILK PRODUCTION';

  @override
  String yieldRangeLabel(String min, String max, String band) {
    return 'Range $min–$max L · $band';
  }

  @override
  String get metricSpecies => 'Species';

  @override
  String get metricLactation => 'Lactation';

  @override
  String get metricHealth => 'Health';

  @override
  String get aiPipeline => 'AI Pipeline';

  @override
  String get detectionPanel => 'Detection panel';

  @override
  String get detectSexClassification => 'Sex classification';

  @override
  String get detectLactationStage => 'Lactation stage';

  @override
  String get detectSpeciesConfidence => 'Species confidence';

  @override
  String get dimBadge => 'DIM';

  @override
  String get productionEstimate => 'Production estimate';

  @override
  String get litersPerDay => 'L / day';

  @override
  String confidencePercent(int percent) {
    return '$percent% confidence';
  }

  @override
  String productionEstimateFootnote(String min, String max) {
    return 'Identified from escutcheon measurement and on-device AI ($min–$max L scale).';
  }

  @override
  String sessionId(String id) {
    return 'Session $id';
  }

  @override
  String get escutcheonVision => 'Escutcheon vision';

  @override
  String get metricAbHeight => 'A–B height';

  @override
  String get metricCdWidth => 'C–D width';

  @override
  String get metricArea => 'Area';

  @override
  String get metricSymmetry => 'Symmetry %';

  @override
  String get milkMirrorAnalysis => 'పాల Predictor Analysis';

  @override
  String get measured => 'MEASURED';

  @override
  String centerEstimate(String liters) {
    return 'Center estimate: $liters L/day';
  }

  @override
  String confidenceLabel(String percent) {
    return 'Confidence: $percent%';
  }

  @override
  String get escutcheonMeasurements => 'Escutcheon measurements';

  @override
  String get heightAb => 'Height (A → B)';

  @override
  String get widthCd => 'Width (C → D)';

  @override
  String get areaHw => 'Area (H × W)';

  @override
  String get symmetryIndex => 'Symmetry index';

  @override
  String percentOfFrame(String percent) {
    return '$percent% of frame';
  }

  @override
  String percentBalanced(String percent) {
    return '$percent% balanced';
  }

  @override
  String get keyFeaturesExtracted => 'Key features extracted';

  @override
  String get featureArea => 'Area';

  @override
  String get featureSymmetry => 'Symmetry';

  @override
  String get featureFullness => 'Fullness';

  @override
  String get featureTexture => 'Texture';

  @override
  String aiCrossCheck(String liters, String match) {
    return 'AI cross-check: $liters L/day ($match% match)';
  }

  @override
  String get dailyRevenue => 'Daily revenue';

  @override
  String get monthlyRevenue => 'Monthly revenue';

  @override
  String get milkMirrorFootnote =>
      '* Escutcheon landmarks (C/D) and udder (B) on photo — see overlay in debug. Production scale 1–30 L/day from escutcheon + on-device AI.';

  @override
  String get proofRulesGate => 'Rules gate';

  @override
  String get proofPinBones => 'Rear landmarks detected';

  @override
  String get proofEscutcheon => 'Escutcheon measured';

  @override
  String get proofTfliteRan => 'TFLite ran';

  @override
  String get inferenceProof => 'Inference proof';

  @override
  String get inferenceProofConsole => 'Inference proof (see Debug Console)';

  @override
  String get proofSession => 'Session';

  @override
  String get proofPredictedBy => 'Predicted by';

  @override
  String get proofTfliteLoaded => 'TFLite loaded';

  @override
  String get proofInterpreter => 'Interpreter';

  @override
  String get proofInterpreterRun => 'interpreter.run()';

  @override
  String get proofPass => 'PASS';

  @override
  String get proofFail => 'FAIL';

  @override
  String get proofMilkMirrorUi => 'పాల Predictor (UI):';

  @override
  String get proofHeightAb => 'Height A→B';

  @override
  String get proofWidthCd => 'Width C→D';

  @override
  String get proofLitersMeasured => 'Liters (measured)';

  @override
  String get proofTfliteClass => 'TFLite class';

  @override
  String get proofAllClassScores => 'All class scores:';

  @override
  String get badgeMilkMirrorMeasurement => 'పాల PREDICTOR MEASUREMENT';

  @override
  String get badgeAiModelTflite => 'AI MODEL (TFLite)';

  @override
  String get estimatedYield => 'Estimated yield';

  @override
  String get dailyRevenueRow => 'Daily Revenue';

  @override
  String get monthlyRevenueRow => 'Monthly Revenue';

  @override
  String engineLabel(String engine) {
    return 'Engine: $engine';
  }

  @override
  String litersPerMonth(String liters) {
    return '${liters}L / Mo';
  }

  @override
  String get tfliteUntrainedWarning =>
      'This TFLite file is not trained on your buffalo photos yet. The app always picks a class label, but 0% scores mean the model cannot distinguish 6–10 L bands. Train with training/train_model.py using images like your 10 L/day buffalo.';

  @override
  String get couldNotIdentifyBuffalo =>
      '* Could not identify buffalo from this photo';

  @override
  String get localBuffaloDebug =>
      '* Local buffalo — hybrid model with debug inputs above';

  @override
  String get localBuffaloPhoto => '* Local buffalo — estimate from photo only';

  @override
  String get badgeImageBasedModel => 'IMAGE-BASED MODEL';

  @override
  String get visualAnalysisComplete => 'Visual Analysis Complete';

  @override
  String get basedOnImageFeatures => 'Based on image features';

  @override
  String get visualPrediction => 'Visual Prediction';

  @override
  String get visualScore => 'Visual Score';

  @override
  String get udderSize => 'Udder size';

  @override
  String get bodyCondition => 'Body condition';

  @override
  String get frameSize => 'Frame size';

  @override
  String get buildScoreDebug => 'Build score (debug)';

  @override
  String get imageBasedFootnote =>
      '* Based on Visual AI Model (Image Analysis)';

  @override
  String get debugHybridInputs => 'DEBUG — hybrid model inputs';

  @override
  String localBuffaloOnly(String type) {
    return 'Local buffalo only ($type). Hidden in production.';
  }

  @override
  String get feedQuality => 'Feed quality';

  @override
  String get feedHighProtein => 'High Protein';

  @override
  String get feedStandard => 'Standard';

  @override
  String get feedLow => 'Low';

  @override
  String get ageYears => 'Age (yrs)';

  @override
  String get lactationNumber => 'Lactation #';

  @override
  String get daysInMilk => 'Days in milk';

  @override
  String get labelNoBuffaloDetected => 'No Buffalo Detected';

  @override
  String get labelAiModelNotLoaded => 'AI Model Not Loaded';

  @override
  String get labelDetectionError => 'Detection Error';

  @override
  String get labelPhotoNotSuitable => 'Photo Not Suitable';

  @override
  String get speciesBuffalo => 'Buffalo';

  @override
  String get speciesUnknown => 'Unknown';

  @override
  String get speciesUncertain => 'Uncertain';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get lactationLactating => 'Lactating';

  @override
  String get lactationDry => 'Dry / not visible';

  @override
  String get healthNormal => 'Normal';

  @override
  String get healthCheckAsymmetry => 'Check asymmetry';

  @override
  String get healthPoorImageQuality => 'Poor image quality';

  @override
  String get stageEarly => 'Early (0–100 DIM)';

  @override
  String get stageMid => 'Mid (100–200 DIM)';

  @override
  String get stageLate => 'Late (>200 DIM)';

  @override
  String get stepCaptureImage => 'Capture image';

  @override
  String get stepRearPhoto => 'Rear udder photo';

  @override
  String get stepAnimalDetection => 'Animal detection';

  @override
  String get stepAnimalDetected => 'Animal detected';

  @override
  String get stepFailed => 'Failed';

  @override
  String get stepSpecies => 'Species';

  @override
  String get stepSexCheck => 'Sex check';

  @override
  String get stepLactation => 'Lactation';

  @override
  String get stepHealthScreen => 'Health screen';

  @override
  String get stepYieldPredict => 'Yield predict';

  @override
  String get alertBlockedDefault => 'Prediction blocked — fix photo or animal';

  @override
  String get alertMaleBuffalo =>
      'Male buffalo detected — milk yield prediction is for lactating females only';

  @override
  String get tipMaleBuffalo =>
      'Use a rear photo of a lactating female with visible udder.';

  @override
  String get alertEscutcheonFailed =>
      'Could not measure escutcheon — use rear udder view';

  @override
  String get tipEscutcheon =>
      'Stand 3–5 ft behind, camera at udder height, full udder in frame.';

  @override
  String get alertCaution =>
      'Prediction with caution — train TFLite or retake photo';

  @override
  String get tipCaution =>
      'Use a clear rear udder photo; add more labeled training images for accuracy.';

  @override
  String get alertHighConfidence => 'High-confidence పాల Predictor analysis';

  @override
  String get tipHighConfidence =>
      'Maintain nutrition and monitor udder health weekly.';

  @override
  String get alertComplete => 'Analysis complete — review measurements below';

  @override
  String get tipComplete =>
      'Log DIM and parity in farmer inputs for better stage accuracy.';

  @override
  String get overlayLeftPin => 'C';

  @override
  String get overlayRightPin => 'D';

  @override
  String get overlayUdder => 'Udder';

  @override
  String get navHome => 'Home';

  @override
  String get navGalleries => 'Galleries';

  @override
  String get navScan => 'Scan';

  @override
  String get navInsights => 'Insights';

  @override
  String get navAbout => 'About';

  @override
  String get viewAll => 'View all';

  @override
  String get latestPrediction => 'Latest Prediction';

  @override
  String get quickInsights => 'Quick Insights';

  @override
  String get recentAnalyses => 'Recent Analyses';

  @override
  String get insightUdderHealth => 'Udder Health';

  @override
  String get insightSymmetry => 'Symmetry';

  @override
  String get insightBodyCondition => 'Body Condition';

  @override
  String get insightHeatStress => 'Heat Stress';

  @override
  String get statusGood => 'Good';

  @override
  String get statusLow => 'Low';

  @override
  String get statusDash => '—';

  @override
  String get estimatedDailyMilkYield => 'Estimated Daily Milk Yield';

  @override
  String get highYieldPotential => 'High Yield Potential';

  @override
  String get healthStatus => 'Health Status';

  @override
  String get confidence => 'Confidence';

  @override
  String get noPredictionsYet => 'No predictions yet';

  @override
  String get noPredictionsHint =>
      'Tap Scan to capture a rear udder photo and get your first yield estimate.';

  @override
  String get startScan => 'Start Scan';

  @override
  String get emptyRecentHint =>
      'Your recent analyses will appear here after scanning.';

  @override
  String get galleriesTitle => 'Galleries';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get samplePhotos => 'Sample photos';

  @override
  String get samplePhotosHint =>
      'Add photos under assets/images/ in the project, then rebuild the app.';

  @override
  String myScans(int count) {
    return 'My scans ($count)';
  }

  @override
  String get myScansEmpty =>
      'Completed AI analyses appear here after you scan.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsSubtitle =>
      'Summary from your recent పాల Predictor analyses.';

  @override
  String get totalScans => 'Total scans';

  @override
  String get latestYield => 'Latest yield';

  @override
  String get latestConfidence => 'Latest confidence';

  @override
  String get insightsEmpty =>
      'Run a scan to unlock personalized dairy insights.';

  @override
  String get aboutTagline => 'AI Powered Dairy Analytics';

  @override
  String get aboutWhatWeDo => 'What we do';

  @override
  String get aboutWhatWeDoBody =>
      'Analyze rear udder photos of buffalo to estimate daily milk production using on-device AI and escutcheon geometry.';

  @override
  String get aboutBuiltFor => 'Built for';

  @override
  String get aboutBuiltForBody =>
      'Local / Desi buffalo — rear udder capture workflow.';

  @override
  String get aboutVersion => 'Version';

  @override
  String aboutCopyright(int year) {
    return '© $year పాల Predictor';
  }

  @override
  String get choosePhotoSource => 'Choose photo source';

  @override
  String get choosePhotoSourceSub =>
      'Capture a new rear photo or pick from your device';

  @override
  String get cameraSubtitle => 'Take a new photo';

  @override
  String get gallerySubtitle => 'Choose from device photos';

  @override
  String get samplePhotosBundled => 'Sample photos (bundled)';

  @override
  String get captureGuidelines => 'Capture Guidelines';

  @override
  String get captureGuidelinesSub => 'Live tips while you scan';

  @override
  String get captureTipClearImage => 'Clear Image = Better Prediction';

  @override
  String get captureLive => 'LIVE';

  @override
  String captureTipNofTotal(int current, int total) {
    return 'Tip $current of $total';
  }

  @override
  String get guidelineStandBehind => 'Stand 3–5 feet behind the buffalo';

  @override
  String get guidelineCameraLevel => 'Keep camera at udder level';

  @override
  String get guidelineFullUdder => 'Capture full udder in frame';

  @override
  String get guidelinePortrait => 'Use portrait mode';

  @override
  String get guidelineLighting => 'Ensure good lighting';

  @override
  String get guidelineCleanUdder => 'Clean udder and tail area';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String litersPerDayShort(String liters) {
    return '$liters L/day';
  }
}
