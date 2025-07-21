function F18_plotMeanCIangle
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% 5×1 figure: mean angle ±95% CI for each cell population;
% for GAD-67⁺, wrap >180° to negative.

%%
    genotypes = {'Dync1h1^{+/+}','Dync1h1^{–/+}','Dync1h1^{+/Loa}','Dync1h1^{–/Loa}'};
    colors    = lines(4);
    z975      = 1.96;

    %— HARD‐CODED DATA -----------------------------------------------------
    meanDegs = { ...
       [339.08;332.20;336.25;335.81], ...   % ChAT⁺ all cells
       [ 21.50; 28.18; 24.64; 24.34], ...   % ChAT⁺ interneurons
       [  5.19;358.72;  4.94;  4.74], ...   % GAD-67⁺ cells
       [ 20.42; 30.72; 26.96; 26.88], ...   % ChAT⁺–GAD-67⁺ cells
       [ 14.07; 18.28; 16.07; 15.41] };     % Parvalbumin⁺–GAD-67⁺ cells

    V = { ...
       [0.1790;0.1323;0.1361;0.1303], ...
       [0.1710;0.1271;0.1290;0.1226], ...
       [0.2472;0.2462;0.2433;0.2508], ...
       [0.1675;0.1294;0.1124;0.1226], ...
       [0.2141;0.2049;0.1872;0.1867] };

    nC = { ...
       [1700;1338;1399;999], ...
       [1521;1164;1244;908], ...
       [6032;5132;5290;4122], ...
       [598;388;501;303], ...
       [2311;1682;1972;1448] };

    names = { ...
      'ChAT⁺ (all cells)', ...
      'ChAT⁺ interneurons', ...
      'GAD-67⁺ cells', ...
      'ChAT⁺–GAD-67⁺ cells', ...
      'Parvalbumin⁺–GAD-67⁺ cells' };
    %— end DATA ------------------------------------------------------------

    fig = figure('Units','normalized','Position',[0 0 1 1]);
    N = numel(meanDegs);

    for k = 1:N
        muDeg   = meanDegs{k};
        varC    = V{k};
        n       = nC{k};
        titleTxt= names{k};

        % compute 95% CI from circular variance V and n
        R       = 1 - varC;
        SE_rad  = sqrt((1 - R) ./ (n .* R));  % SE in radians
        CI_rad  = z975 * SE_rad;              % ± radians
        CI_deg  = rad2deg(CI_rad);            % ± degrees

        ax = subplot(N,1,k);
        hold(ax,'on');
        y = 1:4;

        if k == 3
            % GAD-67⁺: wrap >180° into negative domain
            dispDeg = muDeg;
            idxHigh = dispDeg > 180;
            dispDeg(idxHigh) = dispDeg(idxHigh) - 360;

            % symmetric tick span
            spanNeg = min(dispDeg - CI_deg);
            spanPos = max(dispDeg + CI_deg);
            maxSpan = max(abs(spanNeg), abs(spanPos));
            tickRange = ceil(maxSpan/5)*5;      % round up to nearest 5°
            ticks     = linspace(-tickRange, tickRange, 5);
            xlim(ax, [-tickRange, tickRange]);

            % label map back to 0–360°
            tickLabels = arrayfun(@(v)sprintf('%d°',mod(round(v),360)), ticks, 'Uni',false);
            set(ax, 'XTick', ticks, 'XTickLabel', tickLabels);
        else
            % auto x-limits
            xlim(ax, [min(muDeg-CI_deg)-2, max(muDeg+CI_deg)+2]);
            % append ° to default ticks
            xt = get(ax,'XTick');
            xtl = arrayfun(@(v)sprintf('%g°',v), xt, 'Uni',false);
            set(ax,'XTick',xt,'XTickLabel',xtl);
        end

        % plot each genotype in its color
        for i = 1:4
            xi = (k==3 && muDeg(i)>180) * -360 + muDeg(i);
            errorbar(ax, xi, y(i), CI_deg(i), CI_deg(i), ...
                'horizontal','o', ...
                'Color', colors(i,:), ...
                'MarkerFaceColor', colors(i,:), ...
                'MarkerEdgeColor','k', ...
                'LineWidth',2, ...
                'MarkerSize',6);
        end

        set(ax, 'YTick',1:4, 'YTickLabel', genotypes, 'YDir','reverse', 'FontSize', 14);
        xlabel(ax, 'Mean angle');
        title(ax, titleTxt, 'Interpreter','none');
        grid(ax,'on');
    end

    print(fig, fullfile(pwd,'Mean_CI_angles_sig_only.svg'),'-dsvg','-vector');
    close(fig);
end
