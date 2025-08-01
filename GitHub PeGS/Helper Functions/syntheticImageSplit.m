%% File Parameters and Synthetic Image Tiling
% 
% Sets up directory paths and filenames used throughout the project for images,
% particle detection outputs, contact files, and solved force data.
%
% Then calls generateSyntheticImageSplit to:
%   - Load a large synthetic force image generated from solved particle data.
%   - Assemble a full synthetic image from individual particle synthetic images.
%   - Split the large synthetic image into a specified grid of smaller tiled images.
%   - Save each tile as a compressed TIFF file (with .mat fallback on failure).
%
% This facilitates handling large synthetic images by breaking them into manageable tiles.
%
% Parameters:
%   fileParams: struct containing folder paths
%   numRows, numCols: number of tiles vertically and horizontally for splitting
%
% Usage:
%   Define fileParams and call generateSyntheticImageSplit(fileParams, numRows, numCols)
%
% Author: [ChatGPT, Arno Harden, Ashe Tanemura]
% Date: 2025-08-01

%% File Parameters
fileParams = struct();
fileParams.topDir      = 'testdata';    % project root (current folder)
fileParams.imgDir      = 'images';      % folder with piece_*.png
fileParams.imgReg      = 'piece_*.png'; % glob for images
fileParams.particleDir = 'particles';   % centres from particleDetect_AA
fileParams.cannyDir    = 'canny_output';% outputs from canny_auto
fileParams.contactDir  = 'contacts';    % where contact files go
fileParams.solvedDir = 'solved'; % output directory for solved force information

generateSyntheticImageSplit(fileParams, 2, 2);

function generateSyntheticImageSplit(fileParams, numRows, numCols)
    % Load solved particle file (assumes mosaic mode)
    solvedFile = fullfile(fileParams.topDir, fileParams.solvedDir, 'mosaic_solved.mat');
    contactsFile = fullfile(fileParams.topDir, fileParams.contactDir, 'mosaic_contacts.mat');

    data = load(solvedFile);
    particle = data.particle;

    [yDim, xDim, minY, minX, maxR] = dimensions(contactsFile);
    bigSynthImg = zeros(yDim, xDim);

    % Build full synthetic image in memory
    for n = 1:length(particle)
        if particle(n).z > 0 && isfield(particle(n), "synthImg")
            sImg = particle(n).synthImg;
            x = floor(particle(n).x - minX + maxR);
            y = floor(particle(n).y - minY + maxR);
            sx = size(sImg, 1)/2;
            sy = size(sImg, 2)/2;

            try
                bigSynthImg(round(y-sy+1):round(y+sy), round(x-sx+1):round(x+sx)) = ...
                    bigSynthImg(round(y-sy+1):round(y+sy), round(x-sx+1):round(x+sx)) + sImg;
            catch
                warning('Skipping particle %d due to indexing issue.', n);
            end
        end
    end

    % Tile the image
    tileHeight = floor(yDim / numRows);
    tileWidth = floor(xDim / numCols);

    [~, baseName, ~] = fileparts(solvedFile);

    for row = 1:numRows
        for col = 1:numCols
            yStart = (row - 1) * tileHeight + 1;
            yEnd = min(row * tileHeight, yDim);
            xStart = (col - 1) * tileWidth + 1;
            xEnd = min(col * tileWidth, xDim);

            tileImg = bigSynthImg(yStart:yEnd, xStart:xEnd);
            tileName = sprintf('%s_Synth_tile_r%d_c%d.tif', strrep(baseName, '_solved', ''), row, col);
            tilePath = fullfile(fileParams.topDir, fileParams.solvedDir, tileName);

            try
                imwrite(tileImg, tilePath, 'tif', 'Compression', 'lzw', 'RowsPerStrip', 100);
            catch ME
                warning('Failed to save tile [%d, %d]: %s', row, col, ME.message);
                % Fallback to .mat save
                matName = strrep(tileName, '.tif', '.mat');
                save(fullfile(fileParams.topDir, fileParams.solvedDir, matName), 'tileImg', '-v7.3');
            end
        end
    end

    disp('Tiled synthetic image generation complete.');
end
