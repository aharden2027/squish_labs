% particleDetect.m
% ------------------------------------------------------------------------------
% Detects circular particles across a grid of images using the Circular Hough Transform,
% with optional filtering, edge-contact classification, and angle recording.
%
% Main Function:
%   particleDetect(fileParams, pdParams, verbose)
%
% Description:
%   Iterates through a set of images (e.g., 'piece_row_col.png') and performs particle
%   detection using imfindcircles. Overlapping detections can be suppressed, edge-touching
%   particles can be removed, and in "particle" boundaryType mode, edges are detected by
%   identifying nearby black particles and computing their contact angles.
%
%   Supports three boundaryType modes:
%       - 'particle' : Detects red particles, finds adjacent black particles,
%                      assigns edge flags, and stores contact angles.
%       - 'image': Detects particles and classifies edges by image boundaries only.
%       - 'rectangle': Detects particles and classifies edges by the
%                      outermost detected particles
%
% INPUTS:
%   fileParams - Struct containing:
%       .topDir       : Root directory containing images and output folders
%       .imgDir       : Subdirectory containing input images
%       .particleDir  : Subdirectory for saving particle center outputs
%       .imgReg       : File pattern for matching images (e.g., '*.png')
%
%   pdParams - Struct containing detection parameters:
%       .radiusRange       : [minRadius, maxRadius] circle search range
%       .objectPolarity    : 'bright' or 'dark'
%       .sensitivity       : imfindcircles sensitivity (0-1)
%       .edgeThreshold     : Edge threshold for imfindcircles
%       .minCenterDistance : Minimum allowed center-to-center spacing
%       .tol               : Tolerance for overlap removal
%       .filter            : Logical flag to enable overlap filtering
%       .clean             : Logical flag to remove edge-touching particles
%       .dtol              : Distance tolerance for image-edge classification
%       .boundaryType      : 'particle' or 'image' or 'rectangle' mode
%
%   verbose - (Optional) Logical flag to enable detailed console output and
%             save annotated visualizations in a 'visualizations' folder.
%
% OUTPUT:
%   For each image, saves:
%       - '[image]_centers.txt': Detected particle positions, radii, edge flags,
%                                and (if applicable) contact angles in radians.
%       - 'particleDetect_params.txt': Parameters used during detection.
%       - '[image]_circles.png': Visualization of detected particles (if verbose).
%
% NOTES:
%   - In 'particle' mode, edge angles are stored as additional columns (NaN-padded).
%   - In 'rectangle' mode, edge flags use codes:
%         -1 (left), 1 (right), -2 (bottom), 2 (top), 0 (none).
%   - Black particle detection is based on median pixel intensity inside each circle.
%   - Assumes images have a red channel suitable for particle detection.
%
% DEPENDENCIES:
%   Requires Image Processing Toolbox (imfindcircles, viscircles).
%
% EXAMPLE USAGE:
%   fileParams.topDir = 'testdata';
%   fileParams.imgDir = 'images';
%   fileParams.particleDir = 'particles';
%   fileParams.imgReg = '*.png';
%   pdParams.radiusRange = [10, 30];
%   pdParams.objectPolarity = 'bright';
%   pdParams.sensitivity = 0.9;
%   pdParams.edgeThreshold = 0.1;
%   pdParams.minCenterDistance = 20;
%   pdParams.tol = 5;
%   pdParams.filter = true;
%   pdParams.clean = true;
%   pdParams.dtol = 10;
%   pdParams.boundaryType = 'particle';
%   particleDetect(fileParams, pdParams, true);
%
% Authors: [Vir Goyal, Arno Harden, Ashe Tanemura]
% Last updated: 2025-08-12
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
        %green = img(:,:,2); %photoelastic signal
        %red = imsubtract(red, green*0.05); %some green bleeds through, makes sharper red
        

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
    
        % If circles found, remove edge-touching particles and save results
        if ~isempty(centers) && isfield(pdParams, "clean") && pdParams.clean
             [imgHeight, imgWidth] = size(red);
             [centers, radii] = removeEdgeParticles(centers, radii, imgHeight, imgWidth, pdParams.dtol);
        end 
    
        % Initialize black particle detection
        if  ~isempty(centers) && isfield(pdParams, 'boundaryType ') && strcmp(pdParams.boundaryType, 'particle') 

            if verbose
                fprintf("  Black particle detection...\n")
            end

            [rows, cols] = size(red);
            [X, Y] = meshgrid(1:cols, 1:rows);
    
            keepMask = false(length(radii), 1);
            blackMask = false(length(radii), 1);
    
            for i = 1:length(radii)
                cx = centers(i,1);
                cy = centers(i,2);
                r = radii(i);
                circleMask = (X - cx).^2 + (Y - cy).^2 <= r^2;
                medVal = median(red(circleMask));
    
                if medVal <= 5
                    blackMask(i) = true;
                else
                    keepMask(i) = true;
                end
            end
    
            % Extract red (non-black) particles
            red_centers = centers(keepMask, :);
            red_radii   = radii(keepMask);

            % Extract black particles
            black_centers = centers(blackMask, :);
            black_radii   = radii(blackMask);
            
            % Variable reassignment 
            centers = red_centers;
            radii = red_radii;
        else
            black_centers = [];
            black_radii = [];
        end

        if verbose
            fprintf('  Detected %d particles.\n', numel(radii));
        end

        %% Particle Visualizations
        if verbose
            figure('Visible', 'off'); 
            redImg = imread(imgPath);
            if size(redImg,3) == 3
                redImg = redImg(:,:,1);
            end
            imshow(redImg);
            hold on;
        end
        
        %classify edge detecton based on touching black particles
        if ~isempty(centers) && strcmp(pdParams.boundaryType, 'particle')
            if verbose
                fprintf("  Detecting Particle Edges (particle)...\n")
            end

            contactBuffer = 20;
            scale = 100;
        
            numRed = size(centers,1);
            edges = zeros(numRed,1);
            edgeAnglesCell = cell(numRed,1);

            for i = 1:numRed
                c = centers(i, :);
                r = radii(i);
                
                delta = black_centers - c;
                dists = sqrt(sum(delta.^2, 2));
                touchingMask = dists <= (r + black_radii + contactBuffer);
                touchingBlack = black_centers(touchingMask, :);

                if isempty(touchingBlack)
                    edges(i) = 0;
                    edgeAnglesCell{i} = [];
                else
                    edges(i) = -1;
                    angles = zeros(size(touchingBlack,1),1);
                    for j = 1:size(touchingBlack,1)
                        vec = touchingBlack(j,:) - c;
                        angles(j) = atan2(vec(2), vec(1)); % radians
                        if verbose
                            normVec = vec / norm(vec);
                            quiver(c(1), c(2), scale*normVec(1), scale*normVec(2), 0, ...
                                'Color', 'm', 'LineWidth', 1);
                        end
                    end
                    edgeAnglesCell{i} = angles;
                end
            end
         else
                text(size(img,2)/2-100, size(img,1)/2, 'No circles detected', ...
                    'Color', 'red', 'FontSize', 14, 'BackgroundColor', 'black');
         end
   
        %classify edge particles based on image boundaries
        if ~isempty(centers) && strcmp(pdParams.boundaryType, 'image')
            if verbose
                fprintf("  Detecting Particle Edges (image)...\n")
            end

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
        end

        %classify edge particles (original)
        if ~isempty(centers) && pdParams.boundaryType == "rectangle"  
            if verbose
                fprintf("  Detecting Particle Edges (rectangle)...\n")
            end
            lpos = min(centers(:,1)-radii);
            rpos = max(centers(:,1)+radii);
            upos = max(centers(:,2)+radii);
            bpos = min(centers(:,2)-radii);
            lwi = centers(:,1)-radii <= lpos+pdParams.dtol;
            rwi = centers(:,1)+radii >= rpos-pdParams.dtol;
            uwi = centers(:,2)+radii >= upos-pdParams.dtol;
            bwi = centers(:,2)-radii <= bpos+pdParams.dtol; %need to add edge case of corner particle

            edges = zeros(length(radii), 1);
            edges(rwi) = 1; %right
            edges(lwi) = -1; %left
            edges(uwi) = 2;  %"upper" - as vertical pixels are backwards from cartesian, actually bottom of image
            edges(bwi) = -2; %"bottom" - see above comment
            %interior particles are 0
        end %for edge detection

        %% Saving ParticleData      
        if isfield(pdParams, 'boundaryType ') && strcmp(pdParams.boundaryType, 'particle')
            % ---- PARTICLE MODE: includes angles ----
            
            % Determine max number of angles
            maxAngles = max(cellfun(@numel, edgeAnglesCell));
            
            % Pad angles with NaN where missing
            anglesMatrix = NaN(size(centers,1), maxAngles);
            for i = 1:size(centers,1)
                angles = edgeAnglesCell{i};
                if ~isempty(angles)
                    angles = round(angles, 6);
                    anglesMatrix(i,1:numel(angles)) = angles(:)';
                end
            end
            
            % Combine all data
            particleData = [centers(:,1), centers(:,2), radii, edges, anglesMatrix];
            
        else
            % ---- DEFAULT MODE: no angles ----
            particleData = [centers(:,1), centers(:,2), radii, edges];
        end
        
        % Output paths
        [~, fileName, ~] = fileparts(imgPath);
        mainOutDir = fileParams.topDir;
        detectOutDir = fullfile(mainOutDir, fileParams.particleDir);
        if ~exist(mainOutDir, 'dir'), mkdir(mainOutDir); end
        if ~exist(detectOutDir, 'dir'), mkdir(detectOutDir); end
        
        % Save particle centers (and angles if particle mode)
        centersFileName = fullfile(detectOutDir, [fileName '_centers.txt']);
        writematrix(particleData, centersFileName, 'Delimiter', ',');
        if verbose
            disp(['  Centers data saved to: ' centersFileName]);
        end

       % Draw circles
       if verbose
            viscircles(centers(edges == 0, :), radii(edges == 0), 'EdgeColor', 'r');
            viscircles(centers(edges ~= 0, :), radii(edges ~= 0), 'EdgeColor', 'g');
        
            % Save visualization image
            visDir = fullfile(fileParams.topDir, 'visualizations');
            if ~exist(visDir, 'dir')
                mkdir(visDir);
            end
            saveas(gcf, fullfile(visDir, [baseName '_circles.png']));
            close(gcf);

            close all
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

function [filteredCenters, filteredRadii] = removeEdgeParticles(centers, radii, imgHeight, imgWidth, edgeBuffer)
    if nargin < 5
        edgeBuffer = 50; % default buffer if not specified
    end

    % Logical indices for particles touching or within edgeBuffer of each edge
    touchLeft   = (centers(:,1) - radii) <= edgeBuffer;
    touchRight  = (centers(:,1) + radii) >= (imgWidth - edgeBuffer);
    touchTop    = (centers(:,2) - radii) <= edgeBuffer;
    touchBottom = (centers(:,2) + radii) >= (imgHeight - edgeBuffer);

    % Combine all edge-touching conditions
    isEdgeParticle = touchLeft | touchRight | touchTop | touchBottom;

    % Filter out edge-touching particles
    filteredCenters = centers(~isEdgeParticle, :);
    filteredRadii = radii(~isEdgeParticle);
end
