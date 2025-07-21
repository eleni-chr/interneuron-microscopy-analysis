function F13_transformAngles_doublePositive
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% This function searches for all CSV files ending in "double_pos_distances_angles.csv"
% within the current directory and all subdirectories.
% It then reads each file and applies a transformation to the "Angle" 
% column to correct for unknown left-right orientation in free-floating 
% spinal cord sections.
%
% The angles were originally obtained using ImageJ, which computes angles mathematically, where:
% - 0° corresponds to the right,
% - 90° to the dorsal side,
% - 180° to the left,
% - 270° to the ventral side.
%
% Since the true left-right orientation of each tissue section is unknown, angles in 
% the left hemisphere (90°–270°) are mirrored to their right-side equivalents using:
%   θ' = 180° - θ
% Angles in the right hemisphere (0°–90° and 270°–360°) remain unchanged.
%
% The transformed angles are appended as a new column, "Angle_transformed", in each 
% CSV file. The function overwrites the original CSV file with the updated data.

%%
    % Find all double‐positive angle CSV files
    files = dir('**/*_double_pos_distances_angles.csv');

    for i = 1:length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        fprintf('Processing double‐positive file: %s\n', filePath);

        try
            % Read the CSV into a table
            data = readtable(filePath);

            % Check presence of "Angle" column
            if ~ismember("Angle", data.Properties.VariableNames)
                warning('  Skipping (no "Angle" column): %s', files(i).name);
                continue;
            end

            % Skip if already transformed
            if ismember("Angle_transformed", data.Properties.VariableNames)
                fprintf('  Skipping (already has Angle_transformed): %s\n', files(i).name);
                continue;
            end

            % Extract and transform angles
            angles = data.Angle;
            transformed = angles;
            mask = (angles >= 90 & angles <= 270);
            transformed(mask) = 180 - angles(mask);

            % Append new column and overwrite CSV
            data.Angle_transformed = transformed;
            writetable(data, filePath);

            fprintf('  Updated: %s\n', files(i).name);

        catch ME
            warning('  Error in %s: %s', files(i).name, ME.message);
        end
    end

    fprintf('All double‐positive angle transforms complete.\n');
end
