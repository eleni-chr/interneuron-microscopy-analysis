function F2_createAnglesMaster
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Compile a master file of cell angles (transformed angles) from a folder tree.
%
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%               ch00_MAX_distances_angles.csv
%               ch01_MAX_distances_angles.csv
%               ... (four CSV files per section)
%           SectionID2/
%               ...
%       MouseID2/
%           SectionID1/
%               ...
%
% The master file (angles_master.xlsx) will have the following columns:
%   1. MouseID (from the mouse folder name)
%   2. Genotype (left empty for manual entry later)
%   3. SectionID (spinal cord cross-section folder name)
%   4. Channel (extracted from the CSV file name, e.g., 'ch00_MAX')
%   5. CellID (from the first column of the CSV file)
%   6. Angle (from the CSV file column with header 'Angle')
%   7. Angle_transformed (from the CSV file column with header 'Angle_transformed')
%
% Run this function from MATLAB. It will prompt you to select the main folder.

%%
% Prompt the user to select the main folder.
mainFolder = uigetdir(pwd, 'Select the main folder containing mouse subfolders');
if mainFolder == 0
    disp('No folder selected. Exiting.');
    return;
end

% Initialize an empty cell array to hold master data.
masterData = {}; 
% Define header for master file.
masterHeader = {'MouseID', 'Genotype', 'SectionID', 'Channel', 'CellID', 'Angle', 'Angle_transformed'};

% List mouse folders in the main folder (ignore . and ..)
mouseFolders = dir(mainFolder);
mouseFolders = mouseFolders([mouseFolders.isdir] & ~ismember({mouseFolders.name}, {'.','..'}));

for i = 1:length(mouseFolders)
    mouseID = mouseFolders(i).name;


    % Determine genotype based on mouseID.
    if strcmp(mouseID, 'FCD8-29') || strcmp(mouseID, 'FCD11-4') || strcmp(mouseID, 'FCD8-11')
        genotype = 'Dync1h1(+/+)';
    elseif strcmp(mouseID, 'FCD12-2') || strcmp(mouseID, 'FCD12-6') || strcmp(mouseID, 'FCD9-18')
        genotype = 'Dync1h1(-/+)';
    elseif strcmp(mouseID, 'FCD8-26') || strcmp(mouseID, 'FCD8-28') || strcmp(mouseID, 'FCD10-7')
        genotype = 'Dync1h1(+/Loa)';
    elseif strcmp(mouseID, 'FCD12-3') || strcmp(mouseID, 'FCD12-4') || strcmp(mouseID, 'FCD12-5')
        genotype = 'Dync1h1(-/Loa)';
    else
        genotype = '';  % Leave empty if the mouseID does not match any known pattern.
    end

    mousePath = fullfile(mainFolder, mouseID);
    
    % List section folders within each mouse folder.
    sectionFolders = dir(mousePath);
    sectionFolders = sectionFolders([sectionFolders.isdir] & ~ismember({sectionFolders.name}, {'.','..'}));
    
    for j = 1:length(sectionFolders)
        sectionID = sectionFolders(j).name;
        sectionPath = fullfile(mousePath, sectionID);
        
        % List CSV files matching the pattern *_distances_angles.csv
        csvFiles = dir(fullfile(sectionPath, '*_distances_angles.csv'));

        if isempty(csvFiles)
            continue;
        end

        for k = 1:length(csvFiles)
            csvFileName = csvFiles(k).name;
            csvFilePath = fullfile(sectionPath, csvFileName);
            
            % Extract channel: remove the ending '_distances_angles.csv'
            channelID = strrep(csvFileName, '_distances_angles.csv', '');
            
            % Read the CSV file as a table.
            try
                T = readtable(csvFilePath);
            catch ME
                warning('Could not read file %s: %s', csvFilePath, ME.message);
                continue;
            end
            
            % Identify the column for "Angle_transformed" (case-insensitive)
            angle_transformedColIdx = find(contains(T.Properties.VariableNames, 'Angle_transformed', 'IgnoreCase', true), 1);
            if isempty(angle_transformedColIdx)
                warning('No ''Angle_transformed'' column found in file %s. Skipping.', csvFilePath);
                continue;
            end
            
            % Assume the first column is the cell ID.
            cellIDs = T{:,1};
            angles = T{:,6};
            angles_transformed = T{:, angle_transformedColIdx};
            
            % Ensure angles are numeric.
            if ~isnumeric(angles_transformed)
                angles_transformed = str2double(angles_transformed);
            end
            
            % For each row in the CSV, add a row to masterData.
            nRows = height(T);
            for r = 1:nRows
                masterData(end+1, :) = {mouseID, genotype, sectionID, channelID, cellIDs(r), angles(r), angles_transformed(r)};
            end
        end
    end
end

% Convert masterData into a table and add header.
masterTable = cell2table(masterData, 'VariableNames', masterHeader);

% Save the master table to an Excel file in the main folder.
outputFile = fullfile(mainFolder, 'angles_master.xlsx');
writetable(masterTable, outputFile);

fprintf('Master file created: %s\n', outputFile);
end
