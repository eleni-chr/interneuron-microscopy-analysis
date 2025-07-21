function F7_registerCellMasks
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.
% 
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%           SectionID2/
%               ...
%       MouseID2/
%           SectionID1/
%               ...
% 
% This function registers the cell mask ROIs for each cell type (across channels 0–3)
% from microscopy images of spinal cord cross‐sections. Registration is performed
% by computing a translation transformation based on the central canal binary mask.
%
% The function performs the following steps:
%   1. Prompts the user to select a main folder containing mouse subfolders and to
%      select two CSV files:
%         - A genotype CSV file with columns: MouseID, Genotype.
%         - A lumbar CSV file with columns: SectionID, LumbarLevel.
%
%   2. Iterates over each mouse subfolder and each inner folder (corresponding to a
%      specific spinal cord section). For each inner folder:
%         - Loads the central canal binary mask TIFF file ("C1_central_canal_mask.tif")
%           and computes its centroid.
%         - For the first section within each group (defined by a combination of genotype
%           and lumbar level), the target size and reference centroid are stored.
%         - For subsequent sections within the same group, a translation vector is computed
%           to align the current central canal mask with the reference.
%
%   3. Applies the computed affine transformation (translation) to the cell mask images.
%      Cell masks for each channel ("ch00_MAX_cell_masks.tif", "ch01_MAX_cell_masks.tif",
%      "ch02_MAX_cell_masks.tif", and "ch03_MAX_cell_masks.tif") are loaded, registered,
%      and then saved.
%
%   4. Registered cell mask TIFF files are saved in an output folder named 
%      "Registered_Cell_Masks", organised into subfolders by group (where each group is
%      identified by a valid combination of genotype and lumbar level).
%
% OUTPUT:
%   Registered cell mask TIFF files are created and saved in the "Registered_Cell_Masks"
%   folder. The filenames include the mouse ID, section ID, and channel number.
%
% USAGE:
%   1. Run this function.
%   2. When prompted, select the main folder containing the mouse subfolders and then the CSV
%      files (genotype and lumbar level data).
%   3. The function processes the central canal mask to compute the necessary translation,
%      applies it to each cell mask for channels 0–3, and saves the registered cell masks for
%      further analysis.

    %% Prompt for Input Folders and CSV Files
    % Choose the main folder that contains the mouse subfolders
    mainDir = uigetdir(pwd, 'Choose main folder containing mouse subfolders:');
    if mainDir == 0
        error('No main folder selected.');
    end
    
    % Select the genotype CSV file (with columns: MouseID,Genotype)
    [genoFile, genoPath] = uigetfile('*.csv', 'Select genotype CSV file (format: MouseID,Genotype)');
    if isequal(genoFile,0)
        error('No genotype CSV file selected.');
    end
    genoCSV = fullfile(genoPath, genoFile);
    genoTable = readtable(genoCSV);
    
    % Select the lumbar CSV file (with columns: InnerFolder,LumbarLevel)
    [lumbarFile, lumbarPath] = uigetfile('*.csv', 'Select lumbar CSV file (format: SectionID,LumbarLevel)');
    if isequal(lumbarFile,0)
        error('No lumbar CSV file selected.');
    end
    lumbarCSV = fullfile(lumbarPath, lumbarFile);
    lumbarTable = readtable(lumbarCSV);
    
    %% Setup Output Folder
    outputBase = fullfile(mainDir, 'Registered_Cell_Masks');
    if ~exist(outputBase, 'dir')
        mkdir(outputBase);
    end
    
    % Structure to store reference data per group (target size and central canal centroid)
    refData = struct();
    
    %% Loop Over Mouse Subfolders and Inner Folders
    mouseDirs = dir(mainDir);
    mouseDirs = mouseDirs([mouseDirs.isdir] & ~ismember({mouseDirs.name}, {'.','..'}));
    
    for i = 1:length(mouseDirs)
        mouseID = mouseDirs(i).name;
        % Lookup genotype using the mouse folder name from the genotype CSV
        idxMouse = strcmp(genoTable.MouseID, mouseID);
        if ~any(idxMouse)
            warning('Genotype not found for mouse %s. Skipping.', mouseID);
            continue;
        end
        genotype = genoTable.Genotype{idxMouse};
        mousePath = fullfile(mainDir, mouseID);
        innerDirs = dir(mousePath);
        innerDirs = innerDirs([innerDirs.isdir] & ~ismember({innerDirs.name}, {'.','..'}));
        
        for j = 1:length(innerDirs)
            innerFolder = innerDirs(j).name;
            % Lookup lumbar level using the inner folder name from the lumbar CSV
            idxLumbar = strcmp(lumbarTable.SectionID, innerFolder);
            if ~any(idxLumbar)
                warning('Lumbar level not found for folder %s in mouse %s. Skipping.', innerFolder, mouseID);
                continue;
            end
            lumbar = lumbarTable.LumbarLevel{idxLumbar};
            % Create a group key from genotype and lumbar level
            originalKey = sprintf('%s_%s', genotype, lumbar);
            % Convert to a valid field name
            groupKey = matlab.lang.makeValidName(originalKey);
            innerPath = fullfile(mousePath, innerFolder);
            
            %% Load Central Canal Mask and Compute Transformation
            canalFile = fullfile(innerPath, 'C1_central_canal_mask.tif');
            if ~exist(canalFile, 'file')
                warning('Central canal mask not found in %s. Skipping.', innerPath);
                continue;
            end
            canalMask = imread(canalFile);
            if ~islogical(canalMask)
                canalMask = imbinarize(canalMask);
            end
            
            % For the first encountered image in the group, store target size and reference centroid
            if ~isfield(refData, groupKey)
                targetSize = size(canalMask);
                refData.(groupKey).targetSize = targetSize;
                props = regionprops(canalMask, 'Centroid');
                if isempty(props)
                    warning('No region detected in central canal mask in %s. Skipping.', canalFile);
                    continue;
                end
                refData.(groupKey).centroid = props(1).Centroid;  % [x, y]
                fprintf('Group %s: Set reference from mouse %s, folder %s (target size = [%d %d]).\n',...
                    groupKey, mouseID, innerFolder, targetSize(1), targetSize(2));
            else
                targetSize = refData.(groupKey).targetSize;
                if ~isequal(size(canalMask), targetSize)
                    canalMask = imresize(canalMask, targetSize);
                end
            end
            
            % Compute current central canal centroid
            props = regionprops(canalMask, 'Centroid');
            if isempty(props)
                warning('No region detected in central canal mask in %s. Skipping.', canalFile);
                continue;
            end
            currentCentroid = props(1).Centroid;
            refCentroid = refData.(groupKey).centroid;
            % Compute translation vector.
            shiftVec = refCentroid - currentCentroid;  % [dx, dy]
            % Build the affine transformation for translation
            tform = affine2d([1 0 0; 0 1 0; shiftVec(1) shiftVec(2) 1]);
            
            %% Process Each Cell Mask Channel (0 to 3)
            for ch = 0:3
                cellFileName = sprintf('ch%02d_MAX_cell_masks.tif', ch);
                cellFilePath = fullfile(innerPath, cellFileName);
                if ~exist(cellFilePath, 'file')
                    warning('Cell mask file %s not found in %s. Skipping channel %d.', cellFileName, innerPath, ch);
                    continue;
                end
                % Load the cell mask.
                cellMask = imread(cellFilePath);
                if ~islogical(cellMask)
                    cellMask = imbinarize(cellMask);
                end
                % Resize to target size if necessary.
                if ~isequal(size(cellMask), targetSize)
                    cellMask = imresize(cellMask, targetSize);
                end
                % Apply the transformation.
                registeredCellMask = imwarp(cellMask, tform, 'OutputView', imref2d(targetSize));
                
                %% Save the Registered Cell Mask
                outFolder = fullfile(outputBase, groupKey);
                if ~exist(outFolder, 'dir')
                    mkdir(outFolder);
                end
                outFileName = sprintf('%s_%s_ch%02d_cell_registered.tif', mouseID, innerFolder, ch);
                outFilePath = fullfile(outFolder, outFileName);
                imwrite(registeredCellMask, outFilePath);
                fprintf('Group %s: Registered cell mask saved for mouse %s, folder %s, channel %d.\n', ...
                    groupKey, mouseID, innerFolder, ch);
            end
        end
    end
end
