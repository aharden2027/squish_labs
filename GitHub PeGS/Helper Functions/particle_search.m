%% particle_search.m
% -------------------------------------------------------------------------
% Searches through solved particle data files to find and display details
% for a specific particle ID.
%
% The script:
%   - Scans all solved particle MAT-files in the 'testdata/solved' directory.
%   - Loads the 'particle' variable from each file.
%   - Searches for the specified target particle ID.
%   - Prints all available data fields for that particle, formatting numbers
%     and matrices for readability.
%   - If available, displays the particle's force image as a grayscale figure.
%
% Usage:
%   Set 'targetID' near the top of the script to the particle you want to inspect.
%   Run the script to see detailed info printed to the command window and
%   visualized for force images.
%
% Notes:
%   - Designed for data structured as arrays of particle structs saved in MAT-files.
%   - Assumes solved files named like 'piece_*_*_solved.mat' in the 'testdata/solved' folder.
%
% Author: [ChatGPT]
% Date: 2025-08-01
% -------------------------------------------------------------------------

% Set the particle ID you want to inspect here:
targetID = 1206;

% Get all contact files in the 'contacts' or 'solved folder
fileList = dir('testdata/solved/piece_*_*_solved.mat');
numFiles = length(fileList);
files = fullfile({fileList.folder}, {fileList.name});

fprintf('Searching for particle ID %d in %d files...\n\n', targetID, numFiles);

for k = 1:numFiles
    filePath = files{k};

    % Load only the 'particle' field
    data = load(filePath, 'particle');

    if ~isfield(data, 'particle')
        fprintf('File: %s\n  No ''particle'' field found.\n\n', filePath);
        continue;
    end

    particle = data.particle;

    % Find the particle with the target ID
    idx = find([particle.id] == targetID, 1);

    if isempty(idx)
        fprintf('File: %s\n  Particle ID %d not found.\n\n', filePath, targetID);
    else
        p = particle(idx);

        fprintf('File: %s\n', filePath);
        fprintf('  Found particle ID %d\n', targetID);
        
        % Loop over all fields in the struct and print them
        fnames = fieldnames(p);
        for f = 1:length(fnames)
            field = fnames{f};
            value = p.(field);

            % Format based on data type
            if isnumeric(value)
                if isscalar(value)
                    fprintf('  %-14s = %.4f\n', field, value);
                elseif isvector(value)
                    fprintf('  %-14s = %s\n', field, mat2str(value(:)', 4));
                elseif ismatrix(value)
                    fprintf('  %-14s = matrix %dx%d\n', field, size(value, 1), size(value, 2));
                end
            elseif ischar(value)
                fprintf('  %-14s = %s\n', field, value);
            else
                fprintf('  %-14s = [unprintable datatype: %s]\n', field, class(value));
            end
        end
        % If forceImage field exists and is a 2D numeric array, show it
        if isfield(p, 'forceImage') && isnumeric(p.forceImage) && ndims(p.forceImage) == 2
            figure;
            imagesc(p.forceImage);
            axis image off;
            colormap('gray');
            title(sprintf('Force Image: %s', filePath), 'Interpreter', 'none');
            colorbar;
        end
        fprintf('\n');
    end
end
