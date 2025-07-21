function F17_plotHeatmapAndPolar
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Plot all post-hoc-significant cell populations in a single figure with 5 rows × 2 columns:
%  • Left column: discrete p‐value heatmaps
%  • Right column: polar arrow plots of mean directions
%
% P‐value matrices and mean‐angle vectors are hardcoded.

%%
genotypes = {'+/+','–/+','+/Loa','–/Loa'};
alpha     = 0.05;

% 1) ChAT⁺ (all cells)
pMats{1} = [
   NaN,   0.000000,  0.000000,  0.000000;
   0.000000,  NaN,   0.000000,  0.000000;
   0.000000,  0.000000,  NaN,   0.171000;
   0.000000,  0.000000,  0.171000,  NaN
];
meanDegs{1} = [339.08; 332.2; 336.25; 335.81];
names{1}    = 'ChAT⁺ (all cells)';

% 2) ChAT⁺ interneurons
pMats{2} = [
   NaN,   0.000000,  0.000000,  0.000000;
   0.000000,  NaN,   0.000000,  0.000000;
   0.000000,  0.000000,  NaN,   0.070000;
   0.000000,  0.000000,  0.070000,  NaN
];
meanDegs{2} = [21.5; 28.18; 24.64; 24.34];
names{2}    = 'ChAT⁺ interneurons';

% 3) GAD-67⁺ cells
pMats{3} = [
   NaN,   0.000000,  0.000000,  0.000000;
   0.000000,  NaN,   0.000000,  0.033000;
   0.000000,  0.000000,  NaN,   0.000000;
   0.000000,  0.033000,  0.000000,  NaN
];
meanDegs{3} = [5.19; 358.72; 4.94; 4.74];
names{3}    = 'GAD-67⁺ cells';

% 4) ChAT⁺–GAD-67⁺ cells
pMats{4} = [
   NaN,   0.000000,  0.000000,  0.000000;
   0.000000,  NaN,   0.001000,  0.037000;
   0.000000,  0.001000,  NaN,   0.000000;
   0.000000,  0.037000,  0.000000,  NaN
];
meanDegs{4} = [20.42; 30.72; 26.96; 26.88];
names{4}    = 'ChAT⁺–GAD-67⁺ cells';

% 5) Parvalbumin⁺–GAD-67⁺ cells
pMats{5} = [
   NaN,   0.000000,  0.000000,  0.000000;
   0.000000,  NaN,   0.014000,  0.009000;
   0.000000,  0.014000,  NaN,   0.000000;
   0.000000,  0.009000,  0.000000,  NaN
];
meanDegs{5} = [14.07; 18.28; 16.07; 15.41];
names{5}    = 'Parvalbumin⁺–GAD-67⁺ cells';

% Discrete colormap for p‐levels:
cmap = [
  0.8 0.8 0.8;    % 0 = ns
  1.0 0.8 0.8;    % 1 = <0.05
  1.0 0.6 0.6;    % 2 = <0.01
  1.0 0.4 0.4;    % 3 = <0.001
  1.0 0.0 0.0     % 4 = <0.0001
];

% Create figure
fig = figure('Units','normalized','Position',[0 0 1 1]);

N = numel(pMats);
for k = 1:N
    pMat      = pMats{k};
    meanDeg   = meanDegs{k};
    groupName = names{k};

    % Map p-values → levels 0–4
    lvl = zeros(size(pMat));
    lvl(pMat < 0.05)    = 1;
    lvl(pMat < 0.01)    = 2;
    lvl(pMat < 0.001)   = 3;
    lvl(pMat < 0.0001)  = 4;

    %% Left: heatmap subplot
    ax1 = subplot(N,2,2*k-1);
    imagesc(ax1, lvl);
    colormap(ax1, cmap);
    clim(ax1, [0 4]);
    axis(ax1,'square');
    set(ax1, ...
        'XTick',1:4, 'XTickLabel',genotypes, ...
        'YTick',1:4, 'YTickLabel',genotypes, ...
        'TickLength',[0 0]);
    title(ax1, sprintf('%s', groupName), 'Interpreter','none');
    cb = colorbar(ax1, 'Ticks',0:4, ...
        'TickLabels',{'ns','<0.05','<0.01','<0.001','<0.0001'});
    cb.Label.String = 'p-value';

    %% Right: arrow‐only polar subplot
    ax2dum = subplot(N,2,2*k);
    pos = ax2dum.Position;
    delete(ax2dum);
    pax = polaraxes('Position',pos);
    hold(pax,'on');
    pax.ThetaZeroLocation = 'right';
    pax.ThetaDir          = 'counterclockwise';
    pax.RLim              = [0 1];

    cols = lines(4);
    for i = 1:4
        th = deg2rad(meanDeg(i));
        polarplot(pax, [th th], [0 1], 'LineWidth',2, 'Color',cols(i,:));
    end
    legend(pax, genotypes, 'Location','eastoutside');
    title(pax, sprintf('%s', groupName), 'Interpreter','none');
end

print(fig, fullfile(pwd,'Polar_histograms_sig_only.svg'),'-dsvg','-vector');
close(fig);
end