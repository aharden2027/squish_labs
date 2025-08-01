// for a 105mm focal length lens, the selection radius may need to be adjusted with a different lens
filePath = getArgument();
unpolarized_processing(filePath);
function unpolarized_processing(filePath) {
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

	// --- Compute mean pixel value ---
	getStatistics(area, mean, min, max, std, histogram);

	// --- Select boundary particles ---
	setThreshold(0, 40);
	run("Create Selection");
	if (selectionType() != -1) {
		run("Enlarge...", "enlarge=37");
	}
	
	// --- Reset image state ---
	resetThreshold;

	// --- Fill selection with mean value to reduce shadow ---
	if (selectionType() != -1) {
		run("Set...", "value=" + 163);
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
		run("Set...", "value=255");
		run("Select None");
	}
	
	// --- Boost contrast for better particle detection ---
	//run("Brightness/Contrast...", "contrast=100");
	//setMinAndMax(90, 240);
	
}

