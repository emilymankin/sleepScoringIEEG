classdef sleepScoring_iEEG < handle
    
    %The class compares power of channel selected for sleep-scoring
    
    properties
        subject;
        experiment;
        linkToMacroRawData;
        macroFilePrefix = 'MACRO';
        macroSystem = 'Neuralynx';
        linkToConvertedData;
        filenameRegionCorrespondence;
        saveDir;
        saveName;
        startTime;
        endTime;
        preData;
        postData;
        sleepRange;
        
        deltaRangeMin = .5;
        deltaRangeMax = 4;
        spRangeMin = 9;
        spRangeMax = 15;
        
        flimits = [0 30]';
        samplingRate;
        sub_sampleRate = 200;
        
        classificationMethod = 'mixture'; % can be 'threshold' or 'mixture'
        % parameters for threshold method:
        REMprctile = 20;
        REMthresh;
        NREMprctile = 50;
        NREMthresh;
        
        minDistBetweenEvents = 60; % sec
        
        PLOT_FIG = 1;
        scaling_factor_delta_log = 2*10^-4 ; % Additive Factor to be used when computing the Spectrogram on a log scale
        markerSize = 20;
        
        scoringEpochDuration = 30; % sec
        NREM_CODE = 1;
        REM_CODE = -1;
        
        bestScoringChannels;
        bestScoringChannelNames;
        
        spectralData;
        sleepInds;
        sleepScoreVectorByChannel;
        sleepScoreVectorClusterByChannel;
        manualResults;
        regionsModifiedByHand;
        finalSleepScoreVector;
        
    end
    
    methods
        
        function obj = prepSleepScoringObject(obj,subject,experiment,preExp,postExp)
            if isempty(obj.subject)
                obj.subject = subject;
            end
            if isempty(obj.experiment)
                obj.experiment = experiment;
            end
            
            if ischar(obj.experiment)
                % passed in a directory, not something from the database.
                % Must handle somewhat differently:
                % Assuming for the moment that this won't ask for pre and
                % post data. Can change that if you decide you want it;
                % model on the code in the else block.
                obj.linkToConvertedData = obj.experiment;
                obj.linkToMacroRawData = obj.experiment;
                doPre = 0; doPost = 0;
            else
                info = getExperimentInfo(obj.subject,obj.experiment); % there was a third argument (1) but I don't know why...
                if ~isfield(info,'linkToConvertedData'),info.linkToConvertedData = info.rawUnpacked;end
                obj.linkToConvertedData = info.linkToConvertedData;
                
                
                % add links to pre and post experiments if given
                if isempty(obj.preData) && exist('preExp','var') && ~isempty(preExp)
                    doPre = 1;
                    infoPre = getExperimentInfo(obj.subject,preExp);% there was a third argument (1) but I don't know why...
                    if ~isfield(infoPre,'linkToConvertedData'),infoPre.linkToConvertedData = infoPre.rawUnpacked;end
                    obj.preData.linkToConverted = infoPre.linkToConvertedData;
                    obj.preData.linkToMacroRawData = [];
                    obj.preData.startTime = [];
                    obj.preData.endTime = [];
                else
                    doPre = ~isempty(obj.preData);
                end
                if isempty(obj.postData) && exist('postExp','var') && ~isempty(postExp)
                    doPost = 1;
                    infoPost = getExperimentInfo(obj.subject,postExp);% there was a third argument (1) but I don't know why...
                    if ~isfield(infoPost,'linkToConvertedData'),infoPost.linkToConvertedData = infoPost.rawUnpacked;end
                    obj.postData.linkToConverted = infoPost.linkToConvertedData;
                    obj.preData.linkToMacroRawData = [];
                    obj.postData.startTime = [];
                    obj.postData.endTime = [];
                else
                    doPost = ~isempty(obj.postData);
                end
            end
            
            obj.saveDir = fullfile(obj.linkToConvertedData,'sleepScoring');
            obj.saveName = ['sleepScoringObj_',datestr(now,'yyyy_mm_dd-HH_MM')];
            
            % find start and end times if possible:
            if isempty(obj.linkToMacroRawData)
                switch info.recordingSystem
                    case 'BlackRock'
                        whatToDo = questdlg('Micros were recorded on BR. Are there Nlx Macro Files to use?',...
                            'Use Nlx Macros?','yes','no','yes');
                        if strcmp(whatToDo,'no')
                            obj.linkToMacroRawData = strrep(info.linkToRaw,'ns5','ns3');
                            [obj.startTime, obj.endTime] = BR_getStartAndEndTimes(info.linkToRaw);
                            obj.macroFilePrefix = 'MACROBR';
                            if doPre
                                obj.preData.linkToMacroRawData = strrep(infoPre.linkToRaw,'ns5','ns3');
                                [obj.preData.startTime, obj.preData.endTime] = BR_getStartAndEndTimes(infoPre.linkToRaw);
                            end
                            if doPost
                                obj.postData.linkToMacroRawData = strrep(infoPost.linkToRaw,'ns5','ns3');
                                [obj.postData.startTime, obj.postData.endTime] = BR_getStartAndEndTimes(infoPost.linkToRaw);
                            end
                            obj.getFileRegionCorrespondence('BR');
                        else
                            fprintf('\nPlease find an Nlx raw data file for experiment %d\n', experiment);
                            [filename, pathname] = uigetfile('*.ncs',sprintf('Please find an Nlx raw data file for experiment %d', experiment));
                            obj.linkToMacroRawData = pathname;
                            [obj.startTime, obj.endTime] = Nlx_getStartAndEndTimes(fullfile(pathname,filename));
                            if doPre
                                fprintf('\nPlease find an Nlx raw data file for experiment %d\n', preExp);
                                [filename, pathname] = uigetfile('*.ncs',sprintf('Please find an Nlx raw data file for experiment %d', preExp));
                                obj.preData.linkToMacroRawData = pathname;
                                [obj.preData.startTime, obj.preData.endTime] = Nlx_getStartAndEndTimes(fullfile(pathname,filename));
                            end
                            if doPost
                                fprintf('\nPlease find an Nlx raw data file for experiment %d\n', postExp);
                                [filename, pathname] = uigetfile('*.ncs',sprintf('Please find an Nlx raw data file for experiment %d', postExp));
                                obj.postData.linkToMacroRawData = pathname;
                                [obj.postData.startTime, obj.postData.endTime] = Nlx_getStartAndEndTimes(fullfile(pathname,filename));
                            end
                            obj.getFileRegionCorrespondence('Nlx');
                        end
                        
                    case 'Neuralynx'
                        files = dir(fullfile(info.linkToRaw,'L*.ncs'));
                        if isempty(files)
                            files = dir(fullfile(info.linkToRaw,'R*.ncs'));
                        end
                        filename = files(1).name;
                        obj.linkToMacroRawData = info.linkToRaw;
                        [obj.startTime, obj.endTime] = Nlx_getStartAndEndTimes(fullfile(info.linkToRaw,filename));
                        if doPre
                            files = dir(fullfile(infoPre.linkToRaw,'L*.ncs'));
                            if isempty(files)
                                files = dir(fullfile(infoPre.linkToRaw,'R*.ncs'));
                            end
                            filename = files(1).name;
                            obj.preData.linkToMacroRawData = infoPre.linkToRaw;
                            [obj.preData.startTime, obj.preData.endTime] = Nlx_getStartAndEndTimes(fullfile(infoPre.linkToRaw,filename));
                        end
                        if doPost
                            files = dir(fullfile(infoPost.linkToRaw,'L*.ncs'));
                            if isempty(files)
                                files = dir(fullfile(infoPost.linkToRaw,'R*.ncs'));
                            end
                            filename = files(1).name;
                            obj.postData.linkToMacroRawData = infoPost.linkToRaw;
                            [obj.postData.startTime, obj.postData.endTime] = Nlx_getStartAndEndTimes(fullfile(infoPost.linkToRaw,filename));
                        end
                        obj.getFileRegionCorrespondence('Nlx');
                end
            elseif isempty(obj.startTime)
                if exist(obj.linkToMacroRawData,'dir')
                    % this is a Nlx dir
                    files = dir(fullfile(obj.linkToMacroRawData,'L*.ncs'));
                    if isempty(files)
                        files = dir(fullfile(obj.linkToMacroRawData,'R*.ncs'));
                    end
                    filename = files(1).name;
                    [obj.startTime, obj.endTime] = Nlx_getStartAndEndTimes(fullfile(obj.linkToMacroRawData,filename));
                    obj.macroFilePrefix = 'MACRO';
                    obj = unpackMacrosWithPrePost(obj,doPre,doPost);
                elseif exist(obj.linkToMacroRawData,'file')
                    % this is a BR file
                    [obj.startTime, obj.endTime] = BR_getStartAndEndTimes(obj.linkToMacroRawData);
                    obj.macroFilePrefix = 'MACROBR';
                end
                
            end
                        
            
            
            oneFilename = dir(fullfile(obj.linkToConvertedData,[obj.macroFilePrefix,'*']));
            data = load(fullfile(obj.linkToConvertedData,oneFilename(1).name),'samplingInterval');
            sampInt = data.samplingInterval;
            sampRate = 1/sampInt; % Stored in kHz
            obj.samplingRate = sampRate * 1000;
            
            if isempty(obj.endTime)
                temp = whos('-file',fullfile(obj.linkToConvertedData,macroFiles(1).name));
                dataInfo = temp(ismember({temp.name},'data'));
                nSamples = prod(dataInfo.size);
                sessionDurationSeconds = nSamples/obj.samplingRate;
                dateFormat = 'yyyy/mm/dd HH:MM:SS';
                obj.endTime = datestr(datenum(obj.startTime,dateFormat)+sessionDurationSeconds/24/60/60,dateFormat);
            end
            obj.getFileRegionCorrespondence(obj.macroSystem);
            obj.saveSelf;
        end
        
        function obj = getFileRegionCorrespondence(obj,macroSystem)
            % Getting macro regions and filenames was done a few times
            % throughout this code, inconsistently. And now that we can
            % record macros on BR as well as Nlx it gets even more
            % confusing. Trying to simplify by doing it once and storing in
            % the object's property filenameRegionCorresponcence, which
            % will now be a 4 x nMacroFile cell where each column represents
            % one macro file with row 1 being filename, row 2 region,
            % row 3 the best title string to use, and row 4 the channel number.
            % This code will probably need some debugging....
            macroFiles = dir(fullfile(obj.linkToConvertedData,[obj.macroFilePrefix,'*']));
            
            doPre = ~isempty(obj.preData); doPost = ~isempty(obj.postData);
            if isempty(macroFiles)
                obj = unpackMacrosWithPrePost(obj,doPre,doPost);
                macroFiles = dir(fullfile(obj.linkToConvertedData,[obj.macroFilePrefix,'*']));
            end
            
            macroChannelNums = arrayfun(@(x)str2double(regexp(x.name,'\d*','once','match')),macroFiles);
            [macroChannelNums,ind] = sort(macroChannelNums);
            macroFiles = macroFiles(ind);
            
            if ischar(obj.experiment)
                filenameList = {macroFiles.name};
                regionList = cellfun(@(x)regexp(x,'(?<=\_)(L|R)\w*','match','once'),filenameList,'uniformoutput',0);
                obj.filenameRegionCorrespondence = [filenameList; regionList; cellfun(@(x)strrep(x,'.mat',''),filenameList,'uniformoutput',0)];
            else
            thisExp = getExperimentInfo(obj.subject,obj.experiment);
            
            switch macroSystem
                case 'Nlx'
                           warning('This code hasn''t been tested since we moved it around. I''m putting you in keyboard mode so you can put a debug stop in and go from there.')
                           keyboard
            brainRegions = thisExp.montagePos;
            brainRegions(cellfun(@(x)isempty(x),brainRegions)) = [];
            macroRawFiles = cellfun(@(x)[arrayfun(@(y)sprintf('%s%d.ncs',x,y),1:8,'uniformoutput',0)],brainRegions,'uniformoutput',0);
            macroRawFiles = cat(2,macroRawFiles{:});
            
            fullNames = arrayfun(@(x)sprintf('%s%d_%s.mat',obj.macroFilePrefix,x,...
                regexp(macroRawFiles{x},'[A-Z]*\d','match','once')),1:length(macroRawFiles),'uniformoutput',0);
            simpleNames = arrayfun(@(x)sprintf('%s%d.mat',obj.macroFilePrefix,x),1:length(macroRawFiles),'uniformoutput',0);
            alreadyExists = logical(cellfun(@(x)exist(fullfile(obj.linkToConvertedData,x),'file'),fullNames));
            alreadyExists_simple = logical(cellfun(@(x)exist(fullfile(obj.linkToConvertedData,x),'file'),simpleNames));
            if sum(alreadyExists_simple)>sum(alreadyExists)
                fileNames = simpleNames;
            else
                fileNames = fullNames;
            end
            obj.filenameRegionCorrespondence = [fileNames;fullNames];
            
            
             filenameList = fileNames;
                regionList = cellfun(@(x)arrayfun(@(y)sprintf('%s',x),1:8,'uniformoutput',0),brainRegions,'uniformoutput',0); regionList = cat(2,regionList{:});
                withinRegionChannelList = repmat({arrayfun(@(y)sprintf('%d',y),1:8,'uniformoutput',0)},size(brainRegions)); withinRegionChannelList = cat(2,withinRegionChannelList{:});
                titleStrings = cellfun(@(fn,r,n)sprintf('%s%s (%s)',r,n,fn),...
                    cellfun(@(x)strrep(x,'.mat',''),filenameList,'uniformoutput',0),regionList,withinRegionChannelList,'uniformoutput',0);
                
                obj.filenameRegionCorrespondence = [filenameList; regionList; titleStrings; els2cells(1:length(regionList))];
                
                obj.filenameRegionCorrespondence(6,:) = fullNames;
            
            
            % The code block below was elsewhere, and it differs from the
            % block above. Need to debug both to figure out why I did one
            % thing in one place and one in another. 
            
%             
%             if strcmp(obj.macroFilePrefix,'MACRO')
%                 hasBR = arrayfun(@(x)~isempty(regexp(x.name,'BR','once')),macroFiles);
%                 macroFiles(hasBR) = [];
%             end

%             
%             % EM: I had this here previously, withouth the if for 
%             % compatibility with Nlx macros, since they are always between channels 1 and 128.
%             % but it messes things up when
%             % macros were recorded on BR. So here I just added the if
%             % around it so that this will only be done for Nlx.
%             if strcmp(obj.macroFilePrefix,'MACRO')
%             ind = macroChannelNums>128;
%             macroChannelNums(ind) = []; macroFiles(ind) = [];
%             end
%             
%             %EM: Again, the code below assumes our Nlx conventions, as it
%             %was written before we started having macros on BR. So I'm
%             %putting an if around it, and will just ask for BR channels to
%             %be intered by hand. Someday I need to update the code to deal
%             %with BR macros but I won't do that in the current
%             %instantiation of patientDataManager...
%             if strcmp(obj.macroFilePrefix,'MACRO')
%             if isnumeric(obj.experiment)
%                 info = getExperimentInfo(obj.subject,obj.experiment);
%                 allChannels = cellfun(@(x)repmat({x},1,8),info.montagePos,'uniformoutput',0);
%                 allChannels = cat(2,allChannels{:});
%                 regions = allChannels(cellfun(@(x)~isempty(x),allChannels));%(macroChannelNums);
%                 missingChannels = ~ismember(1:length(regions),macroChannelNums);
%                 regions(missingChannels) = {'NotRecorded'};
%                 if ~isempty(obj.filenameRegionCorrespondence)
%                     obj.filenameRegionCorrespondence(1,missingChannels) = {'NotRecorded'};
%                 end
%             else
%                 regions = arrayfun(@(x)regexp(x.name,'(?<=\_)[A-Z]*\d*','match','once'),macroFiles,'uniformoutput',0)';
%                 % For consistency with file naming conventions, we have to
%                 % have 8 macros per region, even if only 7 were recorded.
%                 % So fix that here:
%                 numsGiven = cellfun(@(x)str2double(x(end)),regions);
%                 regionList = regions(numsGiven==1);
%                 regionList = cellfun(@(x)arrayfun(@(y)strrep(x,'1',num2str(y)),1:8,'uniformoutput',0),regionList,'uniformoutput',0);
%                 regionList = cat(2,regionList{:});
%                 missing = ~ismember(regionList,regions);
%                 regions = regionList; regions(missing) = {'NotRecorded'};
%             end
            
                case 'BR'
                   disp('Macros were recorded on BR. Please enter a string in the following format:')
                disp('{region1,channelList,region2,channelList....}')
                disp('For example: {''RA'',1:7,''RAH'',8:15,...}')
                disp('Note that BR macros are typically recorded on higher channels (97+ or 129+), so if you start from 1, we will add what''s necessary to get everything up to the first MACROBR channel that exists. But if you start from another number, we will assume you mean that literally.')
                ok = 0;
                regList = input('','s');
                while ~ok

                if strcmpi(regList,'cancel')
                    return
                elseif strcmpi(regList,'exc')
                    disp(exception)
                    disp('type dbcont to continue')
                    keyboard
                end
                try
                    regList = eval(regList);
                    if all(cellfun(@(x)ischar(x),regList(1:2:end))) & ...
                            all(cellfun(@(x)isnumeric(x),regList(2:2:end)))
                    ok = 1;
                    else
                        regList = input('You used the wrong file format. Please see the example above and try again (or type ''cancel'' to get out of this loop)\n','s');
                    end
                catch exception
                    regList = input('You typed something wrong. Please try again (or type ''cancel'' to get out of this loop or exc to display the exception)\n','s');
                end
                end
                if regList{2}(1)==1
                    offset = min(macroChannelNums)-1;
                else
                    offset = 0;
                end
                regionList = cell(1,regList{end}(end)+offset);
                withinRegionChannelList = regionList;
                for ii = 1:2:length(regList)
                 regionList(regList{ii+1}+offset) = regList(ii);
                 withinRegionChannelList(regList{ii+1}+offset) = els2cells(1:length(regList{ii+1}));
                end
                filenameList = cell(1,max(macroChannelNums));
                for ii = 1:length(macroChannelNums)
                    filenameList{macroChannelNums(ii)} = macroFiles(ii).name;
                end
                
                [common toKeep missing] = getCommonElements(macroChannelNums,find(cellfun(@(x)~isempty(x),regionList)));
                worryString = [];
                if ~isempty(missing{1})
                    worryString = [worryString sprintf('This file exists but doesn''t have a region associated to it: %s\n',filenameList{missing{1}})];
                end
                if ~isempty(missing{2})
                    worryString = [worryString sprintf('This region is listed but doesn''t have a file associated to it: %s%d\n',regionList{missing{2}},withinRegionChannelList{missing{2}})];
                end
                if ~isempty(worryString)
                    warning(sprintf('The file list and region list weren''t in perfect agreement.\n%s Please double check and type dbcont once regionList, withinRegionChannelList,and filenameList are okay. We will take only the common elements from each.',worryString))
                    keyboard
                    [common toKeep missing] = getCommonElements(find(cellfun(@(x)~isempty(x),filenameList)),find(cellfun(@(x)~isempty(x),regionList)));
                end
                filenameList = filenameList(common);
                regionList = regionList(common);
                withinRegionChannelList = withinRegionChannelList(common);
                titleStrings = cellfun(@(fn,r,n)sprintf('%s%s (%s)',r,n,fn),...
                    cellfun(@(x)strrep(x,'.mat',''),filenameList,'uniformoutput',0),regionList,withinRegionChannelList,'uniformoutput',0);
                
                obj.filenameRegionCorrespondence = [filenameList; regionList; titleStrings; els2cells(common)'];
            end
            end
            obj.saveSelf;
        end

        function obj = unpackMacrosWithPrePost(obj,doPre,doPost)
            % First figure out whether macros have been upnacked in the
            % main folder, and what filenames were used
            %             macroRawFiles = dir(fullfile(obj.linkToMacroRawData,'*.ncs'));
            %             macroRawFiles = {macroRawFiles.name};
            %             notReallyMacro = cellfun(@(x)~strcmp(x(1),'L') && ~strcmp(x(1),'R'),macroRawFiles);
            %             macroRawFiles(notReallyMacro) = [];
            %             macroRawFiles = cellfun(@(x)regexprep(x,'\_\d{4}',''),macroRawFiles,'uniformoutput',0);
            
            
            %The code block below has been moved to
            %getFileRegionCorrespondence, but I'm leaving it here for now
            %in case it makes more sense to have it here...
            %
            if ischar(obj.experiment)
                macroRawFiles = dir(fullfile(obj.experiment,'*.ncs'));
                toKeep = cellfun(@(x)strcmp(x(1),'R')|strcmp(x(1),'L'),{macroRawFiles.name});
                macroRawFiles = macroRawFiles(toKeep);
                macroRawFiles = {macroRawFiles.name};
            else
                thisExp = getExperimentInfo(obj.subject,obj.experiment);
                brainRegions = thisExp.montagePos;
                brainRegions(cellfun(@(x)isempty(x),brainRegions)) = [];
                macroRawFiles = cellfun(@(x)[arrayfun(@(y)sprintf('%s%d.ncs',x,y),1:8,'uniformoutput',0)],brainRegions,'uniformoutput',0);
                macroRawFiles = cat(2,macroRawFiles{:});
            end

            fullNames = arrayfun(@(x)sprintf('%s%d_%s.mat',obj.macroFilePrefix,x,...
                regexp(macroRawFiles{x},'[A-Z]*\d','match','once')),1:length(macroRawFiles),'uniformoutput',0);
            simpleNames = arrayfun(@(x)sprintf('%s%d.mat',obj.macroFilePrefix,x),1:length(macroRawFiles),'uniformoutput',0);
            alreadyExists = logical(cellfun(@(x)exist(fullfile(obj.linkToConvertedData,x),'file'),fullNames));
            alreadyExists_simple = logical(cellfun(@(x)exist(fullfile(obj.linkToConvertedData,x),'file'),simpleNames));
            if sum(alreadyExists_simple)>sum(alreadyExists)
                fileNames = simpleNames;
            else
                fileNames = fullNames;
            end
%             obj.filenameRegionCorrespondence = [fileNames;fullNames];
            
            % Now unpack macros in each location
            
            doPre = ~isempty(obj.preData); doPost = ~isempty(obj.postData);
%             obj.getFileRegionCorrespondence
            obj = unpackMacros(obj, obj.linkToConvertedData,obj.linkToMacroRawData,fileNames,macroRawFiles);
            if doPre
                obj = unpackMacros(obj, obj.preData.linkToConverted,obj.preData.linkToMacroRawData,fileNames,macroRawFiles);
            end
            if doPost
                obj = unpackMacros(obj, obj.postData.linkToConverted,obj.postData.linkToMacroRawData,fileNames,macroRawFiles);
            end
        end
        
        function obj = unpackMacros(obj, linkToConvertedData,linkToMacroRawData,fileNames,rawFileNames)
            if strcmp(obj.macroFilePrefix,'MACRO')
            alreadyConverted = logical(cellfun(@(x)exist(fullfile(linkToConvertedData,x),'file'),fileNames));
            fileNames(alreadyConverted) = [];
            rawFileNames(alreadyConverted) = [];
            
            if ~isempty(fileNames)
                needsTS = ~exist(fullfile(linkToConvertedData,'lfpTimeStampsMACRO.mat'),'file');
                macroRawFiles = dir(fullfile(linkToMacroRawData,'*.ncs'));
                macroRawFiles = {macroRawFiles.name};
                suffix = regexp(macroRawFiles{1},'\_\d{4}\.ncs','match','once');
%                 if ~isempty(suffix)
%                     macroRawFiles = cellfun(@(x)strrep(x,'.ncs',suffix),rawFileNames,'uniformoutput',0);
%                 else
                    macroRawFiles = rawFileNames;
%                 end
                rawExists = logical(cellfun(@(x)exist(fullfile(linkToMacroRawData,x),'file'),macroRawFiles));
                macroRawFiles = macroRawFiles(rawExists);
                fileNames = fileNames(rawExists);
                if ~isempty(macroRawFiles)
                    [time0,timeend] = unpackAMacro(obj,1,needsTS,fileNames,macroRawFiles,linkToMacroRawData,linkToConvertedData);
                    for f = 2:length(fileNames)
                        unpackAMacro(obj,f,0,fileNames,macroRawFiles,linkToMacroRawData,linkToConvertedData,time0,timeend);
                    end
                end
            end
            else
                % Unpack BR Macros
               warning('Uh oh, this isn''t written for BR macros. If you''re here, it means it''s time to fix that.')
               keyboard
                
            end
        end
        
        
        function obj = chooseScoringChannels(obj,skipPlotting);
            if ~exist('skipPlotting','var') || isempty(skipPlotting)
                skipPlotting = exist(fullfile(obj.saveDir,'Per Channel Hypnograms'),'dir');
            end
            if ~skipPlotting
                plotHypnogramsPerChannel(obj,1);
            end
            
            goodToGo = 0;
            while ~goodToGo
            channelsToUse = inputdlg('Which channel(s) should be used for sleep scoring? (If more than one, please enter inside brackets)',...
                'ChannelSelection');
            try
            obj.bestScoringChannels = eval(channelsToUse{1});
            goodToGo = 1;
            catch exception
                fprintf('The string you entered:\n%s\nwas not able to be evaluated. Please try again.\n')
            end
            end
            
            if size(obj.filenameRegionCorrespondence,1)<5 || isempty(obj.filenameRegionCorrespondence{5,1})
                obj.filenameRegionCorrespondence(5,:) = cellfun(@(x)regexp(x,'\w*','match','once'),obj.filenameRegionCorrespondence(3,:),'uniformoutput',0);
            end
            if isnumeric(obj.bestScoringChannels),
                inds = ismember(cell2mat(obj.filenameRegionCorrespondence(4,:)),obj.bestScoringChannels);
                obj.bestScoringChannelNames = obj.filenameRegionCorrespondence(5,inds);
            else
                inds = ismember(obj.filenameRegionCorrespondence(5,:),obj.bestScoringChannels);
                if ~any(inds)
                    inds = ismember(obj.filenameRegionCorrespondence(2,:),obj.bestScoringChannels);
                end
                obj.bestScoringChannelNames = obj.filenameRegionCorrespondence(5,inds);
                if ~isempty(obj.filenameRegionCorrespondence{4,1})
                obj.bestScoringChannels = cell2mat(obj.filenameRegionCorrespondence(4,inds));
                else
                    obj.bestScoringChannels = find(inds);
                end
            end

            obj.saveSelf;
        end
        
        function obj = evaluateDelta(obj)
            channels = obj.bestScoringChannels;
            obj.REMthresh = zeros(1,length(channels));
            obj.NREMthresh = zeros(1,length(channels));
            
            for c = 1:length(channels)
                ch = channels(c);
                needToDoThisChannel = isempty(obj.spectralData) || length(obj.spectralData)<c ||  obj.spectralData(c).channel ~= ch;
                if needToDoThisChannel
                    d = dir(fullfile(obj.linkToConvertedData,sprintf('%s%d*',obj.macroFilePrefix,ch)));
                    filename = {fullfile(obj.linkToConvertedData,d(1).name)};
                    sleepSess = 1;
                    if ~isempty(obj.preData)
                        d = dir(fullfile(obj.preData.linkToConverted,sprintf('%s%d*',obj.macroFilePrefix,ch)));
                        thisFile = fullfile(obj.preData.linkToConverted,d(1).name);
                        filename = [{thisFile},filename];
                        sleepSess = 2;
                    end
                    if ~isempty(obj.postData)
                        d = dir(fullfile(obj.postData.linkToConverted,sprintf('%s%d*',obj.macroFilePrefix,ch)));
                        thisFile = fullfile(obj.postData.linkToConverted,d(1).name);
                        filename = [filename,{thisFile}];
                    end
                    
                for fil = 1:length(filename)
                    temp = load(filename{fil},'data');
                    if fil==1
                        data = double(temp.data);
                        sess = ones(size(temp.data));
                    else
                        data = [data,double(temp.data)];
                        sess = [sess,fil*ones(size(temp.data))];
                    end
                end
                data(isnan(data)) = 0;
                
                
                
                % compute spectrogram
                window = obj.scoringEpochDuration*obj.samplingRate;
                [S,F,T,P]  = spectrogram(data,window,0,0.5:0.2:obj.flimits(2),obj.samplingRate,'yaxis');
                startSleepInd = find(sess==sleepSess,1,'first');
                endSleepInd = find(sess==sleepSess,1,'last');
                startSleepIndShort = max(round(startSleepInd/length(sess)*size(P,2)),1);
                endSleepIndShort = min(size(P,2),round(endSleepInd/length(sess)*size(P,2)));
                obj.sleepRange = [startSleepInd endSleepInd; startSleepIndShort endSleepIndShort];
                %                 [Ssl,Fsl,Tsl,Psl]  = spectrogram(data(sess==sleepSess),window,0,0.5:0.2:obj.flimits(2),obj.samplingRate,'yaxis');
                
                
                %                 crr = xcorr2(P,Psl);
                %                 M = max(max(crr));
                %                 test = crr == M;
                %                 ind = find(sum(test))
                
                
                P2 = P/max(max(P));
                P2 = (10*log10(abs(P2+obj.scaling_factor_delta_log)))';
                P2 = [P2(:,2) P2 P2(:,end)];
                
                diffSamples = obj.minDistBetweenEvents/diff(T(1:2)); %samples
                
                % Find delta Power
                relevantIndices = F > obj.deltaRangeMin & F < obj.deltaRangeMax;
                P_delta = Smooth(sum(P(relevantIndices,:)),7);
                
                % Define threholds for SWS and REM
                thSleepInclusion = prctile(P_delta,obj.NREMprctile);
                thREMInclusion = prctile(P_delta,obj.REMprctile);
                obj.REMthresh(c) = thREMInclusion;
                obj.NREMthresh(c) = thSleepInclusion;
                
                %find points which pass the peak threshold
                pointsPassedSleepThresh = P_delta > thSleepInclusion;
                pointsPassedREMThresh = P_delta < thREMInclusion;
                
                % Find Spindle Power
                relevantSpIndices = F > obj.spRangeMin & F < obj.spRangeMax;
                P_sp = Smooth(sum(P(relevantSpIndices,:)),5);
                
                % Prep Figure
                figure_name_out = sprintf('sleepScore_process_Channel%d',ch);
                figure('Name', figure_name_out,'NumberTitle','off');
                set(gcf,'PaperUnits','centimeters','PaperPosition',[0.2 0.2 25 35]); % this size is the maximal to fit on an A4 paper when printing to PDF
                set(gcf,'PaperOrientation','portrait');
                set(gcf,'Units','centimeters','Position', get(gcf,'paperPosition')+[1 1 0 0]);
                colormap('jet');
                set(gcf,'DefaultAxesFontSize',14);
                axes('position',[0.1,0.5,0.8,0.3])
                
                % Plot Spectrogram. Delta Power, Spindle Power, and Thresholds
                ah1 = imagesc(T,F,P2',[-40,-5]);axis xy;
                hold on
                fitToWin1 = 30/max(P_delta);
                fitToWin2 = 30/max(P_sp);
                plot(T,P_delta*fitToWin1,'k-','linewidth',1)
                plot(T,P_sp*fitToWin2-min(P_sp)*fitToWin2,'-','linewidth',1,'color',[0.8,0.8,0.8])
                line(get(gca,'xlim'),thSleepInclusion*fitToWin1*ones(1,2),'color','k','linewidth',3)
                line(get(gca,'xlim'),thREMInclusion*fitToWin1*ones(1,2),'color','k','linewidth',3)
                legend('P delta','P spindle','TH1','TH2')
                
                xlabel('ms')
                ylabel('F(Hz)')
                XLIM = get(gca,'xlim');
                YLIM = get(gca,'xlim');
                text(XLIM(2)+diff(XLIM)/35,thSleepInclusion*fitToWin1,'NREM TH')
                text(XLIM(2)+diff(XLIM)/35,thREMInclusion*fitToWin1,'REM TH')
                
                %% Compare threshold-based sleep-scoring to a data-driven cluster approach
                
                if c == 1 || ~exist('Svec','var')
                    Svec = zeros(length(channels),length(P_delta));
                end
                D1 = [P_delta(:), P_sp(:)];
                gm = fitgmdist(D1,2);
                P = posterior(gm,D1);
                C1 = P(:,1)>P(:,2);
                C2 = P(:,2)>P(:,1);
                
                if gm.mu(1) > gm.mu(2)
                    Svec(c,C1) = 1;
                else
                    Svec(c,C2) = 1;
                end
                
                hold on
                plot(T(pointsPassedSleepThresh),25,'.','markersize',8,'color','w')
                plot(T(logical(Svec(c,:))),20,'.','markersize',8,'color','r')
                
                plot(T(obj.sleepRange(2,1))*[1 1],F([1 end]),'color',.75*[1 1 1],'linewidth',4)
                plot(T(obj.sleepRange(2,2))*[1 1],F([1 end]),'color',.75*[1 1 1],'linewidth',4)
                plot(T(obj.sleepRange(2,1))*[1 1],F([1 end]),'y','linewidth',2)
                plot(T(obj.sleepRange(2,2))*[1 1],F([1 end]),'y','linewidth',2)
                
                
                legend('P delta','P spindle','TH1','TH2','Clustering Results','Thresh Results')
                title(sprintf('white - based on delta TH, red - based on  delta+spindle clust, diff = %2.2f%%',...
                    sum(pointsPassedSleepThresh - Svec(c,:)')/length(Svec)))
                
                export_fig(gcf,fullfile(obj.saveDir,[figure_name_out,'.pdf']))
                
                %% Create sleepScoreVector, which indicates which data points are SWS and REM
                if c == 1
                    sleepScoreVectorByChannel = zeros(length(channels),length(data));
                    sleepScoreVectorClusterByChannel = sleepScoreVectorByChannel;
                end
                
                % One pass for SWS, one pass for REM, one pass for
                % SWS with cluster method
                for ii_a = 1:3
                    switch ii_a
                        case 1
                            data_merge = pointsPassedSleepThresh;
                        case 2
                            data_merge = pointsPassedREMThresh;
                        case 3
                            data_merge = Svec(c,:);
                    end
                    
                    % Find events
                    events = continuousRunsOfTrue(data_merge');
                    EventsMinLimit = events(:,1);
                    EventsMaxLimit = events(:,2);
                    currDuration = (EventsMaxLimit-EventsMinLimit)/obj.samplingRate;
                    
                    % if there's less than a minute between REM/NREM points, merge them (this is
                    % inline with AASM guidlines)
                    
                    eventDiffs = EventsMinLimit(2:end)-EventsMaxLimit(1:end-1);
                    short_intervals = find(eventDiffs'<=(diffSamples));
                    
                    % Set the value of the intervening intervals to 1
                    for iii = 1:length(short_intervals)
                        index = short_intervals(iii);
                        data_merge(EventsMaxLimit(index):EventsMinLimit(index+1)) = 1;
                    end
                    
                    
                    
                    % Find events again and remove standalone detections
                    events = continuousRunsOfTrue(data_merge');
                    eventSamples = events(:,2)-events(:,1);
                    eventsToRemove = events(eventSamples<3,:);
                    for i = 1:size(eventsToRemove,1)
                        data_merge(eventsToRemove(i,1):eventsToRemove(i,2)) = 0;
                    end
                    
                    
                    if ii_a == 1
                        pointsPassedSleepThresh = data_merge;
                    elseif ii_a == 2
                        pointsPassedREMThresh = data_merge;
                    elseif ii_a == 3
                        SWSbyCluster = data_merge;
                    end
                    
                end
                
                % Extrapolate the 30-second epochs to the size of the fully sampled
                % data file:
                
                sleepScoreVectorByChannel(c,1:T(1)*obj.samplingRate) = pointsPassedSleepThresh(1)*obj.REM_CODE + pointsPassedREMThresh(1)*obj.NREM_CODE;
                for iEpoch = 2:length(T)
                    sleepScoreVectorByChannel(c,T(iEpoch-1)*obj.samplingRate+1:T(iEpoch)*obj.samplingRate) = ...
                        pointsPassedSleepThresh(iEpoch)*obj.NREM_CODE + pointsPassedREMThresh(iEpoch)*obj.REM_CODE;
                end
                
                sleepScoreVectorClusterByChannel(c,1:T(1)*obj.samplingRate) = SWSbyCluster(1)*obj.NREM_CODE;
                for iEpoch = 2:length(T)
                    sleepScoreVectorClusterByChannel(c,T(iEpoch-1)*obj.samplingRate+1:T(iEpoch)*obj.samplingRate) = ...
                        SWSbyCluster(iEpoch)*obj.NREM_CODE;
                end
                
                % Make spectral data struct
                spData = struct('channel',ch,'time',T,'freq',F,'spectralPower',P2,'deltaPower',P_delta,'spindlePower',P_sp);
                if isempty(obj.spectralData)
                    obj.spectralData = struct('channel',[],'time',[],'freq',[],'spectralPower',[],'deltaPower',[],'spindlePower',[]);
                end
                obj.spectralData(c) = spData;
                
                
                % Save everything per channel
                
                sleep_score_vec = sleepScoreVectorByChannel(c,:);
                sleep_score_vec_cluster = sleepScoreVectorClusterByChannel(c,:);
                obj.sleepScoreVectorByChannel(c,:) = sleep_score_vec;
                obj.sleepScoreVectorClusterByChannel(c,:) = sleep_score_vec_cluster;
                
                if c==1 || ~exist('dataFromSleepSession','var')
                    dataFromSleepSession = sess == sleepSess;
                obj.sleepInds = dataFromSleepSession;
                end
                save(fullfile(obj.saveDir,sprintf('sleepScore_Ch%d',ch)),...
                    'T','F','P2','sleep_score_vec','obj','P_delta','pointsPassedSleepThresh',...
                    'pointsPassedREMThresh','thSleepInclusion','thREMInclusion','SWSbyCluster',...
                    'sleep_score_vec_cluster','dataFromSleepSession','-v7.3')
                
                %% Make another fig...
                if obj.PLOT_FIG
                    
                    figure_name_out = sprintf('sleepScore_Ch%d',ch);
                    % re-compute spectrogram for prettier plots
                    [S2,F2,T2,P2]  = spectrogram(data,window,0.8*window,[0.5:0.2:obj.flimits(2)],obj.samplingRate,'yaxis');
                    spectrogram(data,window,0,[0.5:0.2:obj.flimits(2)],obj.samplingRate,'yaxis');
                    
                    P2 = P2/max(max(P2));
                    P1 = (10*log10(abs(P2+obj.scaling_factor_delta_log)))';
                    P1 = [P1(:,1) P1 P1(:,end)];
                    T2 = [0 T2 T2(end)+1];
                    Pplot = P1';% imgaussfilt(P1',3);
                    
                    % we have extra time points in T2, so need
                    % pointsPassed*Threshold to be upsampled
                    
                    pps2 = interp1(T,double(pointsPassedSleepThresh),T2);
                    ind = find(~isnan(pps2),1);
                    pps2(1:ind-1) = pps2(ind);
                    ind = find(~isnan(pps2),1,'last');
                    pps2(ind+1:end) = pps2(ind);
                    pps2 = logical(round(pps2));
                    
                    ppr2 = interp1(T,double(pointsPassedREMThresh),T2);
                    ind = find(~isnan(ppr2),1);
                    ppr2(1:ind-1) = ppr2(ind);
                    ind = find(~isnan(ppr2),1,'last');
                    ppr2(ind+1:end) = ppr2(ind);
                    ppr2 = logical(round(ppr2));
                    
                    plotSpectrogramAndSpectra(obj,F2,T2,P1,data,figure_name_out,sleep_score_vec,pps2,ppr2)
                    
                end
                end
            end
            
            % save obj
            obj.saveSelf;
        end
        
        
        function obj = manuallyValidateSleepScoring(obj)
            
                regions = obj.bestScoringChannelNames';
            % setup figure
            f = figure('Name',sprintf('Sleep Scoring Validation: Subject %d, Exp %d',obj.subject,obj.experiment),...
                'units','normalized','windowstyle','docked');%'position',[.5,.1,.45,.85]);
            colormap('jet'); set(f,'DefaultAxesFontSize',14);
            nPlots = length(obj.bestScoringChannels)+1;
            pv = makePosVecFunction(nPlots,1,.05,0,.05);
            ax = arrayfun(@(x)axes('parent',f,'units','normalized','position',pv(1,1,x,1)),1:nPlots,'uniformoutput',0);
            hold(ax{end},'on')
            col = spring(nPlots-1);
            % Plot spectrograms, delta power and current sleep score
            
            
            for c = 1:nPlots-1
                hold(ax{c},'on')
                ch = obj.bestScoringChannels(c);
                thisData = load(fullfile(obj.saveDir,sprintf('sleepScore_Ch%d.mat',ch)));
                byChannelData(c) = thisData;
                colormap(ax{c},'jet'); set(ax{c},'clim',[-40 5],'ydir','normal');
                imagesc(thisData.T,thisData.F,thisData.P2','parent',ax{c});
                title(ax{c},sprintf('Channel %d (%s)',ch,regions{c}));
                plot(ax{c},thisData.T(logical(thisData.pointsPassedSleepThresh)),20,'.r','markersize',obj.markerSize)
                plot(ax{c},thisData.T(logical(thisData.pointsPassedREMThresh)),18,'.k','markersize',obj.markerSize)
                plot(ax{c},thisData.T(logical(thisData.SWSbyCluster)),22,'.w','markersize',obj.markerSize)
                plot(ax{c},thisData.T(obj.sleepRange(2,1))*[1 1],thisData.F([1 end]),'color',.75*[1 1 1],'linewidth',4)
                plot(ax{c},thisData.T(obj.sleepRange(2,2))*[1 1],thisData.F([1 end]),'color',.75*[1 1 1],'linewidth',4)
                plot(ax{c},thisData.T(obj.sleepRange(2,1))*[1 1],thisData.F([1 end]),'y','linewidth',2)
                plot(ax{c},thisData.T(obj.sleepRange(2,2))*[1 1],thisData.F([1 end]),'y','linewidth',2)
                plot(ax{end},thisData.T,thisData.P_delta/max(thisData.P_delta),'color',col(c,:),'linewidth',2)
                plot(ax{end},thisData.T([1,length(thisData.T)]),thisData.thSleepInclusion/max(thisData.P_delta)*[1 1],'--','color',col(c,:),'linewidth',1)
                plot(ax{end},thisData.T([1,length(thisData.T)]),thisData.thREMInclusion/max(thisData.P_delta)*[1 1],':','color',col(c,:),'linewidth',1)
                if c==1
                    sleepThreshCrossings = zeros(nPlots-1,length(thisData.pointsPassedSleepThresh));
                    remThreshCrossings = zeros(nPlots-1,length(thisData.pointsPassedSleepThresh));
                    clusteredSleepPoints = zeros(nPlots-1,length(thisData.pointsPassedSleepThresh));
                end
                sleepThreshCrossings(c,:) = thisData.pointsPassedSleepThresh;
                remThreshCrossings(c,:) = thisData.pointsPassedREMThresh;
                clusteredSleepPoints(c,:) = thisData.SWSbyCluster;
            end

            
            yLim = get(ax{end},'ylim');
            col = winter(nPlots);
            
            nSleep = sum(sleepThreshCrossings,1)+1;
            nSleepCol = col(nSleep,:);
            nREM = sum(remThreshCrossings)+1;
            nREMCol = col(nREM,:);
            
            scatter(ax{end},thisData.T,repmat(mean(yLim),size(thisData.T)),15,nSleepCol,'filled');
            scatter(ax{end},thisData.T,repmat(mean(yLim)/2,size(thisData.T)),15,nREMCol);
            linkaxes([ax{:}],'x')
            xlim([ax{1}],[thisData.T(1),thisData.T(end)])
            
            % collect mean/aggregate data
            % Note (6/29/2023): All the cat(1...'s in this chunk were
            % cat(2,...'s before. But it was causing an error. Not sure why
            % it used to work with dim 2 and now works with dim 1. But if
            % you run into weird problems again, maybe changing back to 2
            % will be better for a different dataset.????
            meanP2 = cat(3,{byChannelData.P2});
            meanP1 = mean(cat(3,meanP2{:}),3);
            meanP_delta = cat(1,{byChannelData.P_delta});
            meanP_delta = mean(cat(1,meanP_delta{:}),1);
            anyPointsPassedSleep = cat(1,{byChannelData.pointsPassedSleepThresh});
            anyPointsPassedSleep = any(cat(1,anyPointsPassedSleep{:}),1);
            anyPointsPassedREM = cat(1,{byChannelData.pointsPassedREMThresh});
            anyPointsPassedREM = any(cat(1,anyPointsPassedREM{:}),1);
            
            % Ask for user input:
            answer = input('Please enter your name\n','s');
            manualResults.name = answer;
            manualResults.datestamp = datestr(now,'yyyy-mm-dd,HH:MM');
            manualResults.regionsModifiedByHand = [];
            
            sleep_score_vec = zeros(1,size(obj.sleepScoreVectorByChannel,2));
            sleep_score_vec(any(obj.sleepScoreVectorByChannel==obj.REM_CODE)) = obj.REM_CODE;
            sleep_score_vec(any(obj.sleepScoreVectorByChannel==obj.NREM_CODE)) = obj.NREM_CODE;
            
            for s = 1:2
                switch s
                    case 1
                        sleepType = 'REM';
                        code = obj.REM_CODE;
                    case 2
                        sleepType = 'NREM';
                        code = obj.NREM_CODE;
                end
                
                answer = input(sprintf('add a new %s session?(Y/N)', sleepType),'s');
                while strcmpi(answer,'Y')
                    [x,y] = ginput(2);
                    x(x<0) = 0; x(x>thisData.T(end)) = thisData.T(end); x = sort(x);
                    l1 = cellfun(@(AX)line(x(1)*ones(1,2),yLim,'color','r','parent',AX),ax,'uniformoutput',0);
                    l2 = cellfun(@(AX)line(x(2)*ones(1,2),yLim,'color','g','parent',AX),ax,'uniformoutput',0);
                    
                    answer = input(sprintf('mark between lines as %s ?(Y/N)',sleepType),'s');
                    if strcmpi(answer,'Y')
                        [~, ind1] = min( abs(thisData.T-x(1)));
                        [~, ind2] = min( abs(thisData.T-x(2)));
                        if s == 1 % Add REM
                            anyPointsPassedREM(ind1:ind2) = code;
                            anyPointsPassedSleep(ind1:ind2) = 0;
                        else % Add NREM
                            anyPointsPassedSleep(ind1:ind2) = code;
                            anyPointsPassedREM(ind1:ind2) = 0;
                        end
                        sleep_score_vec(max(floor(x(1)*obj.samplingRate),1):min(floor(x(2)*obj.samplingRate),length(sleep_score_vec))) = code;
                        plot(ax{end},thisData.T(ind1:ind2),repmat(mean(yLim),1,ind2-ind1+1),'ro');
                        manualResults.regionsModifiedByHand(end+1,:) = [floor(x(1)*obj.samplingRate), floor(x(2)*obj.samplingRate) code];
                    end
                    cellfun(@(x)delete(x),[l1 l2]);
                    answer = input(sprintf('add an additonal new %s session?(Y/N)',sleepType),'s');
                end
                
                answer = input(sprintf('Mark %s eopch as not %s?(Y/N)',sleepType,sleepType),'s');
                while strcmpi(answer,'Y')
                    [x,y] = ginput(2);
                    x(x<0) = 0; x(x>thisData.T(end)) = thisData.T(end); x = sort(x);
                    l1 = cellfun(@(AX)line(x(1)*ones(1,2),yLim,'color','r','parent',AX),ax,'uniformoutput',0);
                    l2 = cellfun(@(AX)line(x(2)*ones(1,2),yLim,'color','g','parent',AX),ax,'uniformoutput',0);
                    
                    answer = input(sprintf('Remove %s designation between lines ?(Y/N)',sleepType),'s');
                    if strcmpi(answer,'Y')
                        [~, ind1] = min( abs(thisData.T-x(1)));
                        [~, ind2] = min( abs(thisData.T-x(2)));
                        anyPointsPassedSleep(ind1:ind2) = 0;
                        anyPointsPassedREM(ind1:ind2) = 0;
                        sleep_score_vec(max(floor(x(1)*obj.samplingRate),1):min(floor(x(2)*obj.samplingRate),length(sleep_score_vec))) = 0;
                        plot(ax{end},thisData.T(ind1:ind2),repmat(mean(yLim),1,ind2-ind1+1),'wo');
                        manualResults.regionsModifiedByHand(end+1,:) = [floor(x(1)*obj.samplingRate), floor(x(2)*obj.samplingRate) 0];
                    end
                    cellfun(@(x)delete(x),[l1 l2]);
                    answer = input(sprintf('Delete an additonal %s section?(Y/N)',sleepType),'s');
                end
                
            end
            
            
            manualResults.finalSleepScoreVector = sleep_score_vec(obj.sleepRange(1,1):obj.sleepRange(1,2));
            if isempty(obj.manualResults)
                obj.manualResults = manualResults;
            else
                obj.manualResults = [obj.manualResults manualResults];
            end
            saveSelf(obj);
            
            % Make plots of final
            figure_name_out = sprintf('Manually Validated Sleep Scoring_%s',strrep(obj.saveName,'SleepScoringObj_',''));
            
            channels = obj.bestScoringChannels;
            for c = 1:length(channels)
                ch = channels(c);
                filename = dir(fullfile(obj.linkToConvertedData,sprintf('%s%d.*',obj.macroFilePrefix,ch)));
                if isempty(filename)
                    filename = dir(fullfile(obj.linkToConvertedData,sprintf('%s%d_*',obj.macroFilePrefix,ch)));
                end
                filename = fullfile(obj.linkToConvertedData,filename.name);
                data = load(filename,'data');
                if c==1
                    allData = zeros(length(channels),length(data.data));
                end
                allData(c,:) = data.data;
            end
            
            plotSpectrogramAndSpectra(obj,byChannelData(1).F,...
                byChannelData(1).T(obj.sleepRange(2,1):obj.sleepRange(2,2)),...
                meanP1(obj.sleepRange(2,1):obj.sleepRange(2,2),:),allData,...
                figure_name_out,sleep_score_vec(obj.sleepRange(1,1):obj.sleepRange(1,2)),...
                anyPointsPassedSleep(obj.sleepRange(2,1):obj.sleepRange(2,2)),...
                anyPointsPassedREM(obj.sleepRange(2,1):obj.sleepRange(2,2)))
        end
        
        %% help functions
        function obj = removeFromBestChannelsList(obj,indsToRemove)
            obj.bestScoringChannels(indsToRemove) = [];
            obj.sleepScoreVectorByChannel(indsToRemove,:) = [];
            obj.NREMthresh(indsToRemove) = [];
            obj.REMthresh(indsToRemove) = [];
        end
        
        function [f,psdx] = getPS(obj,segment)
            %a helper method to calculate the power spectrum of a segment
            
            segLength = length(segment);
            xdft = fft(segment);
            xdft = xdft(1:segLength/2+1);
            psdx = (1/(obj.samplingRate*segLength)) * abs(xdft).^2;
            psdx(2:end-1) = 2*psdx(2:end-1);
            psdx = 10*log10(psdx);
            
        end
        
        function [f, pow] = hereFFT (obj, signal)
            % Calculate the fft of the signal, with the given sampling rate, make
            % normalization(AUC=1). Return frequencies and respective powers.
            
            % Matlab source code of FFT
            Y = fft(signal);
            power_spec = Y.* conj(Y) / length(signal);
            
            % keep only half of the power spectrum array (second half is irrelevant)
            amp = power_spec(1:ceil(length(power_spec)/2)) ;
            
            % Define the frequencies relevant for the left powers, and cut for same
            % number of values (for each frequency - a power value)
            f = obj.samplingRate*(1:length(amp))/(length(amp)*2);
            pow = amp(1:length(f));
            
            %----- End of Regular fft -----
            
            pow = pow / sum (pow);   % normalize AUC
            
        end
        
        function BP = bandpass(obj, timecourse, SamplingRate, low_cut, high_cut, filterOrder)
            
            %bandpass code - from Maya
            
            if (nargin < 6)
                filterOrder = obj.defaultFilterOrder;
            end
            
            % Maya GS - handle NAN values
            indices = find(isnan(timecourse));
            if length(indices) > obj.nanWarning*length(timecourse)
                warning('many NaN values in filtered signal')
            end
            timecourse(indices) = 0;
            %
            
            [b, a] = butter(filterOrder, [(low_cut/SamplingRate)*2 (high_cut/SamplingRate)*2]);
            BP = filtfilt(b, a, timecourse );
            BP(indices) = NaN;
        end
        
        function regions = plotHypnogramsPerChannel(obj,saveFigs)
            
            if ~exist('saveFigs','var') || isempty(saveFigs)
                saveFigs = 1;
            end
            
            if isempty(obj.filenameRegionCorrespondence)
                switch (obj.macroFilePrefix)
                    case 'MACRO',
                        obj.getFileRegionCorrespondence('Nlx');
                    case 'MACROBR',
                        obj.getFileRegionCorrespondence('BR');
                end
            end
            macroFiles = obj.filenameRegionCorrespondence(1,:);
            
            
            nFigs = ceil(size(obj.filenameRegionCorrespondence,2)/24);
            f = arrayfun(@(x)figure('units','normalized','position',[.2 .3 .6 .6]),1:nFigs,'uniformoutput',0);
            ax = cellfun(@(x)arrayfun(@(m)subplot2(3,8,m,[],'borderPct',.025,'parent',x),1:24,'uniformoutput',0),f,'uniformoutput',0);
            
            for m = 1:length(macroFiles)
                if mod(m,24)==1
                    fprintf('\n')
                end
                fprintf('.')
                thisAx = ax{ceil(m/24)}{modUp(m,24)};
                plotHypnogram(fullfile(obj.linkToConvertedData,macroFiles{m}),...
                    thisAx,obj.startTime,obj.endTime);
                title(thisAx,obj.filenameRegionCorrespondence{2,m},'interpreter','none'); % should be third row but it's not defined right now and I just need this to plot
            end
            %%
            if saveFigs
                saveDir = fullfile(obj.saveDir,'Per Channel Hypnograms');
                if ~exist(saveDir)
                    mkdir(saveDir);
                end
                for i = 1:length(f)
                    export_fig(fullfile(saveDir,sprintf('Hypnograms Fig %d.pdf',i)),f{i})
                end
            end
        end
        
        function plotSpectrogramAndSpectra(obj,F,T,P1,data,figure_name_out,sleep_score_vec,pointsPassedSleepThresh,pointsPassedREMThresh)
            % prep fig
            
            f = figure('Name', figure_name_out,'NumberTitle','off');
            set(gcf,'PaperUnits','centimeters','PaperPosition',[0.2 0.2 21 30]); % this size is the maximal to fit on an A4 paper when printing to PDF
            set(gcf,'PaperOrientation','portrait');
            set(gcf,'Units','centimeters','Position', get(gcf,'paperPosition')+[1 1 0 0]);
            colormap('jet');
            set(gcf,'DefaultAxesFontSize',14);
            pv = makePosVecFunction(2,size(data,1),.075,.075,.04);
            ax = axes('parent',f,'units','normalized','position',pv(1,size(data,1),1,1),...
                'clim',[-40,-5],'ydir','normal');
            
            
            
            
            start_time = datenum(obj.startTime,'yyyy/mm/dd HH:MM:SS');
            end_time = datenum(obj.endTime,'yyyy/mm/dd HH:MM:SS');
            xData = linspace(start_time,end_time,length(P1));
            
            % plot spectrogram
            imagesc(xData,F,P1','parent',ax)
            axis([get(ax,'xlim'),[0.5,20]])
            set(ax,'ytick',[0.5,10,20])
            datetick('x','HH:MM PM','keeplimits')
            
            % Add annotation for sleep stage
            hold on
            xData2 = linspace(start_time,end_time,length(T));
            if sum(pointsPassedSleepThresh)>0
                plot(ax,xData2(logical(pointsPassedSleepThresh)),20,'.r','markersize',obj.markerSize)
            end
            if sum(pointsPassedREMThresh)>0
                plot(ax,xData2(logical(pointsPassedREMThresh)),18,'.k','markersize',obj.markerSize)
            end
            set(ax,'ydir','normal')
            % finish plot
            yticks = obj.flimits(1):5:obj.flimits(2);
            colorbar
            title_str = sprintf('Sleep scoring - NREM (red), Wake/REM (black)');
            axis([get(ax,'xlim'),[0.5,30]])
            set(ax,'ytick',[0.5,10,20,30])
            YLIM = get(ax,'ylim');
            xlabel('t (hh:mm)')
            ylabel('f (Hz)')
            title(title_str)
            
            % New plot(s) for spectra of different sleep stages
            for ch = 1:size(data,1)
                ax = axes('parent',f,'units','normalized','position',pv(ch,1,2,1));
                sleepRangeVec = zeros(1,length(sleep_score_vec));
                startInd = find(sleep_score_vec == obj.NREM_CODE,1,'first');
                endInd = find(sleep_score_vec == obj.NREM_CODE,1,'last');
                sleepRangeVec(startInd:endInd) = 1;
                
                % compute and plot spectra
                legendText = {};
                for ii_a = 1:3
                    if ii_a == 1
                        a_data =  data(ch,sleep_score_vec == obj.NREM_CODE);
                        legendText{end+1} = 'SWS';
                        col = 'b';
                    elseif ii_a == 2
                        a_data =  data(ch,sleep_score_vec == obj.REM_CODE);
                        legendText{end+1} = 'REM*';
                        col = 'g';
                    elseif ii_a == 3
                        a_data =  data(ch,~sleepRangeVec);
                        legendText{end+1} = 'Wake/Transition*';
                        col = .5*[1 1 1];
                    end
                    
                    if ~isempty(a_data)
                        
                        a_data = a_data - mean(a_data);
                        freq = 0:obj.samplingRate/2;
                        WIN = min(500,length(a_data));
                        NOVERLAP = min(400,WIN/2);
                        [pxx1, f1] = pwelch(a_data,WIN,NOVERLAP,freq,obj.samplingRate);
                        
                        hold(ax,'on')
                        plot(ax,f1,10*log10(pxx1),'color',col,'linewidth',2)

                    else
                        legendText(end) = [];
                    end
                end
                
                % finish plot
                axis(ax,[0 25,0,inf])
                xlabel(ax,'f(Hz)')
                ylabel(ax,'dB')
                legend(ax,legendText)
                title(ax,sprintf('power spectra (%s)',obj.bestScoringChannelNames{ch}))
            end
            
            pv2 = makePosVecFunction(2,1,0,0,.05);
            panel = uipanel('parent',f,'units','normalized','position',pv2(1.65,.23,.2,.18),'BackgroundColor','w');
            ax2 = axes('parent',panel,'units','normalized','position',pv2(1,1,2,2));
            if isempty(endInd)
                text(0,0.7,'sleep length = 0 h','parent',ax2)
            else
                text(0,0.7,sprintf('sleep length = %2.2fh',(endInd-startInd)/obj.samplingRate/60/60),'parent',ax2)
                text(0,0.5,sprintf('NREM = %2.2f%%',100*sum(sleep_score_vec == obj.NREM_CODE)/(endInd-startInd)),'parent',ax2)
                text(0,0.3,sprintf('REM = ~%2.2f%%',100*sum(sleep_score_vec == obj.REM_CODE)/(endInd-startInd)),'parent',ax2)
            end
            axis(ax2,'off')
            
            % Save Fig
            export_fig(f,fullfile(obj.saveDir,[figure_name_out,'.pdf']))
        end
        
        function saveSelf(obj,createNew)
            if exist('createNew','var') && createNew
                obj.saveName = ['sleepScoringObj_',datestr(now,'yyyy_mm_dd-HH_MM')];
            end
            obj.saveDir = cleanPathForThisSystem(obj.saveDir);
            if ~exist(obj.saveDir,'dir')
                mkdir(obj.saveDir);
            end
            save(fullfile(obj.saveDir,obj.saveName),'-v7.3')
        end
        
        function saveAsData(obj)
            fn = fieldnames(obj);
            str = struct();
            for i = 1:length(fn)
                str.(fn{i}) = obj.(fn{i});
            end
            saveAsName = strrep(obj.saveName,'Obj','Data');
            save(fullfile(obj.saveDir,saveAsName),'-struct','str','-v7.3');
        end
        
        function obj = cleanObjPaths(obj)
            obj.saveDir = cleanPathForThisSystem(obj.saveDir);
            obj.linkToConvertedData = cleanPathForThisSystem(obj.linkToConvertedData);
            obj.linkToMacroRawData = cleanPathForThisSystem(obj.linkToMacroRawData);
        end
        
        function [time0, timeend] = unpackAMacro(obj,f,needsTS,newNames,macroRawFiles,sourceLocation,destLocation,time0,timeend)
            if exist(fullfile(sourceLocation,macroRawFiles{f}),'file')
            if f==1 && needsTS
                computeTS = 1;
            else
                computeTS = 0;
            end
            disp(['Processing ',newNames{f}])
            [data,timeStamps,samplingInterval,chNum] = ...
                Nlx_readCSC(fullfile(sourceLocation,macroRawFiles{f}),computeTS);
            data = reshape(data,1,[]);
            if ~exist('time0','var')
                time0 = timeStamps(1);
                timeend = timeStamps(end);
            end
            
            save(fullfile(destLocation,newNames{f}),...
                'data','samplingInterval','time0','timeend','-v7.3');
            
            if computeTS
                save(fullfile(destLocation,'lfpTimeStampsMACRO.mat'),...
                    'timeStamps','time0','timeend','-v7.3');
            end
            else
                fprintf('No raw macro file: %s',macroRawFiles{f});
            end
        end
        
    end % methods
    
    
end % classdef