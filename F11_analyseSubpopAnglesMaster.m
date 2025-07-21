function F11_analyseSubpopAnglesMaster
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Perform circular statistical analysis on ChAT⁺ interneuron and motor‐neuron populations.
%
% The Excel file "ChAT_subpopulation_angles_master.xlsx" is expected to have the following columns:
%   1. mouseID
%   2. Genotype
%   3. SpinalCordSectionID
%   4. Subpopulation (e.g., 'interneurons', etc.)
%   5. CellNumber
%   6. Angle (in -180 to 180 degrees)
%   7. Angle_transformed (in 0 - 360 degrees)
%
% For each genotype × subpopulation combination it computes:
%   - The number of cells (n)
%   - The circular mean transformed angle (converted back to degrees)
%   - The circular variance
%   - The p-value from the Rayleigh test (to assess uniformity)
%
% It then displays these results in a table and generates rose diagrams for each group.

%%

% Start capturing the output printed to the command window.
diary(fullfile(pwd, 'ChAT_subpopulation_angle_analysis_results.txt'));

% --- Read master table ---
fname = 'ChAT_subpopulation_angles_master.xlsx';
if ~isfile(fname)
    error('File "%s" not found in current folder.', fname);
end
T = readtable(fname);

% Check required columns
req = {'Genotype','Subpopulation','Angle_transformed'};
assert(all(ismember(req, T.Properties.VariableNames)), ...
    'Missing one of required columns: %s', strjoin(req,', '));

% Convert transformed angles to radians
angles = deg2rad(T.Angle_transformed);

% Unique genotypes and subpopulations
genotypes = unique(T.Genotype);
subpops   = unique(T.Subpopulation);

% Create human‐friendly display names for each subpopulation
dispSubpops = cell(size(subpops));
for j = 1:numel(subpops)
    switch subpops{j}
        case 'interneurons'
            dispSubpops{j} = 'Interneurons';
        case 'motorNeurons'
            dispSubpops{j} = 'Motor Neurons';
        otherwise
            % fallback: split camelCase into words & capitalize first letter
            s = subpops{j};
            s = regexprep(s, '([a-z])([A-Z])', '$1 $2');
            dispSubpops{j} = [upper(s(1)), s(2:end)];
    end
end

% Prepare results
G = {};
S = {};
N = [];
meanDeg = [];
varCirc = [];
rayP = [];

% Compute stats per genotype × subpopulation
for i = 1:numel(genotypes)
    for j = 1:numel(subpops)
        mask = strcmp(T.Genotype, genotypes{i}) & ...
               strcmp(T.Subpopulation, subpops{j});
        a = angles(mask);
        nCells = numel(a);
        if nCells>0
            m = circ_mean(a);
            v = circ_var(a);
            p = circ_rtest(a);
            mDeg = mod(rad2deg(m),360);
        else
            mDeg = NaN; v = NaN; p = NaN;
        end
        G{end+1,1} = genotypes{i};
        S{end+1,1} = dispSubpops{j};
        N(end+1,1) = nCells;
        meanDeg(end+1,1) = mDeg;
        varCirc(end+1,1) = v;
        rayP(end+1,1)    = p;
    end
end

% Display summary table
statsTbl = table(G, S, N, meanDeg, varCirc, rayP, ...
    'VariableNames', {'Genotype','Subpopulation','NCells', ...
                      'CircMean_deg','CircVar','RayleighP'});
disp(statsTbl);

% --- Plot rose diagrams (polar histograms) for each genotype×subpop ---
fig = figure('Units','normalized','Position',[0 0 1 1]);
binEdges = 0:deg2rad(1):2*pi;   % 1° bins

% Precompute max counts per subpopulation
maxCountBySub = zeros(numel(subpops),1);
for j = 1:numel(subpops)
    allA = angles(strcmp(T.Subpopulation, subpops{j}));
    if ~isempty(allA)
        allA = mod(2*pi - allA, 2*pi);
        cnt = histcounts(allA, binEdges);
        maxCountBySub(j) = max(cnt);
    end
end

nRows = numel(genotypes);
nCols = numel(subpops);
for i = 1:nRows
    for j = 1:nCols
        idx = strcmp(T.Genotype, genotypes{i}) & strcmp(T.Subpopulation, subpops{j});
        angles_plot = angles(idx);
        nObs = numel(angles_plot);

        angles_plot = mod(2*pi - angles_plot, 2*pi);

        subplot(nRows, nCols, (i-1)*nCols + j);
        if ~isempty(angles_plot)
            polarhistogram(angles_plot, binEdges, ...
                'FaceColor','b','EdgeColor','k','Normalization','percent');
            pax = gca;
            pax.ThetaDir = 'counterclockwise';
            pax.ThetaZeroLocation = 'right';
            % adjust radius limit by percent
            allP = histcounts(mod(2*pi - angles(strcmp(T.Subpopulation,subpops{j})),2*pi), ...
                              binEdges,'Normalization','percent');
            pax.RLim = [0 max(allP)*1.1];
            title({ genotypes{i}, ...
                    sprintf('%s (N=%d)', dispSubpops{j}, nObs) });
        else
            polaraxes;
            pax = gca;
            pax.ThetaDir = 'counterclockwise';
            pax.ThetaZeroLocation = 'right';
            pax.RLim = [0 maxCountBySub(j)];
            title({ genotypes{i}, sprintf('%s (no data)', dispSubpops{j}) });
        end
    end
end

print(fig, fullfile(pwd,'Polar_histograms_ChAT_subpopulations.svg'), '-dsvg','-vector');
close(fig);

% --- Nonparametric median test per subpopulation ---
for j = 1:numel(subpops)
    fprintf('\nSubpopulation: %s\n', dispSubpops{j});
    mask = strcmp(T.Subpopulation, subpops{j});
    a = angles(mask);
    labels = T.Genotype(mask);
    grp = zeros(size(a));
    for g = 1:numel(genotypes)
        grp(strcmp(labels, genotypes{g})) = g;
    end
    [p_med, Pstat] = circ_cmtest(a, grp);
    fprintf('  circ_cmtest: Pstat=%g, p=%g\n', Pstat, p_med);
end

% --- Pairwise Kuiper tests with FDR ---
alpha = 0.05;
for j = 1:numel(subpops)
    fprintf('\nSubpopulation: %s (pairwise)\n', dispSubpops{j});
    mask = strcmp(T.Subpopulation, subpops{j});
    aAll = angles(mask);
    labels = T.Genotype(mask);
    groups = unique(labels);
    pvals = [];
    combos = {};
    for g1 = 1:numel(groups)
        for g2 = g1+1:numel(groups)
            a1 = aAll(strcmp(labels, groups{g1}));
            a2 = aAll(strcmp(labels, groups{g2}));
            p = simulate_kuiper_test(a1, a2, 1000);
            pvals(end+1,1) = p;
            combos{end+1,1} = sprintf('%s vs %s',groups{g1},groups{g2});
            fprintf('  %s: p=%g\n', combos{end}, p);
        end
    end
    adj_p = mafdr(pvals, 'BHFDR', true);
    sig = adj_p < alpha;
    if any(sig)
        fprintf('  Significant after FDR:\n');
        for k = find(sig)'
            fprintf('    %s (adj p=%g)\n', combos{k}, adj_p(k));
        end
    else
        fprintf('  No significant pairwise differences after FDR.\n');
    end
end

fprintf('\nAnalysis complete.\n');
diary off;
end

%% Nested helper: simulate_kuiper_test
function pval = simulate_kuiper_test(s1, s2, nSim)
    if nargin<3, nSim=1000; end
    Vobs = compute_kuiper_statistic(s1,s2);
    comb = [s1; s2];
    n1 = numel(s1);
    cnt = 0;
    for k=1:nSim
        p = randperm(numel(comb));
        v = compute_kuiper_statistic(comb(p(1:n1)), comb(p(n1+1:end)));
        if v>=Vobs, cnt=cnt+1; end
    end
    pval = cnt/nSim;
end

function V = compute_kuiper_statistic(s1,s2)
    shift = min([s1; s2]);
    s1 = mod(s1-shift,2*pi);
    s2 = mod(s2-shift,2*pi);
    allPts = sort([s1; s2]);
    n1 = numel(s1); n2 = numel(s2);
    dCDF = arrayfun(@(x) sum(s1<=x)/n1 - sum(s2<=x)/n2, allPts);
    V = max(dCDF) + abs(min(dCDF));
end