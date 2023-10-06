function makePrettySleepScorePlot(obj,channelToPlot,cueTimes)
channels = obj.bestScoringChannels;
channelInd = find(ismember(channels,channelToPlot));


    ch = channels(channelInd);
    
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
    
    % load data from all sessions; sess indicates which
    % session it came from;
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

    
    P2 = P/max(max(P));
    P2 = (10*log10(abs(P2+obj.scaling_factor_delta_log)))';
    P2 = [P2(:,2) P2 P2(:,end)];
    
%     diffSamples = obj.minDistBetweenEvents/diff(T(1:2)); %samples
%     
%     % Find delta Power
%     relevantIndices = F > obj.deltaRangeMin & F < obj.deltaRangeMax;
%     P_delta = Smooth(sum(P(relevantIndices,:)),7);
%     
%     % Define threholds for SWS and REM
%     thSleepInclusion = prctile(P_delta,obj.NREMprctile);
%     thREMInclusion = prctile(P_delta,obj.REMprctile);
%     obj.REMthresh(c) = thREMInclusion;
%     obj.NREMthresh(c) = thSleepInclusion;
%     
%     %find points which pass the peak threshold
%     pointsPassedSleepThresh = P_delta > thSleepInclusion;
%     pointsPassedREMThresh = P_delta < thREMInclusion;
%     
%     % Find Spindle Power
%     relevantSpIndices = F > obj.spRangeMin & F < obj.spRangeMax;
%     P_sp = Smooth(sum(P(relevantSpIndices,:)),5);
    
    % Prep Figure
    figure_name_out = sprintf('sleepScore_Pt%d_Channel%d',obj.subject,ch);
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
%     fitToWin1 = 30/max(P_delta);
%     fitToWin2 = 30/max(P_sp);
    %                 plot(T,P_delta*fitToWin1,'k-','linewidth',1)
    %                 plot(T,P_sp*fitToWin2-min(P_sp)*fitToWin2,'-','linewidth',1,'color',[0.8,0.8,0.8])
    %                 line(get(gca,'xlim'),thSleepInclusion*fitToWin1*ones(1,2),'color','k','linewidth',3)
    %                 line(get(gca,'xlim'),thREMInclusion*fitToWin1*ones(1,2),'color','k','linewidth',3)
    %                 legend('P delta','P spindle','TH1','TH2')
    
    
    ylabel('F(Hz)')
%     XLIM = get(gca,'xlim');
%     YLIM = get(gca,'xlim');
    %                 text(XLIM(2)+diff(XLIM)/35,thSleepInclusion*fitToWin1,'NREM TH')
    %                 text(XLIM(2)+diff(XLIM)/35,thREMInclusion*fitToWin1,'REM TH')
    
    V = obj.manualResults.finalSleepScoreVector;
    Vranges = continuousRunsOfTrue(V);
    t = colonByLength(obj.sleepRange(1,1)/obj.samplingRate,1/obj.samplingRate,length(V));
    for v = 1:size(Vranges,1)
    plot(gca,t(Vranges(v,:)),22.5*[1 1],'linewidth',3,'color',[0.5608    0.0784    0.2392]);
    end
    rasterPlot(gca,cueTimes+obj.sleepRange(1,1)/obj.samplingRate,26,'linewidth',3,'color','m');


        plot(T(obj.sleepRange(2,1))*[1 1],F([1 end]),'color',.75*[1 1 1],'linewidth',4)
    plot(T(obj.sleepRange(2,2))*[1 1],F([1 end]),'color',.75*[1 1 1],'linewidth',4)
    plot(T(obj.sleepRange(2,1))*[1 1],F([1 end]),'y','linewidth',2)
    plot(T(obj.sleepRange(2,2))*[1 1],F([1 end]),'y','linewidth',2)
    
    nMinutes = length(data)/obj.samplingRate/60;
    xticks = 0:15:nMinutes;
    xticksAsString = arrayfun(@(x)sprintf('%d',x),xticks,'uniformoutput',0);
    xTicksInSec = xticks*60;
    set(gca,'xtick',xTicksInSec,'xticklabel',xticksAsString');
    xlabel('time (min)')
    
    saveDir = '/Users/emilymankin/HoffmanMount/data/PIPELINE_vc/ANALYSIS/SoundItemAssociation/wakeSleepWakeObjects/figsForPoster';
    export_fig(gcf,fullfile(saveDir,[figure_name_out,'.pdf']))
    return
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
    

    
    
    legend('P delta','P spindle','TH1','TH2','Clustering Results','Thresh Results')
    title(sprintf('white - based on delta TH, red - based on  delta+spindle clust, diff = %2.2f%%',...
        sum(pointsPassedSleepThresh - Svec(c,:)')/length(Svec)))
    
   