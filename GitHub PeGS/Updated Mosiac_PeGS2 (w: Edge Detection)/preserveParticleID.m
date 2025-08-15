% preserveParticleID.m
% ------------------------------------------------------------------------------
% Consolidates particle tracking results from canny_auto into a single
% file with consistent and accurate frame numbering, preserving particle IDs.
%
% Main Function:
%   preserveParticleID(fileParams, verbose)
%
% Description:
%   Loads particle tracking results saved as 'particle_tracking_results.mat'
%   in the 'canny_output' folder under the root directory specified by
%   fileParams.topDir. It extracts particle positions, radii, edge flags,
%   and global particle IDs from each image/frame.
%
%   The function compiles all particle data across frames into one
%   consolidated CSV file, 'particle_positions.txt', with columns:
%       [frame, particleId, x, y, radius, edge, (optional) edgeAngles...]
%
%   If an existing 'particle_positions.txt' file is present, it backs it up
%   as 'particle_positions.txt.backup' before writing the new file.
%
% INPUTS:
%   fileParams - Struct with at least:
%       .topDir : Root directory where 'canny_output' and output files reside
%
%   verbose - (Optional) Logical flag to display progress messages and stats.
%
% OUTPUTS:
%   Creates or overwrites:
%       [fileParams.topDir]/particle_positions.txt
%         - Consolidated particle data from all frames.
%         - Includes optional edge angle columns if present.
%       [fileParams.topDir]/particle_positions.txt.backup
%         - Backup of prior output file if it existed.
%
% USAGE:
%   1. Run canny_auto to generate particle tracking results.
%   2. Call preserveParticleID(fileParams, true) to produce consolidated file.
%   3. Use particle_positions.txt as input to runCD2.m for contact detection.
%
% NOTES:
%   - Frames correspond to image indices in the loaded results.
%   - If radius data is missing, defaults to 20.
%   - If edge flags are missing, defaults to 0.
%   - Edge angles (if present) are appended as additional columns.
%
% Authors: [Vir Goyal, Arno Harden, Ashe Tanemura]
% Last updated: [8/12/2025]
% ------------------------------------------------------------------------------
   
function preserveParticleID (fileParams, verbose)
    
    % Path to the particle tracking results
    trackingResultsFile = fullfile(fileParams.topDir, 'canny_output', 'particle_tracking_results.mat');

    % Check if tracking results exist
    if ~exist(trackingResultsFile, 'file')
        error('Cannot find tracking results file: %s', trackingResultsFile);
    end
    
    % Load the tracking results
    if verbose
        disp('Loading tracking results...');
    end
    trackingData = load(trackingResultsFile);
    
    % Prepare new positions data with correct frame numbers
    if verbose
        disp('Creating particle_positions.txt with proper frame numbers...');
    end
    positions_data = [];

    % For each image
    for i = 1:length(trackingData.results.image_data)
        imgResult = trackingData.results.image_data{i};
        
        % Skip if the image has no data
        if isempty(imgResult)
            disp(['  Skipping image ' num2str(i) ' - no data']);
            continue;
        end
        
        % Get frame, particle IDs, and centers for this image
        frame = i;  % Frame is just the image index
        particleIds = imgResult.particle_ids;
        centers = imgResult.local_centers;
        edge_flags = imgResult.edge_flags;
        edge_angles = imgResult.edge_angles;
        
        % For each particle in this image
        for j = 1:length(particleIds)
            % Get the particle data
            if size(centers, 1) >= j
                % Get the global unique ID
                particleId = particleIds(j);

                % Get coordinates and radius
                x = centers(j, 1);
                y = centers(j, 2);
                
                if size(centers, 2) >= 3
                    r = centers(j, 3);
                else
                    r = 20; % Default radius if not available
                end
                
                edge = edge_flags(j);
                
                if ~isempty(edge_angles) && j <= size(edge_angles, 1)
                    angles = edge_angles(j, :);
                else
                    angles = [];
                end
        
                % Append as one row
                positions_data = [positions_data; frame, particleId, x, y, r, edge, angles];
            end
        end
    end
    
    % Save the consolidated file
    output_file = fullfile(fileParams.topDir, 'particle_positions.txt');
    
    
    % Back up any existing file
    if exist(output_file, 'file')
        backup_file = [output_file '.backup'];
        copyfile(output_file, backup_file);
        if verbose
            disp(['Backed up existing file to: ' backup_file]);
        end
    end
    
    % Write the new file
    writematrix(positions_data, output_file, 'Delimiter', ',');
    
    % Display statistics
    if verbose
        disp(['Created particle_positions.txt with ' num2str(size(positions_data, 1)) ' particles']);
        disp('Frame distribution:');
        for i = 1:max(positions_data(:,1))
            count = sum(positions_data(:,1) == i);
            disp(['  Frame ' num2str(i) ': ' num2str(count) ' particles']);
        end
    end
    
    % Display a preview of the data
    if verbose
        % disp('Preview of the first few rows:');
        % disp('Format: [frame, particleId, x, y, r, edge]');
        % disp(array2table(positions_data(1:min(10, size(positions_data, 1)), :), ...
        %      'VariableNames', {'Frame', 'ParticleID', 'X', 'Y', 'Radius', 'Edge'}));
        
        % Display usage instructions
        disp('To use this file with contactDetect:');
        disp('1. Make sure particle_positions.txt is in your topDir');
        disp('2. Run runCD2.m with the updated frame assignments');
        
        disp('Done! Now try running runCD2.m for contact detection.');
    end
end