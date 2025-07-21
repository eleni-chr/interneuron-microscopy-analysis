function F8_createHeatmaps
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.
% 
% This function generates composite cell density heatmaps for each cell type by overlaying 
% registered cell mask images with their corresponding averaged gray matter masks. The 
% overlays are organised into a tiled layout where each row represents a lumbar level (e.g., L3, L4, ...)
% and each column represents a genotype. The function applies a fixed color scale (CLim set to [-0.5, 5.5]) together with a custom discrete colormap 
% containing 6 colors (corresponding to cell count values 0–5). A single common colorbar with integer 
% ticks is added to each figure.
%
% The function performs the following steps:
%   1. Prompts the user to select the folder containing registered cell masks. The parent folder 
%      is expected to also contain an "Average_Masks" folder holding the averaged gray matter masks, 
%      with filenames in the format "AverageMask_<genotype>_<lumbar>.tif".
%
%   2. Builds a group structure by parsing the average mask filenames to extract genotype and lumbar
%      level information; each group represents a unique combination of genotype and lumbar level.
%
%   3. Determines the unique lumbar levels and orders the genotypes according to a specified desired 
%      order, mapping the shorthand names to full labels.
%
%   4. For each cell type (corresponding to channels ch00 through ch03, which map to ChAT, 
%      Parvalbumin, GAD-67, and Calbindin), the function creates a maximised figure with a tiled 
%      layout. Each subplot corresponds to one group (specific genotype and lumbar level).
%
%   5. In every subplot:
%        - The corresponding averaged gray matter mask is loaded and used to create an overlay:
%          a truecolor black image is displayed with its AlphaData set from the average mask so that 
%          the gray matter appears as pure black (with varying opacity) while all areas outside appear 
%          transparent.
%        - Registered cell mask images for that group and cell type are loaded and summed (yielding 
%          integer cell count values), then masked to be shown only within the gray matter area.
%        - The resulting cell density heatmap is overlaid with a fixed transparency.
%
%   6. A fixed colour scale (CLim = [-0.5, 5.5]) and a custom colormap (with 6 discrete colours) are applied 
%      uniformly across all subplots, and a single common colorbar with integer tick labels (0–5) is added 
%      to the figure.
%
%   7. Each composite heatmap figure is titled with the full cell type name and saved as an SVG file in 
%      the parent folder.
%
% OUTPUT:
%   The function outputs composite overlay heatmap SVG files for each cell type, organised by 
%   lumbar level (rows) and genotype (columns).
%
% USAGE:
%   1. Run this function.
%   2. When prompted, select the folder containing registered cell mask images 
%      (the structure must follow the expected folder and filename conventions).
%   3. The function will process each group, generate the overlay heatmaps, and save the SVG files.
%
% NOTE:
%   This function assumes that:
%     - The "Registered_Cell_Masks" folder contains subfolders named with the pattern "<genotype>_<lumbar>" 
%       (e.g., "WT_L3").
%     - The parent folder contains an "Average_Masks" folder with average mask TIFFs named as
%       "AverageMask_<genotype>_<lumbar>.tif".
%     - Registered cell mask files are named with the channel information (e.g., "*_ch00_cell_registered.tif").

    %% Select Input Folders
    % Prompt for the Registered_Cell_Masks folder.
    regFolder = uigetdir(pwd, 'Select the Registered_Cell_Masks folder');
    if regFolder == 0
        error('No folder selected.');
    end
    % Parent folder should contain both Registered_Cell_Masks and Average_Masks.
    parentFolder = fileparts(regFolder);
    avgMaskFolder = fullfile(parentFolder, 'Average_Masks');
    if ~exist(avgMaskFolder, 'dir')
        error('Average_Masks folder not found in %s.', parentFolder);
    end

    %% Build the Group Data Structure from Average Mask Files
    % Assumes each average mask filename follows the pattern:
    % "AverageMask_<genotype>_<lumbar>.tif"
    avgMaskFiles = dir(fullfile(avgMaskFolder, 'AverageMask_*.tif'));
    if isempty(avgMaskFiles)
        error('No average mask files found in %s.', avgMaskFolder);
    end
    idxG = 0;
    groupData = struct('groupName','','genotype','','lumbar','','avgMaskFile','','regGroupFolder','');
    for i = 1:length(avgMaskFiles)
        [~, name, ~] = fileparts(avgMaskFiles(i).name);
        % Remove the "AverageMask_" prefix
        groupStr = name(length('AverageMask_')+1:end);
        parts = strsplit(groupStr, '_');
        if numel(parts) < 2
            warning('Skipping file %s; filename must be in format <genotype>_<lumbar>.', avgMaskFiles(i).name);
            continue;
        end
        idxG = idxG + 1;
        groupData(idxG).groupName = groupStr;
        groupData(idxG).genotype = parts{1};
        groupData(idxG).lumbar = parts{2};
        groupData(idxG).avgMaskFile = fullfile(avgMaskFolder, avgMaskFiles(i).name);
        groupData(idxG).regGroupFolder = fullfile(regFolder, groupStr);
    end
    groupData = groupData(1:idxG);
    
    %% Define Desired Genotype Order and Mapping
    desiredGenotypeOrder = {'WT','LOA','FLX','FLXLOA'};
    genotypeMapping = containers.Map;
    genotypeMapping('WT') = 'Dync1h1(+/+)';
    genotypeMapping('LOA') = 'Dync1h1(+/Loa)';
    genotypeMapping('FLX') = 'Dync1h1(-/+)';
    genotypeMapping('FLXLOA') = 'Dync1h1(-/Loa)';
    
    %% Determine Unique Lumbar Levels and Genotype Order
    allLumbar = {groupData.lumbar};
    uniqueLumbar = unique(allLumbar);
    % Convert each lumbar string (assumed "L<number>") to a numeric value for sorting.
    lumNums = cellfun(@(x) sscanf(x, 'L%d'), uniqueLumbar);
    [~, lumOrder] = sort(lumNums);
    uniqueLumbar = uniqueLumbar(lumOrder);
    
    presentGenotypes = unique({groupData.genotype});
    uniqueGenotypes = {};
    for i = 1:length(desiredGenotypeOrder)
        if ismember(desiredGenotypeOrder{i}, presentGenotypes)
            uniqueGenotypes{end+1} = desiredGenotypeOrder{i};
        end
    end
    
    nRows = numel(uniqueLumbar);
    nCols = numel(uniqueGenotypes);
    
    %% Create Figures for Each Cell Type with Tiled Layout (Rows = Lumbar, Columns = Genotype)
    cellTypeLabels = {'ChAT','Parvalbumin','GAD-67','Calbindin'};
    for ch = 0:3
        cellTypeName = cellTypeLabels{ch+1};
        % Create a new figure with transparent background.
        fig = figure('Name', sprintf('Cell Type: %s', cellTypeName), 'NumberTitle', 'off', 'Color', 'none');
        set(gcf, 'InvertHardcopy', 'off'); % ensure transparency in export
        set(fig, 'WindowState', 'maximized');
        t = tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
        t.TileIndexing = 'rowmajor';
        
        % Preallocate arrays for storing density maps and axis handles.
        densities = cell(nRows, nCols);
        axHandles = gobjects(nRows, nCols);
        
        for r = 1:nRows
            for c = 1:nCols
                currentLumbar = uniqueLumbar{r};
                currentGenotype = uniqueGenotypes{c};
                % Find the matching group.
                matchIdx = find(strcmp({groupData.genotype}, currentGenotype) & strcmp({groupData.lumbar}, currentLumbar), 1);
                ax = nexttile(t, (r-1)*nCols + c);
                axHandles(r, c) = ax;
                set(ax, 'Color', 'none'); % transparent axes
                if isempty(matchIdx)
                    axis(ax, 'off');
                    densities{r, c} = [];
                    title(ax, sprintf('%s, %s', genotypeMapping(currentGenotype), currentLumbar), 'Interpreter', 'none');
                    continue;
                end
                
                % --- Gray Matter Overlay ---
                % Load the saved average mask (do not binarise; preserve intensity gradients)
                avgMask = im2double(imread(groupData(matchIdx).avgMaskFile));
                % Threshold the mask to remove weak values:
                alphaMask = avgMask;
                alphaMask(alphaMask < 0.05) = 0;  % you can adjust this threshold
                % Create a truecolor black image (RGB) of the same size.
                blackRGB = zeros([size(avgMask) 3], 'uint8');
                % Plot the black RGB image using imshow so it remains unaffected by the colormap.
                hBg = imshow(blackRGB, 'Parent', ax, 'InitialMagnification', 'fit');
                % Force the black overlay to use the desired alpha without scaling:
                set(hBg, 'AlphaData', alphaMask, 'AlphaDataMapping', 'none');
                hold(ax, 'on');
                
                % --- Cell Density Overlay ---
                regGroupFolder = groupData(matchIdx).regGroupFolder;
                pattern = sprintf('*_ch%02d_cell_registered.tif', ch);
                cellFiles = dir(fullfile(regGroupFolder, pattern));
                if isempty(cellFiles)
                    warning('No registered cell masks for group %s, channel %d.', groupData(matchIdx).groupName, ch);
                    axis(ax, 'off');
                    densities{r, c} = [];
                    title(ax, sprintf('%s, %s', genotypeMapping(currentGenotype), currentLumbar), 'Interpreter', 'none');
                    hold(ax, 'off');
                    continue;
                end
                sumImage = [];
                count = 0;
                for j = 1:length(cellFiles)
                    filePath = fullfile(regGroupFolder, cellFiles(j).name);
                    img = im2double(imread(filePath));
                    if isempty(sumImage)
                        sumImage = zeros(size(img));
                    end
                    if ~isequal(size(img), size(sumImage))
                        img = imresize(img, size(sumImage));
                    end
                    sumImage = sumImage + img;
                    count = count + 1;
                end
                % Use the sum (cell count) so that the overlay shows integer counts.
                cellCount = sumImage;
                % Mask the density so that only areas where the average mask is nonzero are shown.
                maskedDensity = cellCount .* double(avgMask > 0);
                densities{r, c} = maskedDensity;
                
                % Overlay the cell density heatmap.
                hHeat = imagesc(ax, maskedDensity);
                set(hHeat, 'AlphaData', 0.6 * double(maskedDensity > 0));
                hold(ax, 'off');
                title(ax, sprintf('%s, %s', genotypeMapping(currentGenotype), currentLumbar), 'Interpreter', 'none');
                axis(ax, 'equal');
                axis(ax, 'off');
            end
        end
        
        %% Set a Fixed Common Color Scale (CLim) for All Subplots
        commonCLim = [-0.5, 5.5];
        for r = 1:nRows
            for c = 1:nCols
                if ~isempty(axHandles(r,c))
                    set(axHandles(r,c), 'CLim', commonCLim);
                end
            end
        end
        
        % Define a custom colormap (each row is [R G B])
        customMap = [
            0, 0, 0;    % black for 0
            1, 0, 1;    % magenta for 1
            1, 1, 0;    % yellow for 2
            1, 0, 0;    % red for 3
            0, 1, 1;    % cyan for 4
            1, 1, 1;    % white for 5
        ];

        % Set the overall figure colormap.
        colormap(fig, customMap);
        
        %% Add a Single Common Colorbar with Integer Ticks
        cb = colorbar;
        cb.Position = [0.92, 0.11, 0.02, 0.815];
        ticks = 0:5;
        set(cb, 'Ticks', ticks, 'TickLabels', ticks);
        
        %% Add Overall Title and Save the Figure as SVG, then Close
        t.Title.String = sprintf('%s', cellTypeName);
        t.Title.FontSize = 14;
        svgFileName = fullfile(parentFolder, sprintf('OverlayHeatmap_byGenotypeLumbar_%s.svg', cellTypeName));
        print(fig, svgFileName, '-dsvg');
        fprintf('Saved overlay heatmap for cell type %s as %s\n', cellTypeName, svgFileName);
        close(fig);
    end
end
