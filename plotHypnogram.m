function Pplot = plotHypnogram(filename,ax,startTime,endTime)

params.lowCut = .5;
params.highCut = 30;
params.ds_SR = 200;

if ~exist('ax','var') || isempty(ax)
    figure; ax = gca;
end
colormap(ax,'jet')

% Get Data
if ~exist(filename,'file')
    warning('File %s does not exist.');
    return
end
data = load(filename);
sampInt = data.samplingInterval;
sampRate = 1/sampInt; % Already stored in kHz
data = data.data;
data(isnan(data)) = 0;

decimateFactor = sampRate*(1000/params.ds_SR);
data_ds = decimateBy(double(data),[],decimateFactor);

% Compute Spectrogram
scaling_factor_delta_log = 2*10^-4 ; % Additive Factor to be used when computing the Spectrogram on a log scale
window = 30*params.ds_SR;
flimits = [0 30];
[S,F,T,P]  = spectrogram(data_ds,window,0.8*window,[0.5:0.2:flimits(2)],params.ds_SR,'yaxis');
P = P/max(max(P));
P1 = (10*log10(abs(P+scaling_factor_delta_log)))';
% P1 = [P1(:,1) P1 P1(:,end)];
% T = [0 T T(end)+1];
if isempty(which('imgaussfilt'))
    Pplot = P1';
else
    Pplot = imgaussfilt(P1',3);
end

% Adjust time variable to real time, if start time and endtime are provided
if exist('startTime','var') && exist('endTime','var') && ...
        ~isempty(startTime) && ~isempty(endTime)
    hasTime = 1;
    if ~isnumeric(startTime)
        startTime = datenum(startTime,'yyyy/mm/dd HH:MM:SS');
        endTime = datenum(endTime,'yyyy/mm/dd HH:MM:SS');
    end
    xData = linspace(startTime,endTime,length(T));
else
    hasTime = 0;
    xData = T;
end

% Plot Spectrogram
imagesc(xData,F,Pplot,'parent',ax); caxis(ax,[-40,-5]);axis(ax,'xy');
if hasTime
    try
    datetick(ax,'x','HH:MM PM','keeplimits');
    catch
        set(ax,'xticklabel',datestr(get(ax,'xtick'),'HH:MM PM'));
    end
else
xlimits = [0 xData(end)];
xticks = xData(1):(60*60):xData(end);
for ii = 1:length(xticks)
    xlabel_str{ii} = num2str(floor((xticks(ii)/(60*60))));
end
xlabel('t (hr)')
end
yticks = 0:5:30;
% axis([xlimits flimits])
% set(gca,'xtick',xticks,'XTickLabel',xlabel_str)
% colorbar

ylabel(ax,'f (Hz)')

