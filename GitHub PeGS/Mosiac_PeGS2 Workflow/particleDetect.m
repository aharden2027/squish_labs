% particleDetect.m
% ------------------------------------------------------------------------------
% Detects circular particles across a grid of images using the Circular Hough Transform.
%
% Main Function:
%   particleDetect(fileParams, pdParams, verbose)
%
% Description:
%   Iterates through a grid of images (e.g., 'piece_row_col.png') and performs 
%   particle detection on each using circular Hough transform techniques.
%   Detected particles are filtered to remove overlaps and annotated if they 
%   touch image edges. Results are saved as center files for downstream analysis.
%
% INPUTS:
%   fileParams - Struct containing:
%       .topDir      : Root directory containing image and output folders
%       .imgDir      : Subdirectory under topDir containing input images
%       .imgReg      : Image filename wildcard (e.g., '*.png')
%       .particleDir : Subdirectory for saving particle center outputs
%
%   pdParams - Struct containing detection parameters:
%       .rows               : Number of rows in the image grid
%       .cols               : Number of columns in the image grid
%       .radiusRange        : Two-element vector specifying circle radius limits
%       .sensitivity        : imfindcircles sensitivity parameter (0-1)
%       .edgeThreshold      : Edge threshold for circle detection
%       .minCenterDistance  : Minimum distance between circle centers to avoid overlaps
%       .tol                : Tolerance for overlap suppression
%       .dtol               : Distance from edge to mark particle as on edge
%       .objectPolarity     : 'bright' or 'dark' for circle detection
%       .filter             : Logical, enables overlap and intensity-based filtering
%       .clean              : Logical, removes particles touching image edges
%       .showFigures        : (Optional) Unused; figures shown only if verbose is true
%
%   verbose   - (Optional, default: false) Logical flag to display progress, 
%               diagnostics, and save visualizations.
%
% OUTPUT:
%   For each image, saves:
%       - '[piece_row_col]_centers.txt': [X, Y, Radius, EdgeCode] of each particle
%       - 'particleDetect_params.txt'  : Log of parameters used for detection
%
% NOTES:
%   - Edge codes: -1 = left, 1 = right, -2 = bottom, 2 = top, 0 = not on edge
%   - Image names must follow the pattern 'piece_ROW_COL.png'
%   - Visualizations are saved only if verbose = true
%
% DEPENDENCIES:
%   Requires Image Processing Toolbox for imfindcircles and viscircles.
%
% EXAMPLE USAGE:
%   fileParams.topDir = 'testdata';
%   fileParams.imgDir = 'images';
%   fileParams.imgReg = '*.png';
%   fileParams.particleDir = 'particles';
%   pdParams.rows = 3;
%   pdParams.cols = 3;
%   pdParams.radiusRange = [10, 30];
%   pdParams.sensitivity = 0.9;
%   pdParams.edgeThreshold = 0.1;
%   pdParams.minCenterDistance = 20;
%   pdParams.tol = 5;
%   pdParams.dtol = 5;
%   pdParams.objectPolarity = 'bright';
%   pdParams.filter = true;
%   pdParams.clean = true;
%   verbose = true;
%   particleDetect(fileParams, pdParams, verbose);
%
% Authors: [Vir Goyal, Arno Harden, Ashe Tanemura]
% Last updated: [8/1/2025]
% ------------------------------------------------------------------------------
function particleDetect(fileParams, pdParams, verbose)
    
    if nargin < 3
        verbose = false;
    end

    images = dir(fullfile(fileParams.topDir, fileParams.imgDir, fileParams.imgReg));
    nFrames = length(images);

    if isempty(images)
        error('No image files found.');
    end

    for frame = 1:nFrames
        imgPath = fullfile(images(frame).folder, images(frame).name);

        % Extract just the filename with extension
        [~, baseName, ~] = fileparts(imgPath);

        if verbose 
            fprintf('Processing image %d/%d: %s\n', frame, nFrames, images(frame).name);
        end

        % Read image
        img = imread(imgPath);

        %Extract red channel for particle detection
        red = img(:,:,1);
        % green = img(:,:,2); %photoelastic signal
        % red = imsubtract(red, green*0.05); %some green bleeds through, makes sharper red
        
        % Detect circles
        if verbose
            fprintf('  Running imfindcircles...\n')
        end
        [centers, radii, ~] = imfindcircles(red, pdParams.radiusRange, ...
            'ObjectPolarity', pdParams.objectPolarity, ...
            'Sensitivity', pdParams.sensitivity, ...
            'EdgeThreshold', pdParams.edgeThreshold);

        %Filter overlapping circles
        if pdParams.filter && ~isempty(centers)
            
            originalCount = size(centers, 1);
            keepCircles = true(originalCount, 1);
    
            i = 1;
            while i <= originalCount
                if keepCircles(i)
                    j = i + 1;
                    while j <= originalCount
                        if keepCircles(j)
                            dist = norm(centers(i,:) - centers(j,:));
                            radii_sum = radii(i) + radii(j);
                            if dist < pdParams.minCenterDistance
                                if dist < (radii_sum - pdParams.tol)
                                    keepCircles(j) = false; % Remove overlapping circle
                                end
                            end
                        end
                        j = j + 1;
                    end
                end
                i = i + 1;
            end
    
            centers = centers(keepCircles, :);
            radii = radii(keepCircles);
            numRemoved = originalCount - size(centers, 1);
            if numRemoved > 0 && verbose
               disp(['  Removed ' num2str(numRemoved) ' overlapping circles.']);
            end
        end
        
        % Additional Edge Particle Filtering
        if pdParams.filter && ~isempty(centers)
            [rows, cols] = size(red);
            [X, Y] = meshgrid(1:cols, 1:rows);
        
            % Initialize mask of which circles to keep based on mean pixel
            % value
            keepMask = false(length(radii), 1);
            
            if verbose
                fprintf("  Additional Image Filtering...\n")
            end
    
            for i = 1:length(radii)
                cx = centers(i,1);
                cy = centers(i,2);
                r = radii(i);
                circleMask = (X - cx).^2 + (Y - cy).^2 <= r^2;
                meanVal = mean(red(circleMask));
                if meanVal < 250 %Change value for whatever color edge particles are
                    keepMask(i) = true;
                end
            end
    
            centers = centers(keepMask, :);
            radii   = radii(keepMask);
        end
    
        if ~isempty(centers)
            % Extract image dimensions
            [imgHeight, imgWidth] = size(red);
            dtol = pdParams.dtol;  % Edge buffer distance in pixels
        
            % Identify which circles are touching image edges
            lwi = centers(:,1) - radii <= dtol;                  % left edge
            rwi = centers(:,1) + radii >= imgWidth - dtol;       % right edge
            uwi = centers(:,2) - radii <= dtol;                  % top edge (row 0)
            bwi = centers(:,2) + radii >= imgHeight - dtol;      % bottom edge
        
            % Assign edge flags
            edges = zeros(length(radii), 1);
            edges(rwi) = 1;    % right
            edges(lwi) = -1;   % left
            edges(uwi) = 2;    % top (Y=0)
            edges(bwi) = -2;   % bottom
        
            % Combine into particleData
            particleData = [centers(:,1), centers(:,2), radii, edges];
        
            % If cleaning is enabled, remove particles touching edges
            if isfield(pdParams, "clean") && pdParams.clean
                keepMask = edges == 0;
                particleData = particleData(keepMask, :);
                centers = centers(keepMask, :);
                radii   = radii(keepMask);
                if verbose
                    fprintf('  Removed %d edge particles (clean=true).\n', sum(~keepMask));
                end
            end

            [~, fileName, ~] = fileparts(imgPath);
            mainOutDir = fileParams.topDir;
            detectOutDir = fullfile(mainOutDir, fileParams.particleDir);
    
            % Create directories if needed
            if ~exist(mainOutDir, 'dir'), mkdir(mainOutDir); end
            if ~exist(detectOutDir, 'dir'), mkdir(detectOutDir); end
    
            % Save particle centers
            centersFileName = fullfile(detectOutDir, [fileName '_centers.txt']);
            writematrix(particleData, centersFileName, 'Delimiter', ',');
            if verbose
                disp(['  Centers data saved to: ' centersFileName]);
            end
        else
            text(size(img,2)/2-100, size(img,1)/2, 'No circles detected', ...
                'Color', 'red', 'FontSize', 14, 'BackgroundColor', 'black');
        end

        %display circles
        if verbose
            % Create hidden figure for saving
            fig = figure('Visible', 'off');
            imshow(red);
            hold on;
            viscircles(centers, radii, 'EdgeColor', 'b');
            hold off;
        
            % Resize for high-res output
            fig.Position(3:4) = [1200, 1200];
        
            % Create the visualizations folder
            vizFolder = fullfile(mainOutDir, fileParams.particleDir, 'visualizations');
            if ~exist(vizFolder, 'dir')
                mkdir(vizFolder);
            end
        
            % Extract base name of original image
            [~, baseName, ~] = fileparts(imgPath);
            savePath = fullfile(vizFolder, [baseName '_circlesOnly.png']);
        
            % Save as high-resolution PNG
            print(fig, savePath, '-dpng', '-r300');
        
            % Close the hidden figure
            close(fig);
        end
    end
    
    % Display used parameters
    if verbose
        disp('Parameters used:');
        disp(['  Radius Range: [' num2str(pdParams.radiusRange(1)) ', ' num2str(pdParams.radiusRange(2)) ']']);
        disp(['  Sensitivity: ' num2str(pdParams.sensitivity)]);
        disp(['  Edge Threshold: ' num2str(pdParams.edgeThreshold)]);
        disp(['  Minimum Center Distance: ' num2str(pdParams.minCenterDistance)]);
        disp(['  Tolerance: ' num2str(pdParams.tol)]);
    end

    %% saving parameters in and finishing module
    fields = fieldnames(pdParams);
    for i = 1:length(fields)
        fileParams.(fields{i}) = pdParams.(fields{i});
    end
    
    fileParams.lastimagename=images(frame).name;
    fileParams.time = datetime("now");
    fields = fieldnames(fileParams);
    C=struct2cell(fileParams);
    pdParams = [fields C];
    writecell(pdParams,fullfile(fileParams.topDir, fileParams.particleDir,'particleDetect_params.txt'),'Delimiter','tab')
    if verbose
        disp(['Parameters saved to: ' fullfile(fileParams.topDir, fileParams.particleDir,'particleDetect_params.txt')]);
    end
end