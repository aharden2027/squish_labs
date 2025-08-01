function rename_images(riimageFolder, riimageDestination, rows, cols, riimageFormat)

    % Get list of image files
    imageFiles = dir(fullfile(riimageFolder, riimageFormat));
    
    % Extract numeric part from filenames for numeric sorting
    fileNums = zeros(1, numel(imageFiles));
    for i = 1:numel(imageFiles)
        [~, name, ~] = fileparts(imageFiles(i).name);
        fileNums(i) = str2double(name);
    end
    
    % Sort files numerically
    [~, idx] = sort(fileNums);
    imageFiles = imageFiles(idx);
    
    % Check the number of images matches the grid size
    expectedCount = rows * cols; 
    if length(imageFiles) ~= expectedCount
        error('Number of images (%d) does not match grid size (%d x %d = %d)', ...
            length(imageFiles), rows, cols, expectedCount);
    end
    
    % Ensure destination folder exists
    if ~exist(riimageDestination, 'dir')
        mkdir(riimageDestination);
    end
    
    % Rename images following the snake pattern
    k = 1;
    for row = rows-1:-1:0  % Start from bottom row up to top row
        if mod(rows - 1 - row, 2) == 0
            % Even row from bottom: Right to Left
            col_range = cols-1:-1:0;
        else
            % Odd row from bottom: Left to Right
            col_range = 0:cols-1;
        end
        
        for col = col_range
            oldFile = fullfile(riimageFolder, imageFiles(k).name);
            newName = sprintf('piece_%d_%d.png', row, col);
            newFile = fullfile(riimageDestination, newName);
            movefile(oldFile, newFile);
            k = k + 1;
        end
    end
end
