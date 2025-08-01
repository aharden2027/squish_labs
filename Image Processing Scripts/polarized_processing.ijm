filePath = getArgument();
polarized_processing(filePath);
function polarized_processing(filePath){
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

	selectWindow(greenTitle);
	close();

	// Leave the blue channel open for downstream processing
}