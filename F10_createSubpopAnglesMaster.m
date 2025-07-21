function F10_createSubpopAnglesMaster
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% Compile a master file of cell angles (transformed angles) from a folder tree.
%
% Folder structure:
%   MainFolder/
%       MouseID1/
%           SectionID1/
%               *interneurons_distances_angles.csv
%               *motorNeurons_distances_angles.csv
%               ... (2 CSV files per section)
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
% The function writes 'ChAT_subpopulation_angles_master.xlsx' in the selected main folder.
%
% Run this function from MATLAB. It will prompt you to select the main folder.

%%
    % Prompt for main folder
    mainFolder = uigetdir(pwd, 'Select main folder containing mouse subfolders');
    if mainFolder == 0
        disp('No folder selected. Exiting.');
        return;
    end

    % Prepare master data and header
    masterData   = {};
    masterHeader = {'MouseID','Genotype','SectionID','Subpopulation', ...
                    'CellID','Angle','Angle_transformed'};

    % Define CSV patterns
    patterns = { ...
        fullfile(mainFolder,'**','*interneurons_distances_angles.csv'), ...
        fullfile(mainFolder,'**','*motorNeurons_distances_angles.csv') ...
    };

    % Loop through patterns
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

            % Check for required columns
            if ~all(ismember({'Cell','Distance','Angle'}, T.Properties.VariableNames))
                warning('Skipping %s: missing required columns.', filePath);
                continue;
            end
            hasTrans = ismember('Angle_transformed', T.Properties.VariableNames);

            % Extract data
            cellIDs = T.Cell;
            distances = T.Distance;
            angles = T.Angle;
            if hasTrans
                anglesT = T.Angle_transformed;
            else
                anglesT = nan(size(angles));
            end

            % Append each row to masterData
            n = height(T);
            for r = 1:n
                masterData(end+1, :) = { ...
                    mouseID, genotype, sectionID, subpop, ...
                    cellIDs(r), angles(r), anglesT(r) ...
                };
            end
        end
    end

    % Convert to table and write Excel
    masterTable = cell2table(masterData, 'VariableNames', masterHeader);
    outFile = fullfile(mainFolder, 'ChAT_subpopulation_angles_master.xlsx');
    writetable(masterTable, outFile);
    fprintf('Master sheet written to %s\n', outFile);
end
