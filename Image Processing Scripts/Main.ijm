// Main Script for PhotoElastic Image Processing
polarizedDir = "C:/Users/Squishfolk/Desktop/Arno/processingDir/polarized_active";
unpolarizedDir = "C:/Users/Squishfolk/Desktop/Arno/processingDir/unpolarized_active";
outputDir = "C:/Users/Squishfolk/Desktop/Arno/VAA_PeGS_CURRENT_VERSION/testdata/images_unsorted";
outputDir_black = "C:/Users/Squishfolk/Desktop/Arno/processingDir/black"
outputDir_white = "C:/Users/Squishfolk/Desktop/Arno/processingDir/white"

//Script Paths
polarizedScript = "C:/Users/Squishfolk/Desktop/Arno/processingDir/script_hub/polarized_processing.ijm"
unpolarizedScript = "C:/Users/Squishfolk/Desktop/Arno/processingDir/script_hub/unpolarized_processing.ijm"
unpolarizedScript_black = "C:/Users/Squishfolk/Desktop/Arno/processingDir/script_hub/unpolarized_processing_black.ijm"

//Get the two filelists
polarized_fileList = getFileList(polarizedDir);
unpolarized_fileList = getFileList(unpolarizedDir);
numFiles = unpolarized_fileList.length;

// Loop through all files
for (i = 0; i < numFiles; i++) {
    unpolarized_filename = unpolarized_fileList[i];
    polarized_filename = polarized_fileList[i];
    
    unpolarized_fullPath = unpolarizedDir + "/" + unpolarized_filename;
    polarized_fullPath = polarizedDir + "/" + polarized_filename;
    
    // Run Individual Scripts
    runMacro(unpolarizedScript, unpolarized_fullPath);
    runMacro(polarizedScript, polarized_fullPath);
    
    // Construct green channel names based on how the macros rename the windows
    redName = unpolarized_filename + " (green)";
    blueName = polarized_filename + " (blue)";

    // Merge the two channels: red from unpolarized, green from polarized
    run("Merge Channels...", "c1=[" + redName + "] c2=[" + blueName + "] create");

    // Save the merged image
    mergedTitle = "Composite"; // or use getTitle() if unsure
    selectWindow(mergedTitle);

    newName = "" + i + ".png";
    saveAs("PNG", outputDir + "/" + newName);
    close(newName); // Close the merged image
}

