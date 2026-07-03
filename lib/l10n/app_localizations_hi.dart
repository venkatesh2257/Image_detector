// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'పాల Predictor';

  @override
  String get languageLabel => 'भाषा';

  @override
  String get languageEnglish => 'अंग्रेज़ी';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageTelugu => 'तेलुगु';

  @override
  String get headerSubtitleReady => 'AI डेयरी विश्लेषण · पिछले थन का फोटो';

  @override
  String get headerSubtitleBooting => 'भविष्यवाणी इंजन शुरू हो रहा है…';

  @override
  String get statusAiOnline => 'AI ऑनलाइन';

  @override
  String get statusBooting => 'शुरू हो रहा';

  @override
  String get flowCapture => 'कैप्चर';

  @override
  String get flowReview => 'समीक्षा';

  @override
  String get flowResults => 'परिणाम';

  @override
  String get captureHintReady => 'AI तैयार · कैमरा / गैलरी';

  @override
  String get captureHintLoading => 'AI लोड हो रहा…';

  @override
  String get camera => 'कैमरा';

  @override
  String get gallery => 'गैलरी';

  @override
  String get uploadedPhoto => 'अपलोड की गई फोटो';

  @override
  String get reviewInstructions =>
      'पशु स्वास्थ्य की पुष्टि करें, फिर AI विश्लेषण पर आगे बढ़ें।';

  @override
  String get animalHealth => 'पशु स्वास्थ्य';

  @override
  String get healthy => 'स्वस्थ';

  @override
  String get healthySubtitle => 'सामान्य स्थिति, दूध नाप के लिए उपयुक्त';

  @override
  String get notHealthy => 'अस्वस्थ';

  @override
  String get notHealthySubtitle => 'बीमारी, चोट या खराब स्थिति दिखाई देती है';

  @override
  String get changePhoto => 'फोटो बदलें';

  @override
  String get proceed => 'आगे बढ़ें';

  @override
  String get analyzing => 'विश्लेषण…';

  @override
  String get editHealthRetry => 'स्वास्थ्य संपादित करें और पुनः प्रयास';

  @override
  String get newPhoto => 'नई फोटो';

  @override
  String get emptyStateHint =>
      'पहचान शुरू करने के लिए फोटो कैप्चर या अपलोड करें';

  @override
  String get errorCameraWindows =>
      'Windows डेस्कटॉप पर कैमरा समर्थित नहीं है। भैंस की फोटो अपलोड करने के लिए \"गैलरी\" का उपयोग करें।';

  @override
  String errorPickImage(String source) {
    return '$source खोलने में विफल। कृपया ऐप अनुमतियाँ जाँचें।';
  }

  @override
  String savedCapture(String id) {
    return 'कैप्चर $id सहेजा गया (Firestore)';
  }

  @override
  String firestoreSaveFailed(String error) {
    return 'Firestore सहेजना विफल: $error';
  }

  @override
  String get analysisFailed => 'विश्लेषण विफल। कृपया दूसरी फोटो आज़माएँ।';

  @override
  String get engineMilkMirror => 'एस्कुचeon ज्यामिति (A–B, C–D)';

  @override
  String get engineMilkMirrorTflite => 'పాల Predictor + AI';

  @override
  String get engineTflite => 'TFLite AI';

  @override
  String get engineTfliteUntrained => 'TFLite (प्रशिक्षण आवश्यक)';

  @override
  String get engineRulesGate => 'केवल नियम गेट';

  @override
  String get overlayAiAnalysisTitle => 'AI विश्लेषण प्रगति पर';

  @override
  String get overlayAiAnalysisSubtitle =>
      'कंप्यूटर विज़न · माप · भविष्यवाणी इंजन';

  @override
  String get overlayStepCapture => 'कैप्चर';

  @override
  String get overlayStepCaptureSub => 'फोटो लोड';

  @override
  String get overlayStepDetect => 'पहचान';

  @override
  String get overlayStepDetectSub => 'पशु स्कैन';

  @override
  String get overlayStepMeasure => 'माप';

  @override
  String get overlayStepMeasureSub => 'एस्कुचeon';

  @override
  String get overlayStepPredict => 'भविष्यवाणी';

  @override
  String get overlayStepPredictSub => 'TFLite';

  @override
  String get showcaseBootingAi => 'AI शुरू';

  @override
  String get showcaseMilkMirror => 'పాల PREDICTOR';

  @override
  String get showcaseBuffaloRearTitle => 'भैंस पिछला दृश्य';

  @override
  String get showcaseBuffaloRearSub => 'पिछला एस्कुचeon';

  @override
  String get showcaseCowRearTitle => 'गाय पिछला दृश्य';

  @override
  String get showcaseCowRearSub => 'झुंड तुलना';

  @override
  String get showcaseMilkingTitle => 'दुहाई';

  @override
  String get showcaseMilkingSub => 'उपज संदर्भ';

  @override
  String get showcaseAiScanTitle => 'AI स्कैनिंग';

  @override
  String get showcaseAiScanSub => 'न्यूरल विश्लेषण';

  @override
  String get showcaseHealthTitle => 'स्वास्थ्य';

  @override
  String get showcaseHealthSub => 'स्थिति जाँच';

  @override
  String get showcaseLactationTitle => 'स्तनपान अवस्था';

  @override
  String get showcaseLactationSub => 'चरण और DIM';

  @override
  String get showcaseMilkYieldTitle => 'दूध उपज';

  @override
  String get showcaseMilkYieldSub => 'लीटर प्रति दिन';

  @override
  String get alertAnalysisSuccessful => 'विश्लेषण सफल';

  @override
  String get alertReviewRecommended => 'समीक्षा अनुशंसित';

  @override
  String get alertPredictionBlocked => 'भविष्यवाणी रोकी गई';

  @override
  String get alertAiInsight => 'AI अंतर्दृष्टि';

  @override
  String get dailyMilkProduction => 'दैनिक दूध उत्पादन';

  @override
  String yieldRangeLabel(String min, String max, String band) {
    return 'सीमा $min–$max L · $band';
  }

  @override
  String get metricSpecies => 'प्रजाति';

  @override
  String get metricLactation => 'स्तनपान';

  @override
  String get metricHealth => 'स्वास्थ्य';

  @override
  String get aiPipeline => 'AI पाइपलाइन';

  @override
  String get detectionPanel => 'पहचान पैनल';

  @override
  String get detectSexClassification => 'लिंग वर्गीकरण';

  @override
  String get detectLactationStage => 'स्तनपान चरण';

  @override
  String get detectSpeciesConfidence => 'प्रजाति विश्वास';

  @override
  String get dimBadge => 'DIM';

  @override
  String get productionEstimate => 'उत्पादन अनुमान';

  @override
  String get litersPerDay => 'L / दिन';

  @override
  String confidencePercent(int percent) {
    return '$percent% विश्वास';
  }

  @override
  String productionEstimateFootnote(String min, String max) {
    return 'एस्कुचeon माप और ऑन-डिवाइस AI से पहचान ($min–$max L स्केल)।';
  }

  @override
  String sessionId(String id) {
    return 'सत्र $id';
  }

  @override
  String get escutcheonVision => 'एस्कुचeon विज़न';

  @override
  String get metricAbHeight => 'A–B ऊँचाई';

  @override
  String get metricCdWidth => 'C–D चौड़ाई';

  @override
  String get metricArea => 'क्षेत्र';

  @override
  String get metricSymmetry => 'समरूपता %';

  @override
  String get milkMirrorAnalysis => 'పాల Predictor विश्लेषण';

  @override
  String get measured => 'मापा गया';

  @override
  String centerEstimate(String liters) {
    return 'केंद्र अनुमान: $liters L/दिन';
  }

  @override
  String confidenceLabel(String percent) {
    return 'विश्वास: $percent%';
  }

  @override
  String get escutcheonMeasurements => 'एस्कुचeon माप';

  @override
  String get heightAb => 'ऊँचाई (A → B)';

  @override
  String get widthCd => 'चौड़ाई (C → D)';

  @override
  String get areaHw => 'क्षेत्र (H × W)';

  @override
  String get symmetryIndex => 'समरूपता सूचकांक';

  @override
  String percentOfFrame(String percent) {
    return 'फ्रेम का $percent%';
  }

  @override
  String percentBalanced(String percent) {
    return '$percent% संतुलित';
  }

  @override
  String get keyFeaturesExtracted => 'मुख्य विशेषताएँ निकाली गईं';

  @override
  String get featureArea => 'क्षेत्र';

  @override
  String get featureSymmetry => 'समरूपता';

  @override
  String get featureFullness => 'पूर्णता';

  @override
  String get featureTexture => 'बनावट';

  @override
  String aiCrossCheck(String liters, String match) {
    return 'AI क्रॉस-चेक: $liters L/दिन ($match% मिलान)';
  }

  @override
  String get dailyRevenue => 'दैनिक आय';

  @override
  String get monthlyRevenue => 'मासिक आय';

  @override
  String get milkMirrorFootnote =>
      '* फोटो पर एस्कुचeon लैंडमार्क (C/D) और थन (B) — डिबग में ओवरले देखें। एस्कुचeon + ऑन-डिवाइस AI से 1–30 L/दिन स्केल।';

  @override
  String get proofRulesGate => 'नियम गेट';

  @override
  String get proofPinBones => 'पिछले लैंडमार्क पहचाने';

  @override
  String get proofEscutcheon => 'एस्कुचeon मापा';

  @override
  String get proofTfliteRan => 'TFLite चला';

  @override
  String get inferenceProof => 'अनुमान प्रमाण';

  @override
  String get inferenceProofConsole => 'अनुमान प्रमाण (डिबग कंसोल देखें)';

  @override
  String get proofSession => 'सत्र';

  @override
  String get proofPredictedBy => 'द्वारा भविष्यवाणी';

  @override
  String get proofTfliteLoaded => 'TFLite लोड';

  @override
  String get proofInterpreter => 'इंटरप्रेटर';

  @override
  String get proofInterpreterRun => 'interpreter.run()';

  @override
  String get proofPass => 'पास';

  @override
  String get proofFail => 'फेल';

  @override
  String get proofMilkMirrorUi => 'పాల Predictor (UI):';

  @override
  String get proofHeightAb => 'ऊँचाई A→B';

  @override
  String get proofWidthCd => 'चौड़ाई C→D';

  @override
  String get proofLitersMeasured => 'लीटर (मापा)';

  @override
  String get proofTfliteClass => 'TFLite वर्ग';

  @override
  String get proofAllClassScores => 'सभी वर्ग स्कोर:';

  @override
  String get badgeMilkMirrorMeasurement => 'పాల PREDICTOR माप';

  @override
  String get badgeAiModelTflite => 'AI मॉडल (TFLite)';

  @override
  String get estimatedYield => 'अनुमानित उपज';

  @override
  String get dailyRevenueRow => 'दैनिक आय';

  @override
  String get monthlyRevenueRow => 'मासिक आय';

  @override
  String engineLabel(String engine) {
    return 'इंजन: $engine';
  }

  @override
  String litersPerMonth(String liters) {
    return '${liters}L / माह';
  }

  @override
  String get tfliteUntrainedWarning =>
      'यह TFLite फ़ाइल अभी आपकी भैंस फोटो पर प्रशिक्षित नहीं है। ऐप हमेशा एक वर्ग चुनता है, लेकिन 0% स्कोर का मतलब है कि मॉडल 6–10 L बैंड अलग नहीं कर सकता। training/train_model.py से प्रशिक्षित करें।';

  @override
  String get couldNotIdentifyBuffalo => '* इस फोटो से भैंस पहचान नहीं हो सकी';

  @override
  String get localBuffaloDebug =>
      '* स्थानीय भैंस — ऊपर डिबग इनपुट के साथ हाइबrid मॉडल';

  @override
  String get localBuffaloPhoto => '* स्थानीय भैंस — केवल फोटो से अनुमान';

  @override
  String get badgeImageBasedModel => 'छवि-आधारित मॉडल';

  @override
  String get visualAnalysisComplete => 'दृश्य विश्लेषण पूर्ण';

  @override
  String get basedOnImageFeatures => 'छवि विशेषताओं पर आधारित';

  @override
  String get visualPrediction => 'दृश्य भविष्यवाणी';

  @override
  String get visualScore => 'दृश्य स्कोर';

  @override
  String get udderSize => 'थन का आकार';

  @override
  String get bodyCondition => 'शरीर की स्थिति';

  @override
  String get frameSize => 'फ्रेम आकार';

  @override
  String get buildScoreDebug => 'बिल्ड स्कोर (डिबग)';

  @override
  String get imageBasedFootnote => '* दृश्य AI मॉडल पर आधारित (छवि विश्लेषण)';

  @override
  String get debugHybridInputs => 'डिबग — हाइबrid मॉडल इनपुट';

  @override
  String localBuffaloOnly(String type) {
    return 'केवल स्थानीय भैंस ($type)। प्रोडक्शन में छिपा।';
  }

  @override
  String get feedQuality => 'चारा गुणवत्ता';

  @override
  String get feedHighProtein => 'उच्च प्रोटीन';

  @override
  String get feedStandard => 'मानक';

  @override
  String get feedLow => 'कम';

  @override
  String get ageYears => 'आयु (वर्ष)';

  @override
  String get lactationNumber => 'स्तनपान #';

  @override
  String get daysInMilk => 'दूध में दिन';

  @override
  String get labelNoBuffaloDetected => 'कोई भैंस नहीं मिली';

  @override
  String get labelAiModelNotLoaded => 'AI मॉडल लोड नहीं';

  @override
  String get labelDetectionError => 'पहचान त्रुटि';

  @override
  String get labelPhotoNotSuitable => 'फोटो उपयुक्त नहीं';

  @override
  String get speciesBuffalo => 'भैंस';

  @override
  String get speciesUnknown => 'अज्ञात';

  @override
  String get speciesUncertain => 'अनिश्चित';

  @override
  String get sexFemale => 'मादा';

  @override
  String get sexMale => 'नर';

  @override
  String get lactationLactating => 'दूध दे रही';

  @override
  String get lactationDry => 'सूखी / दिखाई नहीं';

  @override
  String get healthNormal => 'सामान्य';

  @override
  String get healthCheckAsymmetry => 'असमानता जाँचें';

  @override
  String get healthPoorImageQuality => 'खराब फोटो गुणवत्ता';

  @override
  String get stageEarly => 'प्रारंभ (0–100 DIM)';

  @override
  String get stageMid => 'मध्य (100–200 DIM)';

  @override
  String get stageLate => 'अंत (>200 DIM)';

  @override
  String get stepCaptureImage => 'फोटो कैप्चर';

  @override
  String get stepRearPhoto => 'पिछला थन फोटो';

  @override
  String get stepAnimalDetection => 'पशु पहचान';

  @override
  String get stepAnimalDetected => 'पशु पहचाना';

  @override
  String get stepFailed => 'विफल';

  @override
  String get stepSpecies => 'प्रजाति';

  @override
  String get stepSexCheck => 'लिंग जाँच';

  @override
  String get stepLactation => 'स्तनपान';

  @override
  String get stepHealthScreen => 'स्वास्थ्य जाँच';

  @override
  String get stepYieldPredict => 'उपज भविष्यवाणी';

  @override
  String get alertBlockedDefault => 'भविष्यवाणी रोकी — फोटो या पशु ठीक करें';

  @override
  String get alertMaleBuffalo =>
      'नर भैंस — दूध उपज केवल दूध देने वाली मादाओं के लिए';

  @override
  String get tipMaleBuffalo =>
      'दूध देने वाली मादा का पिछला फोटो लें, थन दिखाई दे।';

  @override
  String get alertEscutcheonFailed =>
      'एस्कुचeon माप नहीं — पिछले थन दृश्य का उपयोग करें';

  @override
  String get tipEscutcheon =>
      '3–5 फीट पीछे खड़े हों, कैमरा थन की ऊँचाई पर, पूरा थन फ्रेम में।';

  @override
  String get alertCaution =>
      'सावधानी से भविष्यवाणी — TFLite प्रशिक्षित करें या फोटो दोबारा लें';

  @override
  String get tipCaution =>
      'स्पष्ट पिछले थन फोटो का उपयोग करें; अधिक लेबल्ड फोटो जोड़ें।';

  @override
  String get alertHighConfidence => 'उच्च-विश्वास పాల Predictor विश्लेषण';

  @override
  String get tipHighConfidence =>
      'पोषण बनाए रखें और साप्ताहिक थन स्वास्थ्य जाँचें।';

  @override
  String get alertComplete => 'विश्लेषण पूर्ण — नीचे माप देखें';

  @override
  String get tipComplete => 'बेहतर सटीकता के लिए DIM और parity लॉग करें।';

  @override
  String get overlayLeftPin => 'C';

  @override
  String get overlayRightPin => 'D';

  @override
  String get overlayUdder => 'थन';

  @override
  String get navHome => 'होम';

  @override
  String get navGalleries => 'गैलरी';

  @override
  String get navScan => 'स्कैन';

  @override
  String get navInsights => 'अंतर्दृष्टि';

  @override
  String get navAbout => 'परिचय';

  @override
  String get viewAll => 'सभी देखें';

  @override
  String get latestPrediction => 'नवीनतम भविष्यवाणी';

  @override
  String get quickInsights => 'त्वरित अंतर्दृष्टि';

  @override
  String get recentAnalyses => 'हाल के विश्लेषण';

  @override
  String get insightUdderHealth => 'थन स्वास्थ्य';

  @override
  String get insightSymmetry => 'सममिति';

  @override
  String get insightBodyCondition => 'शारीरिक स्थिति';

  @override
  String get insightHeatStress => 'गर्मी तनाव';

  @override
  String get statusGood => 'अच्छा';

  @override
  String get statusLow => 'कम';

  @override
  String get statusDash => '—';

  @override
  String get estimatedDailyMilkYield => 'अनुमानित दैनिक दूध उपज';

  @override
  String get highYieldPotential => 'उच्च उपज क्षमता';

  @override
  String get healthStatus => 'स्वास्थ्य स्थिति';

  @override
  String get confidence => 'विश्वास';

  @override
  String get noPredictionsYet => 'अभी कोई भविष्यवाणी नहीं';

  @override
  String get noPredictionsHint =>
      'पिछले थन का फोटो लेने के लिए स्कैन टैप करें और पहली उपज अनुमान प्राप्त करें।';

  @override
  String get startScan => 'स्कैन शुरू करें';

  @override
  String get emptyRecentHint =>
      'स्कैन करने के बाद आपके हाल के विश्लेषण यहाँ दिखेंगे।';

  @override
  String get galleriesTitle => 'गैलरी';

  @override
  String get addPhoto => 'फोटो जोड़ें';

  @override
  String get samplePhotos => 'नमूना फोटो';

  @override
  String get samplePhotosHint =>
      'प्रोजेक्ट में assets/images/ के अंतर्गत फोटो जोड़ें, फिर ऐप पुनः बनाएं।';

  @override
  String myScans(int count) {
    return 'मेरे स्कैन ($count)';
  }

  @override
  String get myScansEmpty =>
      'स्कैन करने के बाद पूर्ण AI विश्लेषण यहाँ दिखाई देंगे।';

  @override
  String get insightsTitle => 'अंतर्दृष्टि';

  @override
  String get insightsSubtitle =>
      'आपके हाल के పాల Predictor विश्लेषण का सारांश।';

  @override
  String get totalScans => 'कुल स्कैन';

  @override
  String get latestYield => 'नवीनतम उपज';

  @override
  String get latestConfidence => 'नवीनतम विश्वास';

  @override
  String get insightsEmpty => 'व्यक्तिगत डेयरी अंतर्दृष्टि के लिए स्कैन चलाएं।';

  @override
  String get aboutTagline => 'AI संचालित डेयरी विश्लेषण';

  @override
  String get aboutWhatWeDo => 'हम क्या करते हैं';

  @override
  String get aboutWhatWeDoBody =>
      'भैंस के पिछले थन के फोटो का विश्लेषण करके ऑन-डिवाइस AI और एस्कुचeon ज्यामिति से दैनिक दूध उत्पादन का अनुमान लगाते हैं।';

  @override
  String get aboutBuiltFor => 'किसके लिए बनाया';

  @override
  String get aboutBuiltForBody =>
      'स्थानीय / देसी भैंस — पिछले थन कैप्चर वर्कफ़्लो।';

  @override
  String get aboutVersion => 'संस्करण';

  @override
  String aboutCopyright(int year) {
    return '© $year పాల Predictor';
  }

  @override
  String get choosePhotoSource => 'फोटो स्रोत चुनें';

  @override
  String get choosePhotoSourceSub =>
      'नया पिछला फोटो लें या अपने डिवाइस से चुनें';

  @override
  String get cameraSubtitle => 'नया फोटो लें';

  @override
  String get gallerySubtitle => 'डिवाइस फोटो से चुनें';

  @override
  String get samplePhotosBundled => 'नमूना फोटो (बंडल)';

  @override
  String get captureGuidelines => 'कैप्चर दिशानिर्देश';

  @override
  String get captureGuidelinesSub => 'स्कैन करते समय लाइव सुझाव';

  @override
  String get captureTipClearImage => 'स्पष्ट फोटो = बेहतर भविष्यवाणी';

  @override
  String get captureLive => 'लाइव';

  @override
  String captureTipNofTotal(int current, int total) {
    return 'सुझाव $current / $total';
  }

  @override
  String get guidelineStandBehind => 'भैंस के 3–5 फीट पीछे खड़े हों';

  @override
  String get guidelineCameraLevel => 'कैमरा थन की ऊँचाई पर रखें';

  @override
  String get guidelineFullUdder => 'पूरा थन फ्रेम में कैप्चर करें';

  @override
  String get guidelinePortrait => 'पोर्ट्रेट मोड का उपयोग करें';

  @override
  String get guidelineLighting => 'अच्छी रोशनी सुनिश्चित करें';

  @override
  String get guidelineCleanUdder => 'थन और पूंछ क्षेत्र साफ रखें';

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String get onboardingNext => 'आगे';

  @override
  String get onboardingGetStarted => 'शुरू करें';

  @override
  String litersPerDayShort(String liters) {
    return '$liters ली/दिन';
  }
}
