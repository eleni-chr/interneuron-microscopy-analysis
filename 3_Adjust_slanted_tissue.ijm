/* STEP 3: MANUALLY ADJUST ORIENTATION OF SLANTED TISSUE IN IMAGES

Code written by Dr Eleni Christoforidou.

This macro processes directories recursively to locate images ending with "MAX.tif" in inner folders.
For each folder that contains a "ch00_MAX.tif" image, the macro performs the following steps:

1. Opens the "ch00_MAX.tif" image and creates a duplicate for inspection.
2. Converts the duplicate to RGB and draws a temporary cyan grid (with 50-pixel spacing) on it to help assess image orientation.
3. Prompts the user to inspect the duplicate and decide if a rotation adjustment is needed.
4. If the user chooses to adjust:
   - The duplicate is closed and the original "ch00_MAX.tif" image remains open.
   - The user is instructed to manually rotate the image using Image > Transform > Rotate.
     (The Recorder window is open so that it will display the applied rotation angle.)
   - After rotation, the user is prompted to enter the rotation angle they applied (This will be in the Recorder window if the user has forgotten).
   - The macro then automatically applies the same rotation (using the entered angle) to all other "MAX.tif" images in the same folder (excluding "ch00_MAX.tif").
5. If no adjustment is needed, the macro simply closes both the duplicate and the original image.

Note: The macro does not automatically capture the rotation angle, but if the Recorder window is open the user can see the angle applied and then type it in when prompted.
*/

rootDir = getDirectory("Choose a Directory");
processDirectory(rootDir);

function processDirectory(dir) {
    list = getFileList(dir);
    folderDone = false;  // flag to indicate that this folder's MAX.tif images have been processed
    for (i = 0; i < list.length; i++) {
        path = dir + list[i];
        if (File.isDirectory(path)) {
            processDirectory(path);
        } else {
            // If this folder's MAX.tif images have been processed, skip any further MAX.tif files.
            if (folderDone && indexOf(list[i], "MAX.tif") != -1) {
                continue;
            }
            if (list[i] == "ch00_MAX.tif") {
                // Process the ch00_MAX.tif image manually.
                open(path);
                originalTitle = getTitle();
                
                // Duplicate for inspection.
                run("Duplicate...", "title=temp_" + originalTitle);
                selectWindow("temp_" + originalTitle);
                run("RGB Color"); // convert duplicate to RGB so cyan displays properly
                drawGridOnImage(50);
                
                waitForUser("Inspect the image to decide if rotation adjustment is needed, then click OK.");
                answer = getString("Does this image need manual rotation adjustment? (Y/N)", "N");
                
                if (answer == "Y" || answer == "y") {
                    // Close the duplicate.
                    selectWindow("temp_" + originalTitle);
                    close();
                    // Return to the original image.
                    selectWindow(originalTitle);
                    
                    // Open the Recorder window only if it is not already open.
                    if (!isOpen("Recorder")) {
                        run("Record...");
                        waitForUser("Move the Recorder window away from the centre of the screen, then click OK.");
                    }
                    
                    // Instruct the user to manually rotate the image.
                    waitForUser("Manually rotate the image using Image > Transform > Rotate until satisfied.\n" +
                                "The Recorder window will show the applied rotation angle.\n" +
                                "Click OK when finished.");
                    
                    saveAs("Tiff", path);
                    print("Saved rotated image: " + path);
                    
                    // Now prompt the user to enter the rotation angle (which they can check from the Recorder).
                    rotationAngle = getNumber("Enter the rotation angle (in degrees) you applied (see Recorder window):", 0);
                    
                    // Automatically apply the same rotation to all other MAX.tif images in this folder.
                    for (j = 0; j < list.length; j++) {
                        if (list[j] != "ch00_MAX.tif" && indexOf(list[j], "MAX.tif") != -1) {
                            otherPath = dir + list[j];
                            open(otherPath);
                            // Define full-image selection.
                            makeRectangle(0, 0, getWidth(), getHeight());
                            run("Rotate...", "angle=" + rotationAngle + " grid=1 interpolation=Bilinear");
                            run("Select None");  // Clear any active selection before saving.
                            saveAs("Tiff", otherPath);
                            print("Automatically rotated and saved image: " + otherPath);
                            close();
                        }
                    }
                    folderDone = true;
                    close(); // close the ch00_MAX image (already processed)
                } else {
                    // If no adjustment is needed, close both the duplicate and original.
                    selectWindow("temp_" + originalTitle);
                    close();
                    selectWindow(originalTitle);
                    close();
                }
            }
        }
    }
}

function drawGridOnImage(spacing) {
    width = getWidth();
    height = getHeight();
    setColor("cyan");
    setLineWidth(1);
    
    // Draw vertical grid lines.
    for (x = spacing; x < width; x += spacing) {
        drawLine(x, 0, x, height);
    }
    // Draw horizontal grid lines.
    for (y = spacing; y < height; y += spacing) {
        drawLine(0, y, width, y);
    }
    resetMinAndMax();
}