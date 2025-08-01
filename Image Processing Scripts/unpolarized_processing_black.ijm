// Pre-processing for particle detect
filePath = getArgument();
unpolarized_processing_black(filePath);
function unpolarized_processing_black(filePath) {
	// --- Open the image file ---
	open(filePath);
	
	// Save the original name (without extension)
	originalTitle = getTitle();
	base = substring(originalTitle, 0, lastIndexOf(originalTitle, "."));
	
	// Split the RGB channels
	run("Split Channels");
	
	// Construct exact channel names
	redTitle = base + ".JPG (red)";
	greenTitle = base + ".JPG (green)";
	blueTitle = base + ".JPG (blue)";
	
	// Close red and blue channels
	selectWindow(redTitle);
	close();
	
	selectWindow(blueTitle);
	close();
	
	// Select green channel for processing
	selectWindow(greenTitle);
	
	// Get mean pixel value
	//getStatistics(area, mean, min, max, std);
	mean = 152.09;
	
	// --- Select boundary particles ---
	setThreshold(0, 50);
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=5");
	}
	
	//Reset the Image
	resetThreshold;
	
	// --- Fill selection with mean value to reduce shadow ---
	if (selectionType() != -1) {
		run("Set...", "value=" + mean);
	}
	
	// --- Bandpass filtering on background ---
	if (selectionType() != -1) {
		run("Make Inverse");
	}
	run("Bandpass Filter...", "filter_large=800 filter_small=3 suppress=None tolerance=5 autoscale saturate");
	
	// --- Boost contrast for better particle detection ---
	run("Brightness/Contrast...", "contrast=100");
	setMinAndMax(0, 230);
	
	// --- Set boundary particles to white to remove them ---
	if (selectionType() != -1) {
		run("Make Inverse");
		run("Set...", "value=0");
		run("Select None");
	}
}






