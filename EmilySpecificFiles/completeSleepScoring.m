function obj = completeSleepScoring(subject,experiment,preExp,postExp,doManualStep)

if ~exist('preExp','var')
    preExp = [];
end
if ~exist('postExp','var')
    postExp = [];
end
if ~exist('doManualStep','var')
    doManualStep = 1;
end


obj = prepSleepScoringObject(sleepScoring_iEEG,subject,experiment,preExp,postExp);
obj = chooseScoringChannels(obj);
obj = evaluateDelta(obj);

if doManualStep
obj = manuallyValidateSleepScoring(obj);
end

