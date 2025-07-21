function F15_analyseAnglesMaster_doublePositive
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Perform circular statistical analysis on cell angle data.
%
% The Excel file "double_pos_angles_master.xlsx" is expected to have the following columns:
%   1. mouseID
%   2. Genotype
%   3. SpinalCordSectionID
%   4. Population (e.g., 'ChAT_GAD67', etc.)
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
    % Start diary
    diary(fullfile(pwd,'double_pos_angle_analysis_results.txt'));

    % Read master table
    fname = 'double_pos_angles_master.xlsx';
    T = readtable(fname);
    if width(T) < 7
        error('Expected at least 7 columns in %s', fname);
    end

    % Convert transformed angles to radians
    ang_rad = deg2rad(T{:,7});

    % Unique genotypes and populations
    genotypes   = unique(T.Genotype);
    populations = unique(T.Population);

    % Create modified labels: replace "_" → "⁺–", then append a trailing "⁺"
    modPopulations = regexprep(populations, '_', '⁺-');
    modPopulations = strcat(modPopulations, '⁺');

    % Prepare stats containers
    G = {};
    P = {};
    N = [];
    Cmean = [];
    Cvar  = [];
    RayP  = [];

    % 1) Compute circular stats
    for i = 1:numel(genotypes)
        for j = 1:numel(populations)
            mask = strcmp(T.Genotype, genotypes{i}) & strcmp(T.Population, populations{j});
            a = ang_rad(mask);
            n = numel(a);
            if n>0
                m = circ_mean(a);
                v = circ_var(a);
                [pval, ~] = circ_rtest(a);
            else
                m = NaN; v = NaN; pval = NaN;
            end
            G{end+1,1} = genotypes{i};
            P{end+1,1} = populations{j};
            N(end+1,1) = n;
            md = rad2deg(m);
            if md<0, md = md+360; end
            Cmean(end+1,1) = md;
            Cvar(end+1,1)  = v;
            RayP(end+1,1)  = pval;
        end
    end

    % Display summary table
    statsTbl = table(G, P, N, Cmean, Cvar, RayP, ...
        'VariableNames', {'Genotype','Population','NCells','CircMean_deg','CircVar','RayleighP'});
    disp(statsTbl);

    % 2) Rose diagrams
    fig = figure('Units','normalized','Position',[0 0 1 1]);
    binE = 0:deg2rad(1):2*pi;
    % Compute max percent per population
    maxPct = zeros(numel(populations),1);
    for j = 1:numel(populations)
        a_all = ang_rad(strcmp(T.Population, populations{j}));
        if ~isempty(a_all)
            a_all = mod(2*pi - a_all, 2*pi);
            pct = histcounts(a_all, binE, 'Normalization','percent');
            maxPct(j) = max(pct);
        end
    end

    for i = 1:numel(genotypes)
        for j = 1:numel(populations)
            idx = strcmp(T.Genotype, genotypes{i}) & strcmp(T.Population, populations{j});
            a = ang_rad(idx);
            a = mod(2*pi - a, 2*pi);
            subplot(numel(genotypes), numel(populations), (i-1)*numel(populations)+j);
            if ~isempty(a)
                polarhistogram(a, binE, 'Normalization','percent');
                pax = gca;
                pax.ThetaDir = 'counterclockwise';
                pax.ThetaZeroLocation = 'right';
                pax.RLim = [0 maxPct(j)*1.05];
                title({ genotypes{i}, modPopulations{j}, sprintf('N=%d', numel(a)) });
            else
                title({ genotypes{i}, modPopulations{j}, '(no data)' });
            end
        end
    end
    print(fig, fullfile(pwd,'double_pos_polar_histograms.svg'),'-dsvg','-vector');
    close(fig);

    % 3) Nonparametric common-median test (circ_cmtest)
    fprintf('\n=== Common-median Test by Population ===\n');
    for j = 1:numel(populations)
        a_all = ang_rad(strcmp(T.Population, populations{j}));
        geno = T.Genotype(strcmp(T.Population, populations{j}));
        % numeric group labels
        grp = zeros(size(a_all));
        for g=1:numel(genotypes)
            grp(strcmp(geno, genotypes{g})) = g;
        end
        if numel(a_all)>0
            [p_cm, estMed, Pstat] = circ_cmtest(a_all, grp);
            fprintf('%s: Pstat=%g, estMedian(rad)=%g, p=%g\n', modPopulations{j}, Pstat, estMed, p_cm);
        end
    end

    % 4) Pairwise Kuiper tests w/ permutation
    alpha = 0.05;
    fprintf('\n=== Pairwise Kuiper Tests by Population ===\n');
    for j = 1:numel(populations)
        fprintf('\nPopulation: %s\n', populations{j});
        a_all = ang_rad(strcmp(T.Population, populations{j}));
        geno = T.Genotype(strcmp(T.Population, populations{j}));
        % group labels
        grp = zeros(size(a_all));
        for g=1:numel(genotypes)
            grp(strcmp(geno, genotypes{g})) = g;
        end
        pairPs = [];
        for g1 = 1:numel(genotypes)
            for g2 = g1+1:numel(genotypes)
                s1 = a_all(grp==g1);
                s2 = a_all(grp==g2);
                if isempty(s1) || isempty(s2), continue; end
                pval = simulate_kuiper_test(s1, s2, 1000);
                pairPs(end+1,:) = [pval, g1, g2]; %#ok<AGROW>
                fprintf('  %s vs %s: p=%g\n', genotypes{g1}, genotypes{g2}, pval);
            end
        end
        % FDR correction
        if ~isempty(pairPs)
            ps = pairPs(:,1);
            [ps_sorted, idxs] = sort(ps);
            m = numel(ps);
            thresholds = (1:m)'/m*alpha;
            sig = find(ps_sorted < thresholds, 1, 'last');
            if ~isempty(sig)
                fprintf('  Significant after FDR:\n');
                for s=1:sig
                    row = pairPs(idxs(s),2:3);
                    fprintf('    %s vs %s (p=%g)\n', ...
                        genotypes{row(1)}, genotypes{row(2)}, ps_sorted(s));
                end
            else
                fprintf('  No significant pairwise differences after FDR.\n');
            end
        end
    end

    diary off;
end

%% Helper: Monte Carlo Kuiper test
function pval = simulate_kuiper_test(s1, s2, nSim)
    if nargin<3, nSim=1000; end
    Vobs = compute_kuiper_statistic(s1, s2);
    combined = [s1; s2];
    n1 = numel(s1);
    count = 0;
    for k=1:nSim
        perm = randperm(numel(combined));
        if compute_kuiper_statistic(combined(perm(1:n1)), combined(perm(n1+1:end))) >= Vobs
            count = count + 1;
        end
    end
    pval = count/nSim;
end

%% Helper: Compute Kuiper statistic
function V = compute_kuiper_statistic(s1, s2)
    shift = min([s1; s2]);
    u1 = mod(s1-shift,2*pi);
    u2 = mod(s2-shift,2*pi);
    allx = sort([u1; u2]);
    n1 = numel(u1); n2 = numel(u2);
    diffCDF = arrayfun(@(x) sum(u1<=x)/n1 - sum(u2<=x)/n2, allx);
    V = max(diffCDF) - min(diffCDF);
end
