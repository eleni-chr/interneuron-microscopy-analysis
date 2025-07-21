function F5_registerGrayMatterMasks
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
% This function registers the gray matter masks from microscopy images of spinal 
% cord cross‐sections. It works by:
%   1. Prompting the user to select a main folder containing mouse subfolders.
%   2. Prompting for two CSV files:
%        - A genotype CSV file with columns (MouseID, Genotype).
%        - A lumbar CSV file with columns (SectionID, LumbarLevel).
%   3. Iterating through each mouse subfolder and each inner folder (representing
%      a specific spinal cord section), where it:
%        - Loads the central canal binary mask TIFF and computes its centroid.
%        - Loads the gray matter binary mask TIFF.
%        - Uses the first encountered gray matter mask in each group (grouped
%          by genotype and lumbar level) as the registration reference, saving its
%          target size and central canal centroid.
%        - For subsequent sections within the same group, computes the translation
%          vector required to align their central canal with the reference, applies
%          this transformation to the gray matter mask, and registers the image.
%   4. Saving the registered gray matter mask TIFF files in an output folder 
%      called "Registered_Masks" organised by group (genotype_lumbarLevel).
%
% INPUT:
%   - Main folder containing individual mouse subfolders.
%   - A genotype CSV file (with columns: MouseID, Genotype).
%   - A lumbar CSV file (with columns: SectionID, LumbarLevel).
%
% OUTPUT:
%   - Registered gray matter mask TIFF files saved in the "Registered_Masks" folder.
%
% USAGE:
%   1. Run this function.
%   2. Select the main folder and CSV files when prompted.
%   3. The function will process the images, register the masks, and save the 
%      registered output for subsequent analyses.

    %% Prompt the user to select folders and CSV files
    mainDir = uigetdir(pwd, 'Choose main folder containing mouse subfolders:');
    if mainDir == 0
        error('No main folder selected.');
    end
    
    [genoFile, genoPath] = uigetfile('*.csv', 'Select genotype CSV file (format: MouseID,Genotype)');
    if isequal(genoFile,0)
        error('No genotype CSV file selected.');
    end
    genoCSV = fullfile(genoPath, genoFile);
    genoTable = readtable(genoCSV);
    
    [lumbarFile, lumbarPath] = uigetfile('*.csv', 'Select lumbar CSV file (format: SectionID,LumbarLevel)');
    if isequal(lumbarFile,0)
        error('No lumbar CSV file selected.');
    end
    lumbarCSV = fullfile(lumbarPath, lumbarFile);
    lumbarTable = readtable(lumbarCSV);
    
    %% Setup output folder and reference storage
    outputBase = fullfile(mainDir, 'Registered_Masks');
    if ~exist(outputBase, 'dir')
        mkdir(outputBase);
    end
    % refData will store two fields for each group: 
    %   .centroid – the reference central canal centroid [x y]
    %   .targetSize – the [rows cols] from the first gray matter mask in that group
    refData = struct();
    
    %% Process each mouse subfolder
    mouseDirs = dir(mainDir);
    mouseDirs = mouseDirs([mouseDirs.isdir] & ~ismember({mouseDirs.name}, {'.', '..'}));
    
    for i = 1:length(mouseDirs)
        mouseID = mouseDirs(i).name;
        % Look up genotype for this mouse using the CSV.
        idx = strcmp(genoTable.MouseID, mouseID);
        if ~any(idx)
            warning('Genotype not found for mouse %s. Skipping.', mouseID);
            continue;
        end
        genotype = genoTable.Genotype{idx};
        
        mousePath = fullfile(mainDir, mouseID);
        innerDirs = dir(mousePath);
        innerDirs = innerDirs([innerDirs.isdir] & ~ismember({innerDirs.name}, {'.', '..'}));
        
        for j = 1:length(innerDirs)
            innerFolder = innerDirs(j).name;
            % Look up the lumbar level from the CSV.
            idxLumbar = strcmp(lumbarTable.SectionID, innerFolder);
            if ~any(idxLumbar)
                warning('Lumbar level not found for folder %s in mouse %s. Skipping.', innerFolder, mouseID);
                continue;
            end
            lumbar = lumbarTable.LumbarLevel{idxLumbar};
            % Build a group key including genotype and lumbar level.
            % (It is assumed that genotype/lumbar level strings are valid or were preprocessed.)
            groupKey = sprintf('%s_%s', genotype, lumbar);
            % Optionally, clean the key using matlab.lang.makeValidName:
            groupKey = matlab.lang.makeValidName(groupKey);
            
            innerPath = fullfile(mousePath, innerFolder);
            
            %% Load the central canal binary mask TIFF and compute centroid
            canalFile = fullfile(innerPath, 'C1_central_canal_mask.tif');
            if ~exist(canalFile, 'file')
                warning('Central canal mask not found in %s. Skipping.', innerPath);
                continue;
            end
            canalMask = imread(canalFile);
            if ~islogical(canalMask)
                canalMask = imbinarize(canalMask);
            end
            
            %% Load the gray matter binary mask TIFF image
            gmFile = fullfile(innerPath, 'ch00_MAX_gray_matter_mask.tif');
            if ~exist(gmFile, 'file')
                warning('Gray matter mask not found in %s. Skipping.', innerPath);
                continue;
            end
            gmMask = imread(gmFile);
            if ~islogical(gmMask)
                gmMask = imbinarize(gmMask);
            end
            
            %% Standardise image size within the group
            % For the first image in the group, record the target size.
            if ~isfield(refData, groupKey)
                targetSize = size(gmMask);  % use the size of the current gray matter mask
                refData.(groupKey).targetSize = targetSize;
                % Resize the central canal mask (if needed; should be same as target)
                if ~isequal(size(canalMask), targetSize)
                    canalMask = imresize(canalMask, targetSize);
                end
                % Compute the reference central canal centroid.
                props = regionprops(canalMask, 'Centroid');
                if isempty(props)
                    warning('No region detected in %s. Skipping.', canalFile);
                    continue;
                end
                refData.(groupKey).centroid = props(1).Centroid;  % [x, y]
                % For the first image, no registration is needed.
                registeredMask = gmMask;
                fprintf('Group %s: Set reference (size: [%d %d]) from mouse %s, folder %s.\n',...
                    groupKey, targetSize(1), targetSize(2), mouseID, innerFolder);
            else
                targetSize = refData.(groupKey).targetSize;
                % Resize the current gmMask if necessary.
                if ~isequal(size(gmMask), targetSize)
                    gmMask = imresize(gmMask, targetSize);
                end
                % Also ensure the central canal mask is resized.
                if ~isequal(size(canalMask), targetSize)
                    canalMask = imresize(canalMask, targetSize);
                end
                % Recalculate the central canal centroid.
                props = regionprops(canalMask, 'Centroid');
                if isempty(props)
                    warning('No region detected in %s. Skipping.', canalFile);
                    continue;
                end
                currentCentroid = props(1).Centroid;
                refCentroid = refData.(groupKey).centroid;
                % Compute the translation vector needed (difference between centroids).
                shiftVec = refCentroid - currentCentroid;  % [dx, dy]
                % Build the transformation matrix for translation.
                tform = affine2d([1 0 0; 0 1 0; shiftVec(1) shiftVec(2) 1]);
                % Apply the transformation to the gray matter mask.
                registeredMask = imwarp(gmMask, tform, 'OutputView', imref2d(targetSize));
                fprintf('Group %s: Registered mask for mouse %s, folder %s.\n',...
                    groupKey, mouseID, innerFolder);
            end
            
            %% Save the registered gray matter mask
            groupOutDir = fullfile(outputBase, groupKey);
            if ~exist(groupOutDir, 'dir')
                mkdir(groupOutDir);
            end
            outFile = fullfile(groupOutDir, sprintf('%s_%s_registered.tif', mouseID, innerFolder));
            imwrite(registeredMask, outFile);
        end
    end
end
