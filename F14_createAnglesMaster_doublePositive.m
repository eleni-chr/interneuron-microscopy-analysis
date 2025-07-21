function F14_createAnglesMaster_doublePositive
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Compile a master file of cell angles (transformed angles) from a folder tree.
%
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%               *_double_pos_distances_angles.csv
%               ... (3 CSV files per section)
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
% The function writes 'double_pos_angles_master.xlsx' in the selected main folder.
%
% Run this function from MATLAB. It will prompt you to select the main folder.

%% Prompt for main folder
mainFolder = uigetdir(pwd, 'Select the main folder containing mouse subfolders');
if mainFolder == 0
    disp('No folder selected. Exiting.');
    return;
end

% Initialize container for master data
masterData = {};
masterHeader = {'MouseID','Genotype','SectionID','Population','CellID','Angle','Angle_transformed'};

% Find all double-positive distances_angles CSVs
csvFiles = dir(fullfile(mainFolder, '**', '*_double_pos_distances_angles.csv'));

for i = 1:numel(csvFiles)
    % Full path to CSV
    csvPath = fullfile(csvFiles(i).folder, csvFiles(i).name);
    fprintf('Processing: %s\n', csvPath);
    
    % Extract MouseID and SectionID from folder structure
    % e.g. .../MainFolder/MouseID/SectionID/
    parts = strsplit(csvFiles(i).folder, filesep);
    sectionID = parts{end};
    mouseID  = parts{end-1};
    
    % Determine genotype from mouseID
    if ismember(mouseID, {'FCD8-29','FCD11-4','FCD8-11'})
        genotype = 'Dync1h1(+/+)';
    elseif ismember(mouseID, {'FCD12-2','FCD12-6','FCD9-18'})
        genotype = 'Dync1h1(-/+)';
    elseif ismember(mouseID, {'FCD8-26','FCD8-28','FCD10-7'})
        genotype = 'Dync1h1(+/Loa)';
    elseif ismember(mouseID, {'FCD12-3','FCD12-4','FCD12-5'})
        genotype = 'Dync1h1(-/Loa)';
    else
        genotype = '';
    end
    
    % Population label (strip suffix)
    population = erase(csvFiles(i).name, '_double_pos_distances_angles.csv');
    
    % Read the CSV into a table
    try
        T = readtable(csvPath);
    catch ME
        warning('  Could not read %s: %s', csvFiles(i).name, ME.message);
        continue;
    end
    
    % Check for required columns
    if ~ismember('Angle', T.Properties.VariableNames)
        warning('  Missing "Angle" in %s; skipping.', csvFiles(i).name);
        continue;
    end
    if ~ismember('Angle_transformed', T.Properties.VariableNames)
        warning('  Missing "Angle_transformed" in %s; skipping.', csvFiles(i).name);
        continue;
    end
    
    % Extract cell IDs
    cellIDs = T{:,1};
    if isnumeric(cellIDs)
        cellIDs = num2cell(cellIDs);
    end
    
    % Extract angles
    angles = T.Angle;
    angles_t = T.Angle_transformed;
    
    % Append each row to masterData
    nRows = height(T);
    for r = 1:nRows
        masterData(end+1, :) = {
            mouseID, ...
            genotype, ...
            sectionID, ...
            population, ...
            cellIDs{r}, ...
            angles(r), ...
            angles_t(r) ...
        };
    end
end

% Convert to table and write to Excel
masterTbl = cell2table(masterData, 'VariableNames', masterHeader);
outFile = fullfile(mainFolder, 'double_pos_angles_master.xlsx');
writetable(masterTbl, outFile);

fprintf('Master file created: %s\n', outFile);
end
