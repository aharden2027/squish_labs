% canny_auto.m
% -----------------------------------------------------------------------------
% Automatically detects and tracks particles across a grid of images.
%
% This script builds on prior versions of manual particle matching to:
%   1. Align a grid of images using normalized cross-correlation.
%   2. Transform all local particle centers into a unified global coordinate system.
%   3. Identify particles that appear in multiple images and assign unique global IDs.
%   4. Save particle tracking results as a .mat file and a summary .csv file.
%   5. Optionally generate visualizations showing particle distributions and overlaps.
%
% INPUTS:
%   fileParams - Struct with:
%       .topDir : Path to the top-level directory (contains 'images' and 'particles')
%
%   caParams - Struct with:
%       .rows               : Number of rows in the image grid
%       .cols               : Number of columns in the image grid
%       .distanceThreshold  : Pixel distance threshold for considering two particles the same
%       .displayFigures     : (bool) Whether to display debugging/summary figures
%       .debugMode          : (bool) Verbose output for debugging
%       .visualizeParticles : (bool) Whether to generate visualizations per image
%
% OUTPUTS:
%   Writes results to the 'canny_output' subfolder within fileParams.topDir:
%       - particle_tracking_results.mat : All particle positions, radii, edges, edge_angles, and metadata
%       - particle_tracking_summary.csv : Tabular summary of particles and appearances
%       - (Optional) Visualizations of particle maps and annotated images
%
% FILE NAMING CONVENTIONS:
%   Image files should be named:       'piece_ROW_COL.png'
%   Particle center files should be:   'piece_ROW_COL_centers.txt'
%   (Zero-based indexing is used for filenames, e.g., piece_0_0.png)
%
% EXAMPLE USAGE:
%   fileParams.topDir = 'testdata';
%   caParams.rows = 3;
%   caParams.cols = 3;
%   caParams.distanceThreshold = 30;
%   caParams.displayFigures = true;
%   caParams.debugMode = false;
%   caParams.visualizeParticles = true;
%   canny_auto(fileParams, caParams);
%
% DEPENDENCIES:
%   Requires Image Processing Toolbox for `normxcorr2`.
%   Visualization depends on standard MATLAB plotting functions.
%
% Authors: [Vir Goyal, Arno Harden, Ashe Tanemura]
% Last updated: [8/12/2025]
% -----------------------------------------------------------------------------

function canny_auto(fileParams, caParams, verbose)
    
    if nargin < 3
        verbose = false;
    end

    %% Step 1: Hardcoded loading of images and particle center files
    
    % Initialize arrays to store data
    catotal_images = caParams.rows * caParams.cols;
    all_images = cell(catotal_images, 1);
    all_centers = cell(catotal_images, 1);
    img_positions = zeros(catotal_images, 2); % [row, col] positions in the grid
    
    % Mapping for image positions using 0-based indexing from your file structure
    % Format: particles_row_col
    for row = 0:(caParams.rows-1)
        for col = 0:(caParams.cols-1)
            % Convert to 1-based indexing for MATLAB arrays
            idx = row*caParams.cols + col + 1;
            
            % Create folder path based on your file structure using fileParams
            image_folder = fullfile(fileParams.topDir, 'images');
            particles_folder = fullfile(fileParams.topDir, 'particles');
            
            % Construct file names
            img_file = sprintf('piece_%d_%d.png', row, col);
            img_path = fullfile(image_folder, img_file);
            
            center_file = sprintf('piece_%d_%d_centers.txt', row, col);
            center_path = fullfile(particles_folder, center_file);

            % Check if files exist
            if ~exist(img_path, 'file')
                warning('Image file not found: %s', img_path);
                % Use a blank image as placeholder
                all_images{idx} = zeros(1000, 1000, 3, 'uint8');
            else
                all_images{idx} = imread(img_path);
            end
            
            if ~exist(center_path, 'file')
                warning('Center file not found: %s', center_path);
                all_centers{idx} = [];
            else
                all_centers{idx} = load(center_path);
            end
            
            % Store the grid position (using 1-based indexing)
            img_positions(idx,:) = [row+1, col+1];
            
            if verbose
                fprintf('Loaded %s and %s\n', img_file, center_file);
            end   
        end
    end
    
    %% Step 2: Automatic Offset Detection using normxcorr2
    % 3 adjacent images for automatic matching
    % We'll use R0,C0 and R0,C1 and R1,C0

    % First image (R0,C0)
    img1 = imread('testdata/images/piece_0_0.png');
    red1 = img1(:,:,1);
    green1 = img1(:,:,2);
    red1 = imsubtract(red1, green1*0.05);
    template = double(red1);
    
    % Second image (R0,C1)
    if caParams.cols > 1
       img2 = imread('testdata/images/piece_3_3.png'); 
       red2 = img2(:,:,1);
       green2 = img2(:,:,2);
       red2 = imsubtract(red2, green2*0.05);
       imageh = double(red2(:,:,1));
    end
    
    % Third image (R1,C0)
    if caParams.rows > 1
        img3 = imread('testdata/images/piece_4_2.png'); 
        red3 = img3(:,:,1);
        green3 = img3(:,:,2);
        red3 = imsubtract(red3, green3*0.05);
        imagev = double(red3);
    end

    % Compute normalized cross-correlation (horizontal)
    % Includes logic to ensure normxcorr2 runs as piece_0_0 must be a smaller or equal sized image to its neighbors
    % Creates row vectors for the offset of the images
    if caParams.cols > 1
        if verbose
            fprintf('Detecting horizontal offset using normxcorr2... \n');
        end
        if size(imageh) >= size(template)
            C_h = normxcorr2 (template, imageh);
            [max_corr, idx] = max(C_h(:));
            [yh_peak, xh_peak] = ind2sub(size(C_h), idx);
            h_offset = [size(template,2) - xh_peak, size(template,1) - yh_peak];
        else 
            C_h = normxcorr2 (imageh, template);
            [max_corr, idx] = max(C_h(:));
            [yh_peak, xh_peak] = ind2sub(size(C_h), idx);
            h_offset = (-1)*[size(template,2) - xh_peak, size(template,1) - yh_peak];
        end
    else
        h_offset = [0, 0]; % If it's a single column of images
    end

    % Computer normalized cross-correlation (vertical)
    % Includes logic to ensure normxcorr2 runs as piece_0_0 must be a smaller or equal sized image to its neighbors
    % Creates row vectors for the offset of the images
    if caParams.rows > 1
        if verbose
            fprintf('Detecting vertical offset using normxcorr2... \n');
        end
        if size(imagev) >= size(template)
            C_v = normxcorr2 (template, imagev);
            [max_corr, idx] = max(C_v(:));
            [yv_peak, xv_peak] = ind2sub(size(C_v), idx);
            v_offset = [size(template,2) - xv_peak, size(template,1) - yv_peak];
        else
            C_v = normxcorr2 (imagev, template);
            [max_corr, idx] = max(C_v(:));
            [yv_peak, xv_peak] = ind2sub(size(C_v), idx);
            v_offset = (-1)*[size(template,2) - xv_peak, size(template,1) - yv_peak];
        end
    else
        v_offset = [0,0]; % If it's a single row of images
    end

    
    %% Step 3: Transform all particle centers to a global coordinate system
    if verbose
        fprintf('\n--- Global Coordinate Transformation ---\n');
        fprintf('Using horizontal offset: X = %.2f, Y = %.2f\n', h_offset(1), h_offset(2));
        fprintf('Using vertical offset:   X = %.2f, Y = %.2f\n', v_offset(1), v_offset(2));
    end
    % Initialize cell array for global positions
    global_centers = cell(catotal_images, 1);
    
    for i = 1:catotal_images
        % Get image position in grid (1-based indexing)
        row = img_positions(i, 1);
        col = img_positions(i, 2);
        
        % Get local centers for this image
        local_centers = all_centers{i};
        
        if isempty(local_centers)
            global_centers{i} = [];
            continue;
        end
        
        % Initialize output matrix with (x, y, radius)
        global_centers{i} = zeros(size(local_centers, 1), 3);
        
        % Copy radius values if available, otherwise assign default
        if size(local_centers, 2) >= 3
            global_centers{i}(:, 3) = local_centers(:, 3);
        else
            global_centers{i}(:, 3) = 5;  % Default radius
        end

        %% Additions to Canny (Monday August 11th)
        % Copy edge flag if available (4th column)
        if size(local_centers, 2) >= 4
            global_edge{i} = local_centers(:, 4);
        else
            global_edge{i} = zeros(size(local_centers, 1), 1); % default no edge
        end
        
        % Copy edgeAngles (5th column onwards) as cell array, since variable length
        if size(local_centers, 2) > 4
            global_edgeAngles{i} = local_centers(:, 5:end);
        else
            global_edgeAngles{i} = [];
        end
    
        % Compute cumulative offset from reference image (row=1, col=1)
        cumulative_offset = ...
            (col - 1) * h_offset + ...
            (row - 1) * v_offset;
     
        % Apply offset — ADD local coordinates to get global positions
        global_centers{i}(:, 1:2) = local_centers(:, 1:2) + cumulative_offset;
        
        % Debug log
        if verbose
            fprintf('Image %d (R%d,C%d): Applied offset [%.1f, %.1f]\n', ...
                i, row-1, col-1, cumulative_offset(1), cumulative_offset(2));
        end
    end
    
    %% Step 4: Identify unique particles and assign IDs
    % Combine all centers into a single list
    all_global_centers = [];
    img_indices = [];
    
    for i = 1:catotal_images
        centers = global_centers{i};
        if ~isempty(centers)
            all_global_centers = [all_global_centers; centers(:, 1:2)];
            img_indices = [img_indices; i * ones(size(centers, 1), 1)];
        end
    end
    
    % Initialize particle IDs and occurrence counts
    unique_id = 0;
    particle_ids = zeros(size(all_global_centers, 1), 1);
    particle_appearances = cell(1000, 1);  % Pre-allocate for efficiency
    
    % Adjust the distance threshold based on your observations
    % If particles aren't being matched, increase this value
    if verbose
        fprintf('Using distance threshold: %.2f pixels\n', caParams.distanceThreshold);
    end

    % Process each particle
    for i = 1:size(all_global_centers, 1)
        % Skip particles that already have IDs
        if particle_ids(i) > 0
            continue;
        end
        
        % Assign a new unique ID
        unique_id = unique_id + 1;
        particle_ids(i) = unique_id;
        
        % Record which image this particle appears in
        appearances = img_indices(i);
        
        % Find all instances of this particle in other images
        for j = (i+1):size(all_global_centers, 1)
            % Skip particles that already have IDs
            if particle_ids(j) > 0
                continue;
            end
            
            % Only match particles from different images
            if img_indices(i) == img_indices(j)
                continue;
            end
            
            % Calculate distance between particles
            dist = sqrt(sum((all_global_centers(i,:) - all_global_centers(j,:)).^2));
            
            % If close enough, consider as the same particle
            if dist < caParams.distanceThreshold
                particle_ids(j) = unique_id;
                appearances = [appearances; img_indices(j)];
                
                if exist('DEBUG_MODE', 'var') && caParams.debugMode
                    % Display matching information for debugging
                    fprintf('Particle %d in image %d matches with particle in image %d (distance: %.2f)\n', ...
                        i, img_indices(i), img_indices(j), dist);
                end
            end
        end
        
        % Store the list of images where this particle appears
        particle_appearances{unique_id} = unique(appearances);
    end
    
    % Trim cell array to actual size
    particle_appearances = particle_appearances(1:unique_id);
    
    % If in debug mode, display some statistics about particle matching
    if caParams.debugMode
        % Count particles by number of occurrences
        occurrence_counts = cellfun(@length, particle_appearances);
        
        fprintf('\nParticle Matching Statistics:\n');
        fprintf('Total unique particles: %d\n', unique_id);
        fprintf('Particles appearing in only 1 image: %d (%.1f%%)\n', ...
            sum(occurrence_counts == 1), 100*sum(occurrence_counts == 1)/unique_id);
        fprintf('Particles appearing in 2 images: %d (%.1f%%)\n', ...
            sum(occurrence_counts == 2), 100*sum(occurrence_counts == 2)/unique_id);
        fprintf('Particles appearing in 3 images: %d (%.1f%%)\n', ...
            sum(occurrence_counts == 3), 100*sum(occurrence_counts == 3)/unique_id);
        fprintf('Particles appearing in 4+ images: %d (%.1f%%)\n', ...
            sum(occurrence_counts >= 4), 100*sum(occurrence_counts >= 4)/unique_id);
        
        % Show some examples of multi-image particles
        multi_image_ids = find(occurrence_counts > 1);
        if ~isempty(multi_image_ids)
            fprintf('\nExamples of particles appearing in multiple images:\n');
            for i = 1:min(5, length(multi_image_ids))
                id = multi_image_ids(i);
                fprintf('Particle ID %d appears in images: %s\n', ...
                    id, sprintf('%d ', particle_appearances{id}));
            end
        end
    end


    %% Step 5: Organize results by image
    % Create a structure to store the results
    results = struct();
    results.total_unique_particles = unique_id;
    results.image_data = cell(catotal_images, 1);
    
    for i = 1:catotal_images
        % Get indices for particles in this image
        idx = (img_indices == i);
        
        % Get the original centers
        original_centers = all_centers{i};
        
        % Get the global positions and IDs for this image
        global_pos = all_global_centers(idx, :);
        ids = particle_ids(idx);
        
        %% Changed from Canny (Aug 11)
        % Get the edge flags and edge angles for particles in this image
        edge_flags = global_edge{i};            % assuming global_edge is cell array per image
        edge_angles = global_edgeAngles{i};     % same assumption for edge angles
        
        % Create a results structure for this image
        img_result = struct();
        img_result.row = img_positions(i, 1);
        img_result.col = img_positions(i, 2);
        img_result.local_centers = original_centers;
        img_result.global_centers = global_pos;
        img_result.particle_ids = ids;

        %% Changed from Canny (Aug 11)
        img_result.edge_flags = edge_flags;
        img_result.edge_angles = edge_angles;

        % Count unique particles in this image
        img_result.unique_particle_count = length(unique(ids));
        
        % Store in the results structure
        results.image_data{i} = img_result;
    end
    
    %% Step 6: Visualize the results
    % Create a figure showing all particles in global coordinates
    if verbose
        figure('Position', [100 100 1200 800]);
        
        % Create a colormap for particles based on their IDs
        cmap = hsv(unique_id);  % Create colormap with unique_id colors
        
        % Plot all particles in global space
        hold on;
        grid on;
        for i = 1:unique_id
            % Find all particles with this ID
            idx = (particle_ids == i);
            
            % Plot these particles with a unique color
            scatter(all_global_centers(idx, 1), all_global_centers(idx, 2), 50, ...
                'MarkerFaceColor', cmap(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
            
            % Label with ID for a random instance of this particle
            positions = all_global_centers(idx, :);
            if ~isempty(positions)
                midpoint = round(size(positions, 1)/2);
                text(positions(midpoint, 1), positions(midpoint, 2), num2str(i), ...
                    'FontSize', 8, 'HorizontalAlignment', 'center');
            end
        end
        
        % Add image boundaries
        for i = 1:catotal_images
            row = img_positions(i, 1);
            col = img_positions(i, 2);
            
            % Calculate image position in global coordinates
            img_size = size(all_images{i});
            
            % Calculate cumulative offset
            cumulative_offset = [0, 0];
            
            % Apply horizontal offsets
            cumulative_offset(1) = cumulative_offset(1) + (col-1) * h_offset(1);
            cumulative_offset(2) = cumulative_offset(2) + (col-1) * h_offset(2);
           
            % Apply vertical offsets
            cumulative_offset(1) = cumulative_offset(1) + (row-1) * v_offset(1);
            cumulative_offset(2) = cumulative_offset(2) + (row-1) * v_offset(2);
            
            
            % Calculate corner points
            corners = [
                cumulative_offset(1), cumulative_offset(2);  % Top-left
                cumulative_offset(1) + img_size(2), cumulative_offset(2);  % Top-right
                cumulative_offset(1) + img_size(2), cumulative_offset(2) + img_size(1);  % Bottom-right
                cumulative_offset(1), cumulative_offset(2) + img_size(1);  % Bottom-left
                cumulative_offset(1), cumulative_offset(2)   % Back to top-left to close the rectangle
            ];
            
            % Plot the image boundaries
            plot(corners(:, 1), corners(:, 2), 'k--');
            
            % Add image label (using 0-based indexing to match your file structure)
            text(mean(corners(1:4, 1)), mean(corners(1:4, 2)), ...
                sprintf('Image %d\n(R%d,C%d)', i, row-1, col-1), ...
                'FontSize', 12, 'HorizontalAlignment', 'center');
        end
        
        title('Global Particle Map with Unique IDs');
        xlabel('X Coordinate (pixels)');
        ylabel('Y Coordinate (pixels)');
        set(gca, 'YDir', 'reverse');
        axis equal;
    end
    
    %% Step 7: Generate Statistics and Reports
    % Calculate statistics
    particle_occurrence_counts = cellfun(@length, particle_appearances);
    
    % Plot histogram of particle occurrences
    % if caParams.displayFigures
    %     figure;
    %     histogram(particle_occurrence_counts, 'BinMethod', 'integers');
    %     title('Histogram of Particle Occurrences Across Images');
    %     xlabel('Number of Images a Particle Appears In');
    %     ylabel('Count');
    %     grid on;
    % end
    
    % Summary statistics
    % fprintf('\n--- Particle Tracking Summary ---\n');
    % fprintf('Total images processed: %d\n', catotal_images);
    % fprintf('Total unique particles detected: %d\n', unique_id);
    % fprintf('Particles appearing in only one image: %d (%.1f%%)\n', ...
    %     sum(particle_occurrence_counts == 1), 100*sum(particle_occurrence_counts == 1)/unique_id);
    % fprintf('Particles appearing in multiple images: %d (%.1f%%)\n', ...
    %     sum(particle_occurrence_counts > 1), 100*sum(particle_occurrence_counts > 1)/unique_id);
    % fprintf('Maximum occurrences of a single particle: %d\n', max(particle_occurrence_counts));
    
    % Per-image statistics
    for i = 1:catotal_images
        img_result = results.image_data{i};
        if verbose
            fprintf('\nImage %d (Row %d, Col %d):\n', i, img_result.row, img_result.col);
            fprintf('  Total particles: %d\n', size(img_result.local_centers, 1));
            fprintf('  Unique particles: %d\n', img_result.unique_particle_count);
        end
        % Count particles that also appear in other images
        shared_count = 0;
        for j = 1:length(img_result.particle_ids)
            id = img_result.particle_ids(j);
            if length(particle_appearances{id}) > 1
                shared_count = shared_count + 1;
            end
        end
        if verbose
            fprintf('  Shared particles: %d (%.1f%%)\n', ...
                shared_count, 100*shared_count/size(img_result.local_centers, 1));
        end
    end
    
    %% Step 8: Save Results
    mainOutDir = fileParams.topDir;
    cannyOutDir = fullfile(mainOutDir, 'canny_output');
    
    % Create the output directory if it doesn't exist
    if ~exist(cannyOutDir, 'dir')
        mkdir(cannyOutDir);
    end
    
    % Create a detailed MATLAB data file
    save_path = fullfile(cannyOutDir, 'particle_tracking_results.mat');
    save(save_path, 'results', 'particle_appearances', 'particle_occurrence_counts', ...
         'all_global_centers', 'particle_ids', 'img_indices');
    if verbose
        fprintf('\nResults saved to %s\n', save_path);
    end
    
    % Create a summary CSV file
    csv_path = fullfile(cannyOutDir, 'particle_tracking_summary.csv');
    
    % Open CSV file for writing
    fid = fopen(csv_path, 'w');
    if verbose
        fprintf(fid, 'Particle_ID,Num_Occurrences,Appears_In_Images,Global_X,Global_Y\n');
    end

    % Write data for each unique particle
    for i = 1:unique_id
        % Find all instances of this particle
        idx = (particle_ids == i);
        positions = all_global_centers(idx, :);
        
        % Calculate mean position
        mean_pos = mean(positions, 1);
        
        % Get the list of images this particle appears in
        img_list = particle_appearances{i};
        img_list_str = sprintf('%d,', img_list);
        img_list_str = img_list_str(1:end-1);  % Remove trailing comma
        
        % Write to CSV
        if verbose
            fprintf(fid, '%d,%d,"%s",%f,%f\n', ...
                i, length(img_list), img_list_str, mean_pos(1), mean_pos(2));
        end
    end
    
    fclose(fid);
    if verbose
        fprintf('Particle summary saved to %s\n', csv_path);
    end

    % Add a call to the visualization function
    if verbose
        fprintf('\nCreating particle visualizations...\n');
    end

    if caParams.visualizeParticles 
        visualize_particles_on_images(all_images, img_positions, all_centers, particle_ids, img_indices, particle_appearances);
    end
    if caParams.globalMap
        visualize_global_particle_map(all_images, img_positions, all_centers, particle_ids, img_indices);
    end
end

function visualize_particles_on_images(all_images, img_positions, all_centers, particle_ids, img_indices, particle_appearances)
    num_unique_particles = max(particle_ids);
    colormap_particles = hsv(num_unique_particles);

    for img_idx = 1:length(all_images)
        figure('Name', sprintf('Particle Visualization - Image %d (R%d,C%d)', ...
            img_idx, img_positions(img_idx,1)-1, img_positions(img_idx,2)-1), ...
            'Position', [100, 100, 1000, 800]);

        imshow(all_images{img_idx}); hold on;

        % Find particles in this image
        particle_indices = find(img_indices == img_idx);

        % Get local coordinates for this image
        local_centers = all_centers{img_idx};
        if isempty(local_centers)
            continue;  % Skip if no centers available
        end

        % Display each particle with its unique ID
        for i = 1:length(particle_indices)
            global_idx = particle_indices(i);
            unique_id = particle_ids(global_idx);

            % Check if i is within bounds of local_centers
            if i <= size(local_centers, 1)
                x = local_centers(i, 1);
                y = local_centers(i, 2);

                % Get radius if available
                if size(local_centers, 2) >= 3
                    radius = local_centers(i, 3);
                else
                    radius = 20; % Default radius
                end

                % Get number of occurrences for this particle
                num_occurrences = length(particle_appearances{unique_id});

                % Choose color based on unique ID
                color = colormap_particles(unique_id, :);

                % Draw circle around particle with thickness proportional to occurrences
                linewidth = min(1 + num_occurrences * 0.5, 5);
                theta = linspace(0, 2*pi, 100);
                circle_x = x + radius * cos(theta);
                circle_y = y + radius * sin(theta);
                plot(circle_x, circle_y, 'Color', color, 'LineWidth', linewidth);

                % Add ID label
                text(x, y, num2str(unique_id), 'Color', 'white', 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                    'FontSize', 10, 'BackgroundColor', [0 0 0 0.5]);

                % Add smaller label showing which images this particle appears in
                other_images = particle_appearances{unique_id};
                other_images_str = sprintf('%d ', other_images);
                text(x, y + radius + 5, sprintf('In: %s', other_images_str), ...
                    'Color', 'white', 'FontSize', 8, 'HorizontalAlignment', 'center', ...
                    'BackgroundColor', [0 0 0 0.5]);
            end
        end

        % Add title and legend
        title(sprintf('Image %d (R%d,C%d) - Unique Particles Visualization', ...
            img_idx, img_positions(img_idx,1)-1, img_positions(img_idx,2)-1), 'FontSize', 14);

        annotation('textbox', [0.01, 0.01, 0.5, 0.05], 'String', ...
            'Circle colors represent unique particle IDs. Circle thickness shows number of occurrences.', ...
            'EdgeColor', 'none', 'Color', 'white', 'BackgroundColor', [0 0 0 0.7]);
    end
end


function visualize_global_particle_map(all_images, img_positions, all_centers, particle_ids, img_indices)
    num_unique_particles = max(particle_ids);
    colormap_particles = hsv(num_unique_particles);

    % Create an overall map visualization
    figure('Name', 'Global Particle Map', 'Position', [200, 200, 1200, 900]);
    hold on; grid on;

    % Calculate max width and height for the display
    max_img_width = max(cellfun(@(x) size(x, 2), all_images));
    max_img_height = max(cellfun(@(x) size(x, 1), all_images));

    % Draw grid lines to separate images
    max_row = max(img_positions(:, 1));
    max_col = max(img_positions(:, 2));

    for r = 0:max_row
        y_pos = r * max_img_height;
        plot([0, max_col * max_img_width], [y_pos, y_pos], 'k--', 'LineWidth', 1);
    end

    for c = 0:max_col
        x_pos = c * max_img_width;
        plot([x_pos, x_pos], [0, max_row * max_img_height], 'k--', 'LineWidth', 1);
    end

    % Create mapping between particle indexing and local centers
    % This structure maps from global particle indices to local center indices
    particle_mapping = zeros(length(img_indices), 2); % [img_idx, local_idx]
    for i = 1:length(img_indices)
        img_idx = img_indices(i);

        % Find how many particles from this image have been processed before this one
        prev_count = sum(img_indices(1:i-1) == img_idx);

        % The local index is the count + 1
        local_idx = prev_count + 1;

        % Store mapping
        particle_mapping(i, :) = [img_idx, local_idx];
    end

    % Plot each unique particle with connections between occurrences
    for id = 1:num_unique_particles
        % Find all occurrences of this particle
        idx = find(particle_ids == id);

        % Skip if no occurrences (shouldn't happen)
        if isempty(idx)
            continue;
        end

        % Get positions in the global reference frame
        positions = zeros(length(idx), 2);
        valid_positions = true(length(idx), 1);

        for i = 1:length(idx)
            img_idx = particle_mapping(idx(i), 1);
            local_idx = particle_mapping(idx(i), 2);

            % Check if center data exists and index is valid
            if isempty(all_centers{img_idx}) || local_idx > size(all_centers{img_idx}, 1)
                valid_positions(i) = false;
                continue;
            end

            % Get local coordinates
            local_coords = all_centers{img_idx}(local_idx, 1:2);

            % Convert to map coordinates based on grid position
            row = img_positions(img_idx, 1) - 1;  % 0-based
            col = img_positions(img_idx, 2) - 1;  % 0-based

            positions(i, 1) = local_coords(1) + col * max_img_width;
            positions(i, 2) = local_coords(2) + row * max_img_height;
        end

        % Remove invalid positions
        positions = positions(valid_positions, :);

        % Skip if no valid positions
        if isempty(positions)
            continue;
        end

        % Plot each occurrence
        scatter(positions(:,1), positions(:,2), 100, colormap_particles(id,:), 'filled', 'MarkerEdgeColor', 'k');

        % Add ID label to one occurrence
        text(positions(1,1), positions(1,2), num2str(id), 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'w');

        % Connect occurrences with lines
        if size(positions, 1) > 1
            for i = 1:size(positions, 1)
                for j = (i+1):size(positions, 1)
                    plot([positions(i,1), positions(j,1)], [positions(i,2), positions(j,2)], '--', ...
                        'Color', colormap_particles(id,:), 'LineWidth', 1.5);
                end
            end
        end
    end

    % Set proper axis limits and labels
    xlim([0, max_col * max_img_width]);
    ylim([0, max_row * max_img_height]);
    set(gca, 'YDir', 'reverse');
    xlabel('X Coordinate (pixels)', 'FontSize', 12);
    ylabel('Y Coordinate (pixels)', 'FontSize', 12);
    title('Global Map of All Unique Particles', 'FontSize', 16);

    % Add grid labels
    for r = 0:max_row-1
        for c = 0:max_col-1
            x_center = (c + 0.5) * max_img_width;
            y_center = (r + 0.5) * max_img_height;
            text(x_center, y_center, sprintf('R%d,C%d', r, c), ...
                'FontSize', 14, 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1 1 1 0.7], 'Margin', 5);
        end
    end

    % Add legend for occurrence count
    for i = 1:4
        text(50, 50 + (i-1)*30, sprintf('%d occurrences', i), ...
            'FontSize', 12, 'Color', 'k', 'BackgroundColor', [1 1 1 0.7], ...
            'EdgeColor', 'k', 'LineWidth', i*0.5, 'Margin', 5, 'Units', 'pixels');
    end


end
   