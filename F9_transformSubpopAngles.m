function F9_transformSubpopAngles
%% Function written by Dr Eleni Christoforidou in MATLAB R2024b.

% This function searches for all CSV files ending in "interneurons_distances_angles.csv"
% or "motorNeurons_distances_angles.csv" within the current directory and 
% all subdirectories. It then reads each file and applies a transformation 
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
    patterns = {...
        '**/*interneurons_distances_angles.csv', ...
        '**/*motorNeurons_distances_angles.csv' ...
    };

    for p = 1:numel(patterns)
        files = dir(patterns{p});
        for i = 1:numel(files)
            filePath = fullfile(files(i).folder, files(i).name);
            fprintf('Processing file: %s\n', filePath);

            try
                T = readtable(filePath);

                % Check for Angle column
                if ~ismember("Angle", T.Properties.VariableNames)
                    warning('Skipping %s: no "Angle" column.', filePath);
                    continue;
                end

                % Skip if already transformed
                if ismember("Angle_transformed", T.Properties.VariableNames)
                    fprintf('Skipping %s: "Angle_transformed" exists.\n', filePath);
                    continue;
                end

                % Transform angles
                ang = T.Angle;
                mask = (ang >= 90 & ang <= 270);
                ang_trans = ang;
                ang_trans(mask) = 180 - ang(mask);

                % Append and write back
                T.Angle_transformed = ang_trans;
                writetable(T, filePath);
                fprintf('Updated: %s\n', filePath);

            catch ME
                warning('Error processing %s: %s', filePath, ME.message);
            end
        end
    end

    fprintf('Subpopulation angle transformation complete.\n');
end
