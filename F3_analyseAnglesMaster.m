function F3_analyseAnglesMaster
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Perform circular statistical analysis on cell angle data.
%
% The Excel file "angles_master.xlsx" is expected to have the following columns:
%   1. mouseID
%   2. Genotype
%   3. SpinalCordSectionID
%   4. Channel (e.g., 'ch00_MAX', etc.)
%   5. CellNumber
%   6. Angle (in -180 to 180 degrees)
%   7. Angle_transformed (in 0 - 360 degrees)
%
% The function computes, for each genotype and channel combination:
%   - The number of cells (n)
%   - The circular mean transformed angle (converted back to degrees)
%   - The circular variance
%   - The p-value from the Rayleigh test (to assess uniformity)
%
% It then displays these results in a table and generates rose diagrams for each group.

%%

% Start capturing the output printed to the command window.
diary(fullfile(pwd, 'angle_analysis_results.txt'));

% Read the Excel file into a table.
filename = 'angles_master.xlsx';
T = readtable(filename);

% Check that the table has at least 7 columns.
if width(T) < 7
    error('The Excel file must have at least 7 columns as specified.');
end

% Extract the angle data (assumed to be in column 7) and convert to radians.
angles_all = deg2rad(T{:,7});

% Get unique genotypes and channels.
genotypes = unique(T.Genotype);
channels = unique(T.Channel);

% Prepare arrays for output statistics.
genotypeList = {};
channelList = {};
nCells = [];
circMean_deg = [];
circVar = [];
rayleighP = [];

% Loop over each genotype and channel combination.
for i = 1:length(genotypes)
    for j = 1:length(channels)
        % Subset data for the current genotype and channel.
        idx = strcmp(T.Genotype, genotypes{i}) & strcmp(T.Channel, channels{j});
        angles_subset = angles_all(idx);
        n = numel(angles_subset);
        if n > 0
            % Compute circular statistics using Circular Statistics Toolbox functions.
            m = circ_mean(angles_subset);
            v = circ_var(angles_subset);
            [p_val, ~] = circ_rtest(angles_subset);
        else
            m = NaN;
            v = NaN;
            p_val = NaN;
        end
        
        % Append results.
        genotypeList{end+1,1} = genotypes{i};
        channelList{end+1,1} = channels{j};
        nCells(end+1,1) = n;
        mean_deg = rad2deg(m);
        if mean_deg < 0
            mean_deg = mean_deg + 360; % convert radians to degrees.
        end
        circMean_deg(end+1,1) = mean_deg;
        circVar(end+1,1) = v;
        rayleighP(end+1,1) = p_val;
    end
end

% Create and display a summary table.
statsTable = table(genotypeList, channelList, nCells, circMean_deg, circVar, rayleighP, ...
    'VariableNames', {'Genotype', 'Channel', 'NCells', 'CircMean_deg', 'CircVar', 'RayleighP'});
disp(statsTable);

% --- Plot rose diagrams (polar histograms) for each genotype-channel combination. ---
fig = figure('Units','normalized','Position',[0 0 1 1]);
binEdges = 0:deg2rad(1):2*pi;  % 1° bins

% 1) Pre-compute maximum percent (not count) for each channel
maxPercentByChannel = zeros(length(channels),1);
for j = 1:length(channels)
    allA = angles_all(strcmp(T.Channel, channels{j}));
    if ~isempty(allA)
        allA = mod(2*pi - allA, 2*pi);  % mirror for orientation
        pct = histcounts(allA, binEdges, 'Normalization','percent');
        maxPercentByChannel(j) = max(pct);
    end
end

nRows = length(genotypes);
nCols = length(channels);
for i = 1:nRows
    for j = 1:nCols
        idx = strcmp(T.Genotype, genotypes{i}) & strcmp(T.Channel, channels{j});
        a = angles_all(idx);
        n_obs = numel(a);
        
        % mirror for image-coordinate orientation
        a = mod(2*pi - a, 2*pi);
        
        subplot(nRows, nCols, (i-1)*nCols + j);
        if ~isempty(a)
            h = polarhistogram(a, binEdges, ...
                'FaceColor','b','EdgeColor','k','Normalization','percent');
            pax = gca;
            pax.ThetaDir = 'counterclockwise';
            pax.ThetaZeroLocation = 'right';
            % 2) Use max percent, not max count
            pax.RLim = [0 maxPercentByChannel(j)*1.05];  % +5% headroom
            
            % marker name
            switch channels{j}
                case 'ch00_MAX', marker = 'ChAT';
                case 'ch01_MAX', marker = 'Calbindin';
                case 'ch02_MAX', marker = 'GAD-67';
                otherwise        marker = 'Parvalbumin';
            end
            title({genotypes{i}, marker, sprintf('N = %d cells',n_obs)});
        else
            title({genotypes{i}, [channels{j} ' (no data)']});
        end
    end
end

print(fig, fullfile(pwd,'Polar_histograms.svg'),'-dsvg','-vector');
close(fig);

% Non parametric multi-sample test for equal medians (for circular data).
% Similar to a Kruskal-Wallis test for linear data.
channels = unique(T.Channel);  % Get the unique channels.
genotypes = unique(T.Genotype);  % Get the unique genotypes.

for c = 1:length(channels)
    if strcmp(channels{c}, 'ch00_MAX')
        marker = 'ChAT';
    elseif strcmp(channels{c}, 'ch01_MAX')
        marker = 'Calbindin';
    elseif strcmp(channels{c}, 'ch02_MAX')
        marker = 'GAD-67';
    else
        marker = 'Parvalbumin';
    end
    fprintf('\nMarker: %s\n', marker);
    
    % Subset angles & labels
    channelIdx    = strcmp(T.Channel, channels{c});
    angles_channel = angles_all(channelIdx);
    genotypeLabels = T.Genotype(channelIdx);
    
    % Numeric grouping
    groupLabels = zeros(size(angles_channel));
    for g = 1:length(genotypes)
        groupLabels(strcmp(genotypeLabels, genotypes{g})) = g;
    end

    % Capture all outputs from circ_cmtest:
    %   pVal      = p–value
    %   estMedian = estimated common median (in radians)
    %   Pstat     = test statistic
    [pVal, estMedian, Pstat] = circ_cmtest(angles_channel, groupLabels);

    % Log both statistic & p-value to the diary:
    fprintf('Non-parametric median test (circ_cmtest):\n');
    fprintf('  Test statistic (P)    = %g\n', Pstat);
    fprintf('  Estimated median (rad)= %g\n', estMedian);
    fprintf('  p-value               = %g\n\n', pVal);
end



% Post-hoc pairwise comparisons for significant results (Kuiper test)
% The Kuiper test compares the entire distribution of angles between two 
% groups (two genotypes in this case). It is designed for circular data and
% is sensitive to differences in both location and spread.

alpha = 0.05; % Significance threshold
pairwise_pValues = [];

for c = 1:length(channels)
    % Determine marker for the current channel
    if strcmp(channels{c}, 'ch00_MAX')
        marker = 'ChAT';
    elseif strcmp(channels{c}, 'ch01_MAX')
        marker = 'Calbindin';
    elseif strcmp(channels{c}, 'ch02_MAX')
        marker = 'GAD-67';
    else
        marker = 'Parvalbumin';
    end

    fprintf('\nMarker: %s\n', marker);
    
    % Reinitialize pairwise_pValues for this marker to get separate stats per marker.
    pairwise_pValues = [];
    
    % Extract angles and genotype grouping
    channelIdx = strcmp(T.Channel, channels{c});
    angles_channel = angles_all(channelIdx);
    genotypeLabels = T.Genotype(channelIdx);
    
    % Numeric grouping
    groupLabels = zeros(size(angles_channel));
    for g = 1:length(genotypes)
        groupLabels(strcmp(genotypeLabels, genotypes{g})) = g;
    end
    
    % Pairwise comparisons
    pair_count = 0;
    for g1 = 1:length(genotypes)
        for g2 = g1+1:length(genotypes)
            % Extract angles for the two genotypes
            angles_g1 = angles_channel(groupLabels == g1);
            angles_g2 = angles_channel(groupLabels == g2);
            
            % Perform Kuiper test
            % pval = circ_kuipertest(angles_g1, angles_g2); % This is the original test, which gives warnings when n>200. It has been replaced with the line below.
            pval = simulate_kuiper_test(angles_g1, angles_g2, 1000);
            pair_count = pair_count + 1;
            
            % Store results
            pairwise_pValues = [pairwise_pValues; pval, g1, g2];
            
            fprintf('Pairwise Kuiper test p-value for %s vs %s: %f\n', ...
                genotypes{g1}, genotypes{g2}, pval);
        end
    end
    
    % Multiple comparisons correction (False Discovery Rate - Benjamini-Hochberg)
    if pair_count > 1
        p_sorted = sort(pairwise_pValues(:,1));  % Sort p-values
        m = length(p_sorted); % Number of tests
        q = 0.05; % Desired FDR level
        thresholds = (1:m)' / m * q; % Compute significance thresholds
        
        % Find last significant p-value
        sig_idx = find(p_sorted < thresholds, 1, 'last');
        
        if ~isempty(sig_idx)
            sig_p = p_sorted(1:sig_idx); % Significant p-values
            sig_pairs = pairwise_pValues(ismember(pairwise_pValues(:,1), sig_p), 2:3);
            
            fprintf('Significant pairwise comparisons after FDR correction:\n');
            for s = 1:size(sig_pairs,1)
                fprintf('%s vs %s (Adjusted p-value: %f)\n', ...
                    genotypes{sig_pairs(s,1)}, genotypes{sig_pairs(s,2)}, sig_p(s));
            end
        else
            fprintf('No significant pairwise differences after FDR correction.\n');
        end
    end
end

% Turn off diary to finish capturing output.
diary off;

end





%%
% The following nested functions  have been added as an alternative to using circ_kuipertest.
% The built-in circ_kuipertest relies on a lookup table of critical values that only supports 
% sample sizes up to 200. Since our data groups contain more than 200 cells, using 
% circ_kuipertest generates warnings and may lead to less accurate p-value estimations.
%
% The simulation-based approach implemented here uses a Monte Carlo permutation method.
% It calculates the observed Kuiper statistic for the two samples and then compares it against
% the distribution of Kuiper statistics generated by randomly reassigning the data to the two groups.
% This method adapts to larger sample sizes and provides more reliable p-values for our analysis.

function pval = simulate_kuiper_test(sample1, sample2, nSim)
    % simulate_kuiper_test - Compute a p-value for the two-sample Kuiper test 
    % using permutation (Monte Carlo simulation).
    %
    % Inputs:
    %   sample1 - vector of angles (in radians) for group 1 (assumed in [0, 2pi))
    %   sample2 - vector of angles (in radians) for group 2 (assumed in [0, 2pi))
    %   nSim    - number of simulations (e.g., 1000)
    %
    % Output:
    %   pval    - p-value computed as the proportion of simulated Kuiper
    %             statistics greater than or equal to the observed one.
    
    if nargin < 3
        nSim = 1000; % default number of simulations
    end
    
    % Compute observed Kuiper statistic.
    V_obs = compute_kuiper_statistic(sample1, sample2);
    
    % Combine the two samples.
    combined = [sample1; sample2];
    n1 = length(sample1);
    nTotal = length(combined);
    
    count = 0;
    for i = 1:nSim
        perm = randperm(nTotal);
        perm_sample1 = combined(perm(1:n1));
        perm_sample2 = combined(perm(n1+1:end));
        V_perm = compute_kuiper_statistic(perm_sample1, perm_sample2);
        if V_perm >= V_obs
            count = count + 1;
        end
    end
    
    pval = count / nSim;
end

function V = compute_kuiper_statistic(sample1, sample2)
    % compute_kuiper_statistic - Compute the Kuiper statistic for two samples.
    %
    % The Kuiper statistic is defined as V = Dplus + Dminus, where:
    %   Dplus  = max[ F1(x) - F2(x) ]
    %   Dminus = max[ F2(x) - F1(x) ]
    %
    % Here, F1 and F2 are the empirical cumulative distribution functions of
    % sample1 and sample2, respectively.
    %
    % To handle circular data, we first shift both samples so that the minimum
    % angle (from the combined data) becomes zero, then compute the statistic.
    
    % Shift the data to start at zero.
    shift = min([sample1; sample2]);
    s1 = mod(sample1 - shift, 2*pi);
    s2 = mod(sample2 - shift, 2*pi);
    
    % Combine the shifted samples and sort.
    combined = sort([s1; s2]);
    n1 = length(s1);
    n2 = length(s2);
    
    % Compute the difference between the empirical CDFs at each point.
    diffCDF = zeros(length(combined), 1);
    for i = 1:length(combined)
        diffCDF(i) = sum(s1 <= combined(i)) / n1 - sum(s2 <= combined(i)) / n2;
    end
    
    Dplus = max(diffCDF);
    Dminus = abs(min(diffCDF));
    V = Dplus + Dminus;
end
