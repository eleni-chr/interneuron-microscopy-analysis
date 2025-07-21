/* STEP 2: ROTATE MAXIMUM PROJECTION IMAGES 90 DEGREES LEFT

Code written by Dr Eleni Christoforidou.

ThisImageJ macro processes images of spinal cord cross-sections stored in a main folder containing multiple subfolders.
Each first-level subfolder contains inner subfolders, where each inner subfolder corresponds to one cross-section imaged over 4 colour channels (each representing a different antibody staining).
E.g.,
MainFolder
	Subfolder1
		InnerSubfolder1
		InnerSubfolder2
		...
	Subfolder2
		InnerSubfolder1
		...

For each inner subfolder:
• The macro iterates over the 4 .tif images corresponding to the 4 colour channels after they have been max-projected. It only processed images with the following filenames: "ch00_MAX.tif", "ch01_MAX.tif", "ch02_MAX.tif", "ch03_MAX.tif".
• The macro rotates these images 90 degrees left, then re-saves them, overwriting the original files.
*/

// Ask the user to select the main folder
mainFolder = getDirectory("Select the main folder containing your tif files");

// Start processing recursively
processFolder(mainFolder);

function processFolder(folder) {
    // Get list of files and subfolders in the current folder
    files = getFileList(folder);
    for (i = 0; i < files.length; i++) {
        currentPath = folder + files[i];
        // If the item is a folder (its name ends with "/"), process it recursively
        if (endsWith(files[i], "/")) {
            processFolder(currentPath);
        } else {
            // Process only if the file name matches one of the specified names
            if (files[i]=="ch00_MAX.tif" || files[i]=="ch01_MAX.tif" || files[i]=="ch02_MAX.tif" || files[i]=="ch03_MAX.tif") {
                print("Processing: " + currentPath);
                open(currentPath);
                run("Rotate 90 Degrees Left");
                // Save the rotated image, overwriting the original file
                saveAs("Tiff", currentPath);
                close();
            }
        }
    }
}
