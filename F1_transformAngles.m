function F1_transformAngles
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% This function searches for all CSV files ending in "angles.csv" within the current 
% directory and all subdirectories. It then reads each file and applies a transformation 
% to the "Angle" column to correct for unknown left-right orientation in free-floating 
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
    % Get all CSV files ending in "angles.csv" within current directory and subdirectories
    files = dir('**/*angles.csv');
    
    % Loop through each file
    for i = 1:length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        fprintf('Processing file: %s\n', filePath);

        % Read the CSV file into a table
        try
            data = readtable(filePath);
            
            % Check if "Angle" column exists
            if ~ismember("Angle", data.Properties.VariableNames)
                warning('Skipping file %s: No "Angle" column found.', filePath);
                continue;
            end

            % Check if "Angle_transformed" column already exists
            if ismember("Angle_transformed", data.Properties.VariableNames)
                fprintf('Skipping file %s: "Angle_transformed" column already exists.\n', filePath);
                continue;
            end
            
            % Extract the angles
            angles = data.Angle;

            % Apply the transformation
            transformed_angles = angles; % Initialize
            mask = (angles >= 90 & angles <= 270); % Identify left-side angles
            transformed_angles(mask) = 180 - angles(mask);

            % Append new column to the table
            data.Angle_transformed = transformed_angles;

            % Write the modified table back to the same CSV file
            writetable(data, filePath);

            fprintf('Successfully updated: %s\n', filePath);
        catch ME
            warning('Error processing file %s: %s', filePath, ME.message);
        end
    end
    
    fprintf('Processing complete.\n');
end
