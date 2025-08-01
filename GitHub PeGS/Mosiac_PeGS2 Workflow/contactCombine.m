% contactCombine.m
% ------------------------------------------------------------------------------
% Combines multiple contact files into a single unified contact dataset.
%
% Main Function:
%   contactCombine(fileParams)
%
% DESCRIPTION:
%   This function consolidates particle contact data from multiple 
%   `piece_ROW_COL*_contacts.mat` files into one global `mosaic_contacts.mat`.
%   When particles with the same ID appear in multiple files, the most
%   centered version (closest to image center) is selected to represent it.
%
%   Global (x, y) coordinates are obtained from a Canny-based particle tracking 
%   summary CSV. Output is a unified `particle` array suitable for global 
%   photoelastic analysis or further processing.
%
% INPUT:
%   fileParams - Struct containing:
%       .topDir      : Top-level directory for project
%       .contactDir  : Directory under topDir with contact MAT files
%       .imgDir      : Directory under topDir with image files (for sizing)
%       .cannyDir    : Directory under topDir with particle_tracking_summary.csv
%
% OUTPUT:
%   Saves 'mosaic_contacts.mat' into the contactDir. It contains:
%       - `particle`: Struct array of combined particles with fields such as:
%           id, x, y, r, z, g2, neighbours, contactG2s, contactIs, etc.
%
% LOGIC:
%   1. Loads all `piece_*_*contacts.mat` files from contactDir.
%   2. Groups entries by particle ID.
%   3. For duplicates, chooses the particle closest to the center of the image.
%   4. Looks up global (x, y) positions from `particle_tracking_summary.csv`.
%   5. Saves the final particle array as 'mosaic_contacts.mat'.
%
% DEPENDENCIES:
%   Requires `particle_tracking_summary.csv` to exist in cannyDir.
%   Assumes image naming pattern: 'piece_ROW_COL.png'.
%   Requires matching `piece_ROW_COL*_contacts.mat` files.
%
% EXAMPLE:
%   fileParams.topDir = 'experiment1';
%   fileParams.contactDir = 'contacts';
%   fileParams.imgDir = 'images';
%   fileParams.cannyDir = 'canny';
%   contactCombine(fileParams);
%
% Authors: [Arno Harden]
% Last updated: [8/1/2025]
% ------------------------------------------------------------------------------
function contactCombine(fileParams)
    topDir = fileParams.topDir;
    contactDir = fileParams.contactDir;
    imgDir = fileParams.imgDir;

    % Automatically find first available piece_*.png to get image size
    imageFiles = dir(fullfile(topDir, imgDir, 'piece_*.png'));
    if isempty(imageFiles)
        error('No piece_*.png files found in %s', fullfile(topDir, imgDir));
    end
    refImagePath = fullfile(topDir, imgDir, imageFiles(1).name);
    info = imfinfo(refImagePath);
    imgWidth = info.Width;
    imgHeight = info.Height;
    imgCenter = [imgWidth / 2, imgHeight / 2];
    fprintf('Using image size from %s: %d x %d\n', imageFiles(1).name, imgWidth, imgHeight);

    files = dir(fullfile(topDir, contactDir, 'piece_*_*contacts.mat'));
    contactFiles = files(~[files.isdir]);

    allParticles = {};
    particleMap = containers.Map('KeyType', 'int32', 'ValueType', 'any');

    fprintf("Building Particle Map...\n")
    for i = 1:numel(contactFiles)
        file = fullfile(topDir, contactDir, contactFiles(i).name);
        data = load(file);
        if isfield(data, 'particle')
            for j = 1:numel(data.particle)
                p = data.particle(j);
                entry.particle = p;
                entry.sourceFileIdx = i;

                if isKey(particleMap, p.id)
                    temp = particleMap(p.id);
                    temp{end+1} = entry;
                    particleMap(p.id) = temp;
                else
                    particleMap(p.id) = {entry};
                end
            end
        end
    end

    ids = keys(particleMap);
    numParticles = numel(ids);
    fprintf('Number of unique particles found: %d\n', numParticles);

    T = readtable(fullfile(topDir, fileParams.cannyDir, 'particle_tracking_summary.csv'));
    id2xy = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    for i = 1:height(T)
        id2xy(T.Particle_ID(i)) = [T.Global_X(i), T.Global_Y(i)];
    end

    particle(numel(ids), 1) = struct();
    isequal(sort(fieldnames(createEmptyParticle())), sort(fieldnames(data.particle(1))));

    fprintf("Starting to Combine Particles...\n")
    for i = 1:numel(ids)
        try
            id = ids{i};
            entries = particleMap(id);
            if numel(entries) == 1
                bestEntry = entries{1}.particle;
            else
                distances = zeros(1, numel(entries));
                for k = 1:numel(entries)
                    entry = entries{k};
                    px = entry.particle.x;
                    py = entry.particle.y;

                    % Distance from center using constant image size
                    distances(k) = norm([px, py] - imgCenter);
                end

                [~, minIdx] = min(distances);
                bestEntry = entries{minIdx}.particle;
            end

            p = createEmptyParticle();
            p.id = bestEntry.id;
            p.r = bestEntry.r;
            p.rm = bestEntry.rm;
            p.color = bestEntry.color;
            p.z = bestEntry.z;
            p.fsigma = bestEntry.fsigma;
            p.forcescale = bestEntry.forcescale;
            p.g2 = bestEntry.g2;
            p.forceImage = bestEntry.forceImage;
            p.edge = bestEntry.edge;
            p.neighbours = bestEntry.neighbours;
            p.contactG2s = bestEntry.contactG2s;
            p.contactIs = bestEntry.contactIs;
            p.betas = bestEntry.betas;

            matches = T.Particle_ID == id;
            p.x = T.Global_X(matches);
            p.y = T.Global_Y(matches);

            fields = fieldnames(p);
            for f = 1:numel(fields)
                particle(i).(fields{f}) = p.(fields{f});
            end

            fprintf('[%s] Saved particle ID %d (%d of %d)\n', ...
                    datestr(now, 'HH:MM:SS'), id, i, numel(ids));

        catch ME
            fprintf('Error processing ID %d (index %d): %s\n', id, i, ME.message);
        end
    end

    save(fullfile(topDir, contactDir, 'mosaic_contacts.mat'), 'particle', '-v7.3');
    fprintf('\n Done. Saved mosaic_contacts.mat with %d particles.\n', numel(particle));
end

function p = createEmptyParticle()
    p = struct( ...
        'id', [], 'x', [], 'y', [], 'r', [], 'rm', [], 'color', '', 'fsigma', [], 'z', [], ...
        'forcescale', [], 'g2', [], 'forces', [], 'fitError', [], 'betas', [], 'alphas', [], ...
        'neighbours', [], 'contactG2s', [], 'forceImage', [], 'edge', [], 'contactIs', []);
end

function [sorted, index] = sort_nat(c)
    expr = '(\d+)';
    [tokens, ~] = regexp(c, expr, 'tokens', 'match');
    tokens = cellfun(@(x) str2double([x{:}]), tokens, 'UniformOutput', false);
    nums = cell2mat(tokens');
    [~, index] = sortrows(nums);
    sorted = c(index);
end
