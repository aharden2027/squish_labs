%% finding new dimensions
%% 'testdata\particleCleaned.mat'
function [yDim, xDim, minY, minX, maxR] = dimensions(filePath)
    % Load the particle data structure from the specified file
    data = load(filePath);
    particles = data.particle;
    
    % Extract all x and y coordinates from the particle array
    xVals = [particles.x];
    yVals = [particles.y];
    
    % Find the minimum and maximum x and y coordinates
    minX = ceil(min(xVals));
    maxX = ceil(max(xVals));
    minY = ceil(min(yVals));
    maxY = ceil(max(yVals));

    % Get all radii and determine the largest one
    rad = [particles.r];
    maxR = max(rad);
    
    % Compute total width and height, including padding for particle edges
    xDim = (maxX - minX) + maxR*2;
    yDim = (maxY - minY) + maxR*2;
    
end