function F16_createDistancesMaster_doublePositive
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.
%
% Compile a master file of normalised cell distances from a folder tree.
%
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%               *_double_pos_DT.csv
%               ... (3 CSV files per section)
%           SectionID2/
%               ...
%       MouseID2/
%           SectionID1/
%               ...
%
% The master file (double_pos_distances_master.xlsx) will have the following columns:
%   1. MouseID (from the mouse folder name)
%   2. Genotype (hardcoded using mouseIDs)
%   3. SectionID (spinal cord cross-section folder name)
%   4. Population
%   5. CellID (from the first column of the CSV file)
%   6. Normalised_DT_distance (from the CSV file column with header 'Normalised_DT')
%
% Run this function from MATLAB. It will prompt you to select the main folder.

    %% Prompt for main folder
    mainFolder = uigetdir(pwd, 'Select the main folder containing mouse subfolders');
    if mainFolder == 0
        disp('No folder selected. Exiting.');
        return;
    end

    % Initialize data container and header
    masterData   = {};
    masterHeader = {'MouseID','Genotype','SectionID','Population','CellID','Normalised_DT_distance'};

    % Find all double‐positive distances_angles CSVs
    csvFiles = dir(fullfile(mainFolder, '**', '*_double_pos_DT.csv'));

    % Loop over each CSV
    for i = 1:numel(csvFiles)
        fileInfo = csvFiles(i);
        csvPath  = fullfile(fileInfo.folder, fileInfo.name);
        fprintf('Processing: %s\n', csvPath);

        % Extract section and mouse IDs from path
        parts     = strsplit(fileInfo.folder, filesep);
        sectionID = parts{end};
        mouseID   = parts{end-1};

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

        % Population label (strip the suffix)
        population = erase(fileInfo.name, '_double_pos_DT.csv');

        % Read the table
        try
            T = readtable(csvPath);
        catch ME
            warning('  Could not read %s: %s', fileInfo.name, ME.message);
            continue;
        end

        % Locate Distance column
        idxDist = find(contains(T.Properties.VariableNames,'Normalised_DT','IgnoreCase',true),1);
        if isempty(idxDist)
            warning('  No "Normalised_DT" column in %s; skipping.', fileInfo.name);
            continue;
        end

        % Cell IDs (first column)
        cellIDs = T{:,1};
        if isnumeric(cellIDs)
            cellIDs = num2cell(cellIDs);
        end

        % Distance values
        distances = T{:,idxDist};
        if ~isnumeric(distances)
            distances = str2double(distances);
        end

        % Append each row
        nRows = height(T);
        for r = 1:nRows
            masterData(end+1,:) = {
                mouseID, ...
                genotype, ...
                sectionID, ...
                population, ...
                cellIDs{r}, ...
                distances(r) ...
            };
        end
    end

    % Create table and write to Excel
    masterTbl = cell2table(masterData,'VariableNames',masterHeader);
    outFile = fullfile(mainFolder,'double_pos_distances_master.xlsx');
    writetable(masterTbl,outFile);
    fprintf('Master distances file created: %s\n', outFile);
end
