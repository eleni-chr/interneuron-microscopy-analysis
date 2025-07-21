// USER SETTINGS
overlapFrac = 0.20;  // 20 % overlap threshold

// Define your three marker‐pairs:
prefA_arr = newArray("ch00", "ch03", "ch03");            // A-channel prefixes
prefB_arr = newArray("ch02", "ch02", "ch01");            // B-channel prefixes
labA_arr  = newArray("ChAT", "Parvalbumin", "Parvalbumin");
labB_arr  = newArray("GAD67","GAD67","Calbindin");

// Ask for the top‐level folder
mainDir = getDirectory("Choose MainFolder");

// Loop over Subfolders → InnerSubfolders
firstList = getFileList(mainDir);
for (i1 = 0; i1 < firstList.length; i1++) {
    if (!File.isDirectory(mainDir + firstList[i1])) continue;
    subDir = mainDir + firstList[i1] + "/";

    innerList = getFileList(subDir);
    for (i2 = 0; i2 < innerList.length; i2++) {
        if (!File.isDirectory(subDir + innerList[i2])) continue;
        innerDir = subDir + innerList[i2] + "/";

        // Skip if already processed
        checkCSV = innerDir
                 + labA_arr[2] + "_" + labB_arr[2]
                 + "_double_positive_measurements.csv";
        if (File.exists(checkCSV)) {
            print("Skipping “" + innerList[i2] + "” – already processed.");
            continue;
        }

        // Process each marker pair
        for (p = 0; p < prefA_arr.length; p++) {
            prefA  = prefA_arr[p];
            prefB  = prefB_arr[p];
            labelA = labA_arr[p];
            labelB = labB_arr[p];

            maskA = innerDir + prefA + "_MAX_cell_masks.tif";
            maskB = innerDir + prefB + "_MAX_cell_masks.tif";
            roiA  = innerDir + prefA + "_MAX_cell_ROIs.zip";

            // Skip missing files
            if (!File.exists(maskA) || !File.exists(maskB) || !File.exists(roiA)) {
                print("Skipping " + labelA + "+" + labelB
                    + " in “" + innerList[i2] + "” (missing files)");
                continue;
            }

            // 1. Open masks
            open(maskA); winA = getTitle();
            open(maskB); winB = getTitle();

            // 2. Load ROIs for marker A
            roiManager("reset");
            roiManager("Open", roiA);
            n = roiManager("count");

            // 3. Measure full‐cell area on mask A
            selectWindow(winA);
            run("Set Measurements...", "area centroid redirect=None decimal=3");
            roiManager("Measure");
            areaA = newArray(n);
            for (k = 0; k < n; k++) {
                areaA[k] = getResult("Area", k);
            }
            selectWindow("Results"); run("Close");

            // 4. Measure overlap‐pixel area on mask B
            selectWindow(winB);
            setThreshold(1, 255);
            run("Set Measurements...", "area mean redirect=None decimal=3 limit");
            roiManager("Measure");
            areaOv = newArray(n);
            for (k = 0; k < n; k++) {
                areaOv[k] = getResult("Area", k);
            }
            selectWindow("Results"); run("Close");

            // 5. Filter out ROIs with < overlapFrac
            for (k = n - 1; k >= 0; k--) {
                if ((areaOv[k] / areaA[k]) < overlapFrac) {
                    roiManager("Select", k);
                    roiManager("Delete");
                }
            }

            // Sanity check
            filteredCount = roiManager("count");
            pct = 100 * filteredCount / n;
            pctStr = d2s(pct, 1);
            print(labelA + "+" + labelB + ": "
                  + filteredCount + " of " + n
                  + " (" + pctStr + "%)");

            // Paths for outputs
            outZip = innerDir
                   + labelA + "_" + labelB
                   + "_double_positive_ROIs.zip";
            outCSV = innerDir
                   + labelA + "_" + labelB
                   + "_double_positive_measurements.csv";

            // CASE: No colocalising cells
            if (filteredCount == 0) {
                // Close the ROI Manager window if it's open
                if (Window.exists("ROI Manager")) {
                    selectWindow("ROI Manager");
                    run("Close");
                }
                // Close the two mask windows
                if (isOpen(winA)) close(winA);
                if (isOpen(winB)) close(winB);
                // Create an empty CSV
                File.saveString("", outCSV);
                print("None found → wrote empty CSV: " + outCSV);
                // Skip saving any ROI-ZIP
                continue;
            }

            // CASE: Some colocalising cells
            // 6. Save the filtered ROIs
            roiManager("Save", outZip);
            print("Saved ROIs: " + outZip);

            // 7. Re-open those ROIs & export CSV measurements
            roiManager("reset");
            roiManager("Open", outZip);
            selectWindow(winA);
            run("Set Measurements...", "area centroid redirect=None decimal=3");
            roiManager("Measure");
            saveAs("Results", outCSV);
            selectWindow("Results"); run("Close");
            print("Saved CSV:  " + outCSV);

            // Clean up mask windows
            close(winA);
            close(winB);
        }
    }
}
