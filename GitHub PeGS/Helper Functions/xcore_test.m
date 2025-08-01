% xcore_test.m
% ------------------------------------------------------------------------------
% Computes normalized cross-correlation offsets between a reference image (template)
% and two neighboring images in a grid: one horizontal neighbor and one vertical neighbor.
%
% PURPOSE:
%   To calculate pixel offsets needed to align images horizontally and vertically 
%   based on maximum normalized cross-correlation values.
%
% INPUTS:
%   - Three image file paths are hardcoded in variables:
%       img1 : Reference image (template)
%       img2 : Horizontal neighbor image
%       img3 : Vertical neighbor image
%
% PROCESS:
%   1. Reads the three images and extracts the red color channel.
%   2. Uses normxcorr2 to compute normalized cross-correlation between:
%       a) template and horizontal neighbor
%       b) template and vertical neighbor
%   3. Determines offsets by locating the peak correlation points.
%   4. Handles image size differences by adjusting correlation direction.
%
% OUTPUT:
%   - Prints the horizontal and vertical offset vectors to the console.
%   - Displays color-mapped images of the cross-correlation matrices for both directions.
%
% NOTES:
%   - Assumes images are arranged in a grid with naming convention 'piece_ROW_COL.png'.
%   - Offsets indicate pixel shifts needed to align neighbors to the template.
%
% EXAMPLE USAGE:
%   Run the script directly as paths are hardcoded.
%
% Author: [Arno Harden, Ashe Tanemura]
% Date: 2025-08-01
% ------------------------------------------------------------------------------

img1 = 'testdata/images/piece_3_2.png'; % First image (R0,C0)
img2 = 'testdata/images/piece_3_3.png'; % Second image (R0,C1)
img3 = 'testdata/images/piece_4_2.png'; % Third image (R1,C0)

% Read images
template = double(imread(img1));
imageh = double(imread(img2));
imagev = double(imread(img3));

% Extract only the red channel (1st channel in RGB)
template = template(:,:,1);
imageh   = imageh(:,:,1);
imagev   = imagev(:,:,1);

size(imread(img1))
size(imread(img2))
size(imread(img3))

% Compute normalized cross-correlation (horizontal)
% Includes logic to ensure normxcorr2 runs as piece_0_0 must be a smaller or equal sized image to its neighbors
% Creates row vectors for the offset of the images
fprintf("horiztonal offset...");
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
fprintf("vertical offset...");
% Computer normalized cross-correlation (vertical)
% Includes logic to ensure normxcorr2 runs as piece_0_0 must be a smaller or equal sized image to its neighbors
% Creates row vectors for the offset of the images
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

disp(h_offset)
disp(v_offset)

figure;
imagesc(C_h);
colormap('jet');     % Or 'gray', 'hot', etc.
colorbar;
title('Horizontal Cross-Correlation Output');
xlabel('X-axis (shift)');
ylabel('Y-axis (shift)');

figure;
imagesc(C_v);
colormap('jet');     % Or 'gray', 'hot', etc.
colorbar;
title('Vertical Cross-Correlation Output');
xlabel('X-axis (shift)');
ylabel('Y-axis (shift)');