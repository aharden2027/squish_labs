%% contactCombine_testing.m
% -------------------------------------------------------------------------
% Loads and displays detailed information for a specified particle ID 
% from mosaic and individual contact data files.
%
% This script:
%   - Defines directory and file parameters via 'fileParams' struct.
%   - Loads the combined particle data file 'mosaic_contacts.mat' and 
%     prints info for the given particle ID if found.
%   - Searches through all individual contact files 
%     ('piece_*_*_contacts.mat') to find and display matching particle data.
%
% Usage:
%   Call printParticleInfo(fileParams, particleID) with the particle ID 
%   you want to inspect.
%
% Inputs:
%   fileParams - Struct specifying directory locations for project data.
%   particleID - Integer specifying the particle ID to look up.
%
% Outputs:
%   Prints particle data to the command window from mosaic and contact files.
%
% Notes:
%   Assumes contact files and mosaic file are located relative to fileParams paths.
%
% Author: [ChatGPT]
% Date: 2025-08-01
% -------------------------------------------------------------------------

%% File Parameters
fileParams = struct();
fileParams.topDir      = 'testdata';    % project root (current folder)
fileParams.imgDir      = 'images';      % folder with piece_*.png
fileParams.imgReg      = 'piece_*.png'; % glob for images
fileParams.particleDir = 'particles';   % centres from particleDetect_AA
fileParams.cannyDir    = 'canny_output';% outputs from canny_auto
fileParams.contactDir  = 'contacts';    % where contact files go
fileParams.solvedDir = 'solved'; % output directory for solved force information

printParticleInfo(fileParams, 355);
function printParticleInfo(fileParams, particleID)
    % Load mosaic contacts
    mosaicFile = fullfile(fileParams.topDir, fileParams.contactDir, 'mosaic_contacts.mat');
    S = load(mosaicFile);
    mosaicParticles = S.particle;

    % Find the particle in the mosaic file
    idxMosaic = find([mosaicParticles.id] == particleID, 1);
    if isempty(idxMosaic)
        fprintf('Particle ID %d not found in mosaic_contacts.mat\n', particleID);
    else
        fprintf('Particle ID %d info from mosaic_contacts.mat:\n', particleID);
        disp(mosaicParticles(idxMosaic));
    end

    % Get individual contact files
    contactDirFull = fullfile(fileParams.topDir, fileParams.contactDir);
    contactFiles = dir(fullfile(contactDirFull, 'piece_*_*_contacts.mat'));

    % For each contact file, look for the particle and print info
    foundInFiles = false;
    fprintf('\nSearching for Particle ID %d in original contact files:\n', particleID);

    for i = 1:numel(contactFiles)
        data = load(fullfile(contactFiles(i).folder, contactFiles(i).name));
        if ~isfield(data, 'particle')
            continue;
        end
        particles = data.particle;
        idx = find([particles.id] == particleID, 1);
        if ~isempty(idx)
            foundInFiles = true;
            fprintf('Found in file: %s\n', contactFiles(i).name);
            disp(particles(idx));
            fprintf('--------------------------------------\n');
        end
    end

    if ~foundInFiles
        fprintf('Particle ID %d not found in any original contact file.\n', particleID);
    end
end
