function F6_createAverageMasks
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.
% 
% This function computes average gray matter masks for each experimental group by
% averaging the registered mask TIFF files generated in a previous registration step.
% The groups are defined by the combination of genotype and lumbar level, with 
% individual registered mask files stored in subfolders of the "Registered_Masks" folder.
%
% The function performs the following steps:
%   1. Prompts the user to select a folder containing the registered mask images 
%      (e.g., "Registered_Masks").
%   2. Creates an output folder named "Average_Masks" in the parent directory if it
%      does not already exist.
%   3. Iterates through each group subfolder within the selected folder and identifies 
%      all TIFF files whose names end with "_registered.tif".
%   4. Sums the registered mask images for each group and divides by the number of images 
%      to compute the average mask for that group.
%   5. Saves the computed average mask for each group as a TIFF file in the "Average_Masks" 
%      folder, using filenames that include the group identifier (e.g., "AverageMask_<groupName>.tif").
%
% INPUT:
%   - No input arguments are required. The function prompts the user to select the 
%     folder containing registered mask images.
%
% OUTPUT:
%   - Average gray matter mask TIFF files saved in the "Average_Masks" folder.
%
% USAGE:
%   1. Run the function.
%   2. When prompted, select the folder containing the registered masks.
%   3. The function will process each group, compute the average mask, and save the result
%      for subsequent analysis.

    %% Prompt user for the folder with registered masks
    % This should be the output folder from the registration pipeline (e.g., "Registered_Masks").
    baseFolder = uigetdir(pwd, 'Select the folder containing registered masks (e.g., Registered_Masks)');
    if baseFolder == 0
        error('No folder selected. Exiting.');
    end

    %% Create an output folder for the average masks
    % The "Average_Masks" folder will be created in the parent folder.
    parentFolder = fileparts(baseFolder);
    avgOutputFolder = fullfile(parentFolder, 'Average_Masks');
    if ~exist(avgOutputFolder, 'dir')
        mkdir(avgOutputFolder);
    end

    %% List group folders in the base folder
    groupDirs = dir(baseFolder);
    groupDirs = groupDirs([groupDirs.isdir] & ~ismember({groupDirs.name}, {'.', '..'}));

    %% Loop over each group and compute the average mask
    for i = 1:numel(groupDirs)
        groupName = groupDirs(i).name;
        groupFolder = fullfile(baseFolder, groupName);
        
        % Get a list of all registered mask TIFF files in the group folder.
        % This assumes that the registered mask files have names ending with '_registered.tif'
        maskFiles = dir(fullfile(groupFolder, '*_registered.tif'));
        if isempty(maskFiles)
            warning('No registered mask files found in group folder: %s. Skipping.', groupFolder);
            continue;
        end
        
        % Initialise a variable for accumulation.
        sumImage = [];
        count = 0;
        
        % Loop over each mask file in the group.
        for j = 1:numel(maskFiles)
            imgPath = fullfile(groupFolder, maskFiles(j).name);
            img = imread(imgPath);
            % Convert to double precision for averaging.
            img = im2double(img);
            
            % Initialise the accumulator on the first image.
            if isempty(sumImage)
                sumImage = zeros(size(img));
            end
            
            % If the current image size does not match, resize it to the accumulator size.
            if ~isequal(size(img), size(sumImage))
                img = imresize(img, size(sumImage));
            end
            
            sumImage = sumImage + img;
            count = count + 1;
        end
        
        % Compute the average mask.
        avgMask = sumImage / count;
        
        %% Save the average mask.
        avgFileName = fullfile(avgOutputFolder, sprintf('AverageMask_%s.tif', groupName));
        imwrite(avgMask, avgFileName);
        fprintf('Saved average mask for group %s (%d images) to %s\n', groupName, count, avgFileName);
    end
end
