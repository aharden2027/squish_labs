% imfindcircles testing (for black edges)
% This is a working version of an updated edge detection method that needs
% to detect black edge particles

%% File Parameters
fileParams = struct();
fileParams.topDir      = 'testdata';    % project root (current folder)
fileParams.imgDir      = 'images';      % folder with piece_*.png
fileParams.imgReg      = 'piece_0_0.png'; % glob for images
fileParams.particleDir = 'particles';   % centres from particleDetect_AA
fileParams.cannyDir    = 'canny_output';% outputs from canny_auto
fileParams.contactDir  = 'contacts';    % where contact files go
fileParams.solvedDir   = 'solved';      % output directory for solved force information

%% Particle Detect Parameters
pdParams = struct();
pdParams.rows = rows;
pdParams.cols = cols;
pdParams.radiusRange        = [175 305];
pdParams.objectPolarity     = 'dark';
pdParams.sensitivity        = 0.985;
pdParams.edgeThreshold      = 0.05;
pdParams.minCenterDistance  = 250;
pdParams.dtol               = 30;
pdParams.tol                = 50;
pdParams.filter             = true;
pdParams.showFigures        = true;
pdParams.clean              = true;

% Run test on all images
test_imfindcircles(fileParams, pdParams, true)

function test_imfindcircles(fileParams, pdParams, verbose)
    images = dir(fullfile(fileParams.topDir, fileParams.imgDir, fileParams.imgReg));
    nFrames = length(images);

    if isempty(images)
        error('No image files found.');
    end

    for frame = 1:nFrames
        imgPath = fullfile(images(frame).folder, images(frame).name);

        if verbose 
            fprintf('Processing image %d/%d: %s\n', frame, nFrames, images(frame).name);
        end

        % Read image
        img = imread(imgPath);

        %Extract red channel for particle detection
        red = img(:,:,1);
        green = img(:,:,2); %photoelastic signal
        red = imsubtract(red, green*0.05); %some green bleeds through, makes sharper red

        [imgHeight, imgWidth] = size(red);
        
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
             [centers, radii] = removeEdgeParticles(centers, radii, imgHeight, imgWidth, pdParams.dtol);
        end 

        if pdParams.filter && ~isempty(centers)
            [rows, cols] = size(red);
            [X, Y] = meshgrid(1:cols, 1:rows);
        
            % Initialize masks
            keepMask = false(length(radii), 1);  % for valid particles
            blackMask = false(length(radii), 1); % for black particles
        
            % Initialize black particle arrays
            black_particle_centers = [];
            black_particle_radii   = [];
        
            if verbose
                fprintf("  Additional Image Filtering...\n")
            end
        
            for i = 1:length(radii)
                cx = centers(i,1);
                cy = centers(i,2);
                r = radii(i);
                circleMask = (X - cx).^2 + (Y - cy).^2 <= r^2;
                medVal = median(red(circleMask));
        
                if medVal <= 5  % black particle: very low intensity
                    blackMask(i) = true;
                else  % keep only if it's not black and not too bright (e.g., edge artifact)
                    keepMask(i) = true;
                end
            end
        
            % Extract black particles
            black_particle_centers = centers(blackMask, :);
            black_particle_radii   = radii(blackMask);
        
            % Keep only the valid (non-black, non-edge) particles
            centers = centers(keepMask, :);
            radii   = radii(keepMask);
        end
        
        % % % Initialize true edge particle arrays
        % true_edge_centers = [];
        % true_edge_radii   = [];
        % 
        % % Loop through each black particle
        % if ~ isempty(black_particle_centers)
        %     for i = 1:size(black_particle_centers, 1)
        %         black_center = black_particle_centers(i, :);
        %         black_radius = black_particle_radii(i);
        % 
        %         % Compute distances from black particle to all non-black particle centers
        %         delta = centers - black_center;  % vector difference
        %         center_distances = sqrt(sum(delta.^2, 2));
        % 
        %         % Compute edge-to-edge distances
        %         edge_distances = center_distances - radii;
        % 
        %         % Find where edge distance is <= black_radius + 20
        %         nearbyMask = edge_distances <= (black_radius + 20);
        % 
        %         % Append matching particles
        %         true_edge_centers = [true_edge_centers; centers(nearbyMask, :)];
        %         true_edge_radii   = [true_edge_radii;   radii(nearbyMask)];
        %     end
        % end
        % 

        % Remove duplicates
        % [unique_centers, ia, ~] = unique(true_edge_centers, 'rows');
        % true_edge_centers = unique_centers;
        % true_edge_radii   = true_edge_radii(ia);
        % fprintf("  Number of true edge particles: %d\n", size(true_edge_centers, 1));

        particleData = assignTrueEdgeFlags(centers, radii, black_particle_centers, black_particle_radii, imgHeight, imgWidth);
        
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

        imshow(red); hold on;
        
        % Non-edge particles in red
        nonEdgeIdx = particleData(:,4) == 0;
        viscircles(particleData(nonEdgeIdx,1:2), particleData(nonEdgeIdx,3), 'EdgeColor', 'r');
        
        % Right edge (1) - green
        rightIdx = particleData(:,4) == 1;
        viscircles(particleData(rightIdx,1:2), particleData(rightIdx,3), 'EdgeColor', 'g', 'LineWidth', 1.5);
        
        % Left edge (-1) - blue
        leftIdx = particleData(:,4) == -1;
        viscircles(particleData(leftIdx,1:2), particleData(leftIdx,3), 'EdgeColor', 'b', 'LineWidth', 1.5);
        
        % Top edge (2) - yellow
        topIdx = particleData(:,4) == 2;
        viscircles(particleData(topIdx,1:2), particleData(topIdx,3), 'EdgeColor', 'y', 'LineWidth', 1.5);
        
        % Bottom edge (-2) - black
        bottomIdx = particleData(:,4) == -2;
        viscircles(particleData(bottomIdx,1:2), particleData(bottomIdx,3), 'EdgeColor', 'k', 'LineWidth', 1.5);
        
        hold off;


        % if verbose
        %     figure; 
        %     subplot(1, 2, 1); imshow(red); title('Original Image');
        %     subplot(1, 2, 2); imshow(red); 
        %     title(['Detected: ' num2str(size(centers, 1)) ' circles']);
        %     viscircles(centers, radii, 'EdgeColor', "b");
        %     viscircles(black_particle_centers, black_particle_radii, 'EdgeColor', "r");
        %     viscircles(true_edge_centers, true_edge_radii,'EdgeColor', "g");
        % end

    end
end

function [filteredCenters, filteredRadii] = removeEdgeParticles(centers, radii, imgHeight, imgWidth, edgeBuffer)
    % removeEdgeParticles
    % Removes particles touching or within edgeBuffer pixels of the image edges.
    %
    % Inputs:
    %   centers    - Nx2 array of particle centers [x, y]
    %   radii      - Nx1 vector of particle radii
    %   imgHeight  - height of the image (number of rows)
    %   imgWidth   - width of the image (number of columns)
    %   edgeBuffer - scalar, distance in pixels from edge within which particles are removed
    %
    % Outputs:
    %   filteredCenters - filtered centers after removing edge-touching particles
    %   filteredRadii  - filtered radii after removing edge-touching particles

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

function particleData = assignTrueEdgeFlags(centers, radii, black_particle_centers, black_particle_radii, imgHeight, imgWidth)

    % Initialize all edge flags to zero
    edgeFlagsFull = zeros(size(centers,1),1);

    if isempty(black_particle_centers)
        % No black particles, so no true edges, return all zeros for edgeFlag
        particleData = [centers, radii, edgeFlagsFull];
        return
    end

    true_edge_centers = [];
    true_edge_radii = [];
    true_edge_flags = [];

    % Loop through each black particle to find true edge particles and assign flags
    for i = 1:size(black_particle_centers, 1)
        black_center = black_particle_centers(i, :);
        black_radius = black_particle_radii(i);

        delta = centers - black_center;
        center_distances = sqrt(sum(delta.^2, 2));
        edge_distances = center_distances - radii;

        nearbyMask = edge_distances <= (black_radius + 20);
        nearby_centers = centers(nearbyMask, :);
        nearby_radii = radii(nearbyMask);

        % Determine closest image edge to black particle
        distLeft = black_center(1);
        distRight = imgWidth - black_center(1);
        distTop = black_center(2);
        distBottom = imgHeight - black_center(2);
        [~, minIdx] = min([distLeft, distRight, distTop, distBottom]);

        switch minIdx
            case 1
                edgeFlag = -1; % Left edge
            case 2
                edgeFlag = 1;  % Right edge
            case 3
                edgeFlag = 2;  % Top edge
            case 4
                edgeFlag = -2; % Bottom edge
        end

        true_edge_centers = [true_edge_centers; nearby_centers];
        true_edge_radii = [true_edge_radii; nearby_radii];
        true_edge_flags = [true_edge_flags; repmat(edgeFlag, sum(nearbyMask), 1)];
    end

    % Remove duplicates among true edge particles
    [unique_centers, ia, ~] = unique(true_edge_centers, 'rows', 'stable');
    unique_flags = true_edge_flags(ia);

    % Match unique true edge particles back to full centers array and assign flags
    tol = 1e-6; % Tolerance for matching centers
    for j = 1:size(unique_centers,1)
        dx = centers(:,1) - unique_centers(j,1);
        dy = centers(:,2) - unique_centers(j,2);
        dist = sqrt(dx.^2 + dy.^2);

        matchIdx = find(dist < tol, 1);
        if ~isempty(matchIdx)
            edgeFlagsFull(matchIdx) = unique_flags(j);
        else
            warning('True edge particle not found in centers: (%.2f, %.2f)', unique_centers(j,1), unique_centers(j,2));
        end
    end

    % Output full particle data with edge flags
    particleData = [centers, radii, edgeFlagsFull];
end




