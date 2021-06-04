function plotHypnogramsPerChannel(subject,exp,saveFigs)

if ~exist('saveFigs','var') || isempty(saveFigs)
    saveFigs = 0;
end

info = getExperimentInfo(subject,exp);

macroFiles = dir(fullfile(info.linkToConvertedData,'MACRO*'));
hasBR = arrayfun(@(x)~isempty(regexp(x.name,'BR','once')),macroFiles);
macroFiles(hasBR) = [];
macroChannelNums = arrayfun(@(x)str2double(regexp(x.name,'\d*','once','match')),macroFiles);
[macroChannelNums,ind] = sort(macroChannelNums);
macroFiles = macroFiles(ind);

allChannels = cellfun(@(x)repmat({x},1,8),info.montagePos,'uniformoutput',0);
allChannels = cat(2,allChannels{:});
regions = allChannels(macroChannelNums);

% find start and end times if possible:
switch info.recordingSystem
    case 'BlackRock'
        whatToDo = questdlg('Are there Nlx Macro Files','macros?','yes','no','yes');
        if strcmp(whatToDo,'no')
            startTime = []; endTime = [];
        else
            disp('Please find an Nlx raw data file')
            [filename, pathname] = uigetfile('*.ncs','Please find an Nlx raw data file');
            [startTime, endTime] = Nlx_getStartAndEndTimes(fullfile(pathname,filename));
        end
    case 'Neuralynx'
        files = dir(fullfile(info.linkToRaw,'L*.ncs'));
        if isempty(files)
            files = dir(fullfile(info.linkToRaw,'R*.ncs'));
        end
        filename = files(1).name;
        [startTime endTime] = Nlx_getStartAndEndTimes(fullfile(info.linkToRaw,filename));
end

nFigs = ceil(length(macroFiles)/24);
f = arrayfun(@(x)figure('units','normalized','position',[.2 .3 .6 .6]),1:nFigs,'uniformoutput',0);
ax = cellfun(@(x)arrayfun(@(m)subplot2(3,8,m,[],'borderPct',.025,'parent',x),1:24,'uniformoutput',0),f,'uniformoutput',0);

for m = 1:length(macroFiles)
    if mod(m,24)==1
        fprintf('\n')
    end
    fprintf('.')
    thisAx = ax{ceil(m/24)}{modUp(m,24)};
    plotHypnogram(fullfile(info.linkToConvertedData,macroFiles(m).name),...
        thisAx,startTime,endTime);
    title(thisAx,sprintf('%s (%s)',strrep(macroFiles(m).name,'.mat',''),regions{m}));
end
%%
if saveFigs
    saveDir = fullfile(info.linkToConvertedData,'sleepScoring','Per Channel Hypnograms');
    if ~exist(saveDir)
        mkdir(saveDir);
    end
    for i = 1:length(f)
        export_fig(fullfile(saveDir,sprintf('Hypnograms Fig %d.pdf',i)),f{i})
    end
end 