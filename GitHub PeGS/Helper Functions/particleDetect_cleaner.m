%% ParticleDetect Cleaning Helpr Function

%% File Parameters
fileParams = struct();
fileParams.topDir      = 'testdata';    % project root (current folder)
fileParams.imgDir      = 'images';      % folder with piece_*.png
fileParams.imgReg      = 'piece_*.png'; % glob for images
fileParams.particleDir = 'particles';   % centres from particleDetect_AA
fileParams.cannyDir    = 'canny_output';% outputs from canny_auto
fileParams.contactDir  = 'contacts';    % where contact files go
fileParams.solvedDir = 'solved'; % output directory for solved force information

% Requested Piece
piece = 'piece_0_0';

% Create the output file name for centers
centersFileName = [piece, '_centers.txt'];
imgFileName = [piece, '.png'];

% Load Particle Data
detectOutDir = fullfile(fileParams.topDir, fileParams.particleDir);
data = readmatrix(fullfile(detectOutDir, centersFileName));

% Extract Centers and Radii Information
centers = data(: , 1:2);
radii = data(:, 3);
edges = data(:, 4);
edge_angles = data(:, 5:end);

% Generate an array from 1 to the number of radii
numRadii = length(radii);
temp_idx = 1:numRadii;

% Load the Image
imgPath = fullfile(fileParams.topDir, fileParams.imgDir, imgFileName);
redImg = imread(imgPath);
if size(redImg,3) == 3
    redImg = redImg(:,:,1);
end

clean = false;

while ~clean
    imshow(redImg);
    hold on;
    % Visualize the Circles
    viscircles(centers(edges == 0, :), radii(edges == 0), 'EdgeColor', 'r');
    viscircles(centers(edges ~= 0, :), radii(edges ~= 0), 'EdgeColor', 'g');

    % Label each circle with a number from the idx array
    for i = 1:numRadii
        text(centers(i,1), centers(i,2), num2str(temp_idx(i)), 'Color', 'k', 'FontSize', 12, 'HorizontalAlignment', 'center');
    end
    
    value = input("Enter a number or CLEAN: ", 's');
    if ischar(value) && strcmpi(value, 'CLEAN')
        question = input("CONFIRM to save updated file: ", 's');

        if ischar(question) && strcmpi(question, 'CONFIRM')         
            particleData = [centers(:,1), centers(:,2), radii, edges, edge_angles];

            % Save the cleaned particle data to a file
            centersFullFile = fullfile(detectOutDir, centersFileName);
            writematrix(particleData, centersFullFile, 'Delimiter', ',');
            disp(['  Centers data saved to: ' centersFullFile]);

            % Save the new visualization as a PNG
            visDir = fullfile(fileParams.topDir, 'visualizations');
            if ~exist(visDir, 'dir')
                mkdir(visDir); % Create the directory if it does not exist
            end
            saveas(gcf, fullfile(visDir, [piece, '_circles.png'])); % Save as PNG
            disp(['  Visualization image saved to: ' ['/' visDir piece, '_circles.png']]);
            close(gcf);
        else
            disp('Centers data NOT saved')
        end
 
        % Exit the Loop
        clean = true; % Exit the loop if 'CLEAN' is entered
        close all;
    else
        idxToRemove = str2double(value); % Convert input to a number
        if ~isnan(idxToRemove) && idxToRemove >= 1 && idxToRemove <= numRadii
            centers(idxToRemove, :) = []; % Remove the selected center
            radii(idxToRemove) = []; % Remove the corresponding radius
            edges(idxToRemove) = [];
            if edge_piece
                edge_angles(idxToRemove, :) = []; % Remove the corresponding edge angles
            end
            numRadii = length(radii); % Update the number of radii
            temp_idx = 1:numRadii; % Update the index array
        else
            disp('Invalid input. Please enter a valid number or "CLEAN".');
        end
    end
end













