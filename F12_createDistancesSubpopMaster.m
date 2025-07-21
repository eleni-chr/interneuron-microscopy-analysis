function F12_createDistancesSubpopMaster
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.
%
% Compile a master file of normalised cell distances from a folder tree.
%
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%               interneurons_DT.csv
%               motorNeurons_DT.csv
%           SectionID2/
%               ...
%       MouseID2/
%           SectionID1/
%               ...
%
% The master file (ChAT_subpopulation_distances_master.xlsx) will have the following columns:
%   1. MouseID (from the mouse folder name)
%   2. Genotype (hardcoded using mouseIDs)
%   3. SectionID (spinal cord cross-section folder name)
%   4. Subpopulation
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
    masterHeader = {'MouseID','Genotype','SectionID','Subpopulation','CellID','Normalised_DT_distance'};

    % Define CSV patterns
    patterns = { ...
        fullfile(mainFolder,'**','*interneurons_DT.csv'), ...
        fullfile(mainFolder,'**','*motorNeurons_DT.csv') ...
    };

    % Loop over each CSV
    for p = 1:numel(patterns)
        files = dir(patterns{p});
        for i = 1:numel(files)
            filePath = fullfile(files(i).folder, files(i).name);
            fprintf('Reading: %s\n', filePath);

            % Determine Subpopulation from filename
            if contains(files(i).name, 'interneurons_')
                subpop = 'interneurons';
            else
                subpop = 'motorNeurons';
            end

            % Identify MouseID and SectionID from folder structure
            parts = strsplit(files(i).folder, filesep);
            % assumes .../mainFolder/MouseID/SectionID/...
            sectionID = parts{end};
            mouseID   = parts{end-1};

            % Determine genotype
            switch mouseID
                case {'FCD8-29','FCD11-4','FCD8-11'}
                    genotype = 'Dync1h1(+/+)';
                case {'FCD12-2','FCD12-6','FCD9-18'}
                    genotype = 'Dync1h1(-/+)';
                case {'FCD8-26','FCD8-28','FCD10-7'}
                    genotype = 'Dync1h1(+/Loa)';
                case {'FCD12-3','FCD12-4','FCD12-5'}
                    genotype = 'Dync1h1(-/Loa)';
                otherwise
                    genotype = '';
            end

            % Read the CSV into a table
            try
                T = readtable(filePath);
            catch ME
                warning('Could not read %s: %s', filePath, ME.message);
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
                    subpop, ...
                    cellIDs{r}, ...
                    distances(r) ...
                };
            end
        end
    end

    % Create table and write to Excel
    masterTbl = cell2table(masterData,'VariableNames',masterHeader);
    outFile = fullfile(mainFolder,'ChAT_subpopulation_distances_master.xlsx');
    writetable(masterTbl,outFile);
    fprintf('Master distances file created: %s\n', outFile);
end
