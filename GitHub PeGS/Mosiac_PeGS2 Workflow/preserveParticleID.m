% preserveParticleID.m
% ------------------------------------------------------------
% This script consolidates particle tracking data from 
% canny_auto into a single file, particle_positions.txt, with
% consistent and accurate frame numbering.
%
% INPUT:
%   fileParams - Struct containing file system parameters,
%                including .topDir (root directory for data).
%
% FUNCTIONALITY:
%   - Loads particle tracking results from:
%       [fileParams.topDir]/canny_output/particle_tracking_results.mat
%   - Extracts particle positions, radii, edge flags, and global IDs.
%   - Assigns correct frame numbers based on image index.
%   - Outputs a consolidated file:
%       [fileParams.topDir]/particle_positions.txt
%   - Backs up existing particle_positions.txt if it exists.
%
% OUTPUT:
%   A new particle_positions.txt file containing:
%       [frame, particleId, x, y, r, edge]
%
% USAGE:
%   1. Ensure that canny_auto has been run and output exists.
%   2. Call preserveParticleID(fileParams).
%   3. Then run runCD2.m for contact detection using the generated file.
%
% NOTES:
%   - Default radius = 20 if not provided.
%   - Default edge flag = 0 if not provided.
%   - Backups are saved as particle_positions.txt.backup
%
% Author: [Vir Goyal, Arno Harden, Ashe Tanemura]
% Last updated: [6/20/2025]
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
        
        % For each particle in this image
        for j = 1:length(particleIds)
            % Get the particle data
            if size(centers, 1) >= j
                % Get coordinates and radius
                x = centers(j, 1);
                y = centers(j, 2);
                
                if size(centers, 2) >= 3
                    r = centers(j, 3);
                else
                    r = 20; % Default radius if not available
                end
                
                % Get edge flag if available, otherwise use 0
                if size(centers, 2) >= 4
                    edge = centers(j, 4);
                else
                    edge = 0;
                end
                
                % Get the global unique ID
                particleId = particleIds(j);
                
                % Add to positions data: [frame, particleId, x, y, r, edge]
                positions_data = [positions_data; frame, particleId, x, y, r, edge];
            end
        end
    end
    
    % Save the consolidated file
    base_dir = './testdata'; % Adjust if needed
    output_file = fullfile(base_dir, 'particle_positions.txt');
    
    
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
        disp('Preview of the first few rows:');
        disp('Format: [frame, particleId, x, y, r, edge]');
        disp(array2table(positions_data(1:min(10, size(positions_data, 1)), :), ...
            'VariableNames', {'Frame', 'ParticleID', 'X', 'Y', 'Radius', 'Edge'}));
        
        % Display usage instructions
        disp('To use this file with contactDetect:');
        disp('1. Make sure particle_positions.txt is in your topDir');
        disp('2. Run runCD2.m with the updated frame assignments');
        
        disp('Done! Now try running runCD2.m for contact detection.');
    end
end