import 'detection.dart';

/// Processing step IDs for the upload pipeline.
enum PipelineStep {
  readMetadata,
  coordinateParsing,
  resampling,
  leeFilter,
  motionCorrection,
  featureExtraction,
  regionProposal,
  similaritySearch,
  riskScoring,
  missionReady,
}

extension PipelineStepLabel on PipelineStep {
  String get label => switch (this) {
    PipelineStep.readMetadata      => 'Reading Metadata',
    PipelineStep.coordinateParsing => 'Coordinate Parsing',
    PipelineStep.resampling        => 'Resampling',
    PipelineStep.leeFilter         => 'Lee Filter',
    PipelineStep.motionCorrection  => 'Motion Correction',
    PipelineStep.featureExtraction => 'Feature Extraction',
    PipelineStep.regionProposal    => 'Region Proposal',
    PipelineStep.similaritySearch  => 'Similarity Search',
    PipelineStep.riskScoring       => 'Risk Scoring',
    PipelineStep.missionReady      => 'Mission Ready',
  };

  String get description => switch (this) {
    PipelineStep.readMetadata      => 'Extracting tow height, slant range, heading...',
    PipelineStep.coordinateParsing => 'Parsing WGS84 GPS coordinates...',
    PipelineStep.resampling        => 'Normalizing resolution to 0.1m/pixel...',
    PipelineStep.leeFilter         => 'Removing speckle noise from sonar...',
    PipelineStep.motionCorrection  => 'Correcting motion blur and ping dropouts...',
    PipelineStep.featureExtraction => 'Computing shadow length, height, texture...',
    PipelineStep.regionProposal    => 'Running Tiny U-Net candidate detection...',
    PipelineStep.similaritySearch  => 'FAISS retrieval against debris library...',
    PipelineStep.riskScoring       => 'Computing navigation hazard score...',
    PipelineStep.missionReady      => 'Targets indexed and ready for review.',
  };
}

class ScanResult {
  final String fileName;
  final String? uploadId;
  final PipelineStep? activeStep;
  final int completedSteps;
  final Map<PipelineStep, double> stepProgress; // 0.0 - 1.0
  final Map<PipelineStep, Duration> stepElapsed;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;

  // Metadata from backend
  final double? towHeightM;
  final double? slantRangeM;
  final double? headingDeg;
  final double? resolutionMPerPx;
  final int?    candidateCount;
  final int?    detectionCount;
  final List<Detection>? detections;
  final String? missionAdvisory;

  const ScanResult({
    required this.fileName,
    this.uploadId,
    this.activeStep,
    this.completedSteps = 0,
    this.stepProgress   = const {},
    this.stepElapsed    = const {},
    this.isComplete     = false,
    this.hasError       = false,
    this.errorMessage,
    this.towHeightM,
    this.slantRangeM,
    this.headingDeg,
    this.resolutionMPerPx,
    this.candidateCount,
    this.detectionCount,
    this.detections,
    this.missionAdvisory,
  });

  ScanResult copyWith({
    PipelineStep? activeStep,
    int? completedSteps,
    Map<PipelineStep, double>? stepProgress,
    Map<PipelineStep, Duration>? stepElapsed,
    bool? isComplete,
    bool? hasError,
    String? errorMessage,
    String? uploadId,
    double? towHeightM,
    double? slantRangeM,
    double? headingDeg,
    double? resolutionMPerPx,
    int? candidateCount,
    int? detectionCount,
    List<Detection>? detections,
    String? missionAdvisory,
  }) => ScanResult(
    fileName:         fileName,
    uploadId:         uploadId         ?? this.uploadId,
    activeStep:       activeStep       ?? this.activeStep,
    completedSteps:   completedSteps   ?? this.completedSteps,
    stepProgress:     stepProgress     ?? this.stepProgress,
    stepElapsed:      stepElapsed      ?? this.stepElapsed,
    isComplete:       isComplete       ?? this.isComplete,
    hasError:         hasError         ?? this.hasError,
    errorMessage:     errorMessage     ?? this.errorMessage,
    towHeightM:       towHeightM       ?? this.towHeightM,
    slantRangeM:      slantRangeM      ?? this.slantRangeM,
    headingDeg:       headingDeg       ?? this.headingDeg,
    resolutionMPerPx: resolutionMPerPx ?? this.resolutionMPerPx,
    candidateCount:   candidateCount   ?? this.candidateCount,
    detectionCount:   detectionCount   ?? this.detectionCount,
    detections:       detections       ?? this.detections,
    missionAdvisory:  missionAdvisory  ?? this.missionAdvisory,
  );
}
