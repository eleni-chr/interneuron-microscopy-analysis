// STEP 14: NORMALISE DOUBLE‐POSITIVE DISTANCES

// Ask for the top‐level folder
mainDir = getDirectory("Choose your MainFolder");

// Channel‐label ↔ prefix lookup arrays
prefA_arr = newArray("ch00",       "ch03",         "ch03");
labA_arr  = newArray("ChAT",       "Parvalbumin",  "Parvalbumin");
prefB_arr = newArray("ch02",       "ch02",         "ch01");
labB_arr  = newArray("GAD67",      "GAD67",        "Calbindin");

// Suffix for double‐pos CSVs
suffix = "_double_pos_distances_angles.csv";

// Iterate first‐level → inner subfolders
firstList = getFileList(mainDir);
for (i = 0; i < firstList.length; i++) {
    if (!File.isDirectory(mainDir + firstList[i])) continue;
    subDir = mainDir + firstList[i] + File.separator;
    innerList = getFileList(subDir);
    for (j = 0; j < innerList.length; j++) {
        if (!File.isDirectory(subDir + innerList[j])) continue;
        innerDir = subDir + innerList[j] + File.separator;
        print("Processing “" + innerList[j] + "”");

        // 1.) Find the gray‐matter ROI
        files = getFileList(innerDir);
        roiFound = false;
        for (k = 0; k < files.length; k++) {
            if (endsWith(files[k], "_gray_matter.zip")) {
                roiFile = innerDir + files[k];
                roiFound = true;
                break;
            }
        }
        if (!roiFound) {
            print("  No gray matter ROI found — skipping.");
            continue;
        }

        // 2.) Loop over every double‐pos distances_angles CSV
        for (k = 0; k < files.length; k++) {
            csvFile = files[k];
            if (!endsWith(csvFile, suffix)) continue;

            // Extract markers and find prefix
            labelRoot = substring(csvFile, 0, lengthOf(csvFile) - lengthOf(suffix));
            parts = split(labelRoot, "_");
            if (parts.length < 2) {
                print("  Unexpected CSV name: " + csvFile + " — skipping.");
                continue;
            }
            labelA = parts[0];
            labelB = parts[1];
            pIndex = -1;
            for (m = 0; m < labA_arr.length; m++) {
                if (labA_arr[m]==labelA && labB_arr[m]==labelB) {
                    pIndex = m; break;
                }
            }
            if (pIndex < 0) {
                print("  No channel prefix for " + labelA + "+" + labelB + " — skipping.");
                continue;
            }
            prefix = prefA_arr[pIndex] + "_MAX";
            templateFile = innerDir + prefix + ".tif";
            if (!File.exists(templateFile)) {
                print("  Missing image: " + prefix + ".tif — skipping " + csvFile);
                continue;
            }

            // Determine DT filename
            dtName = prefix + "_Distance_Transform.tif";
            dtPath = innerDir + dtName;

            // 3.) Open or generate the Distance Transform (ROI‐based)
            if (File.exists(dtPath)) {
                print("  Reusing existing DT: " + dtName);
                open(dtPath);
            } else {
                print("  Generating ROI‐based DT for " + prefix);
                // a) get image size
                open(templateFile);
                w = getWidth();
                h = getHeight();
                close();
                // b) blank mask
                newImage("gm_mask", "8-bit black", w, h, 1);
                // c) fill gray‐matter ROI
                roiManager("reset");
                roiManager("Open", roiFile);
                roiManager("Select", 0);
                selectWindow("gm_mask");
                run("Fill");
                // d) binarise
                setThreshold(1, 255);
                run("Convert to Mask");
                // e) DT
                run("Distance Map");
                rename(dtName);
                saveAs("Tiff", dtPath);
                print("  Saved new DT: " + dtName);
                // DT remains open
            }

            // 4.) Compute max for normalization
            getStatistics(area, mean, min, maxVal, std);
            if (maxVal == 0) {
                print("  DT max=0 for " + dtName + " — skipping CSV.");
                close();       // close DT
                roiManager("reset");
                continue;
            }
            print("  Max DT = " + maxVal);

            // 5.) Read the CSV & append DT values (inverted norm)
            csvPath = innerDir + csvFile;
            text = File.openAsString(csvPath);
            lines = split(text, "\n");
            if (lines.length < 2) {
                print("  Empty CSV " + csvFile + " — skipping.");
                close();       // close DT
                roiManager("reset");
                continue;
            }
            newCSV = lines[0] + ",DT_distance,Normalised_DT_distance\n";
            for (n = 1; n < lines.length; n++) {
                line = trim(lines[n]);
                if (line == "") continue;
                fields = split(line, ",");
                x = parseFloat(fields[1]);
                y = parseFloat(fields[2]);
                dtVal = getPixel(round(x), round(y));
                normDT = 1.0 - (dtVal / maxVal);
                newCSV += line + "," + dtVal + "," + normDT + "\n";
            }
            outName = replace(csvFile, suffix, "_double_pos_DT.csv");
            File.saveString(newCSV, innerDir + outName);
            print("  Wrote: " + outName);

            // Clean up before next CSV
            close();           // close DT image
            roiManager("reset");
        }
    }
}
print("Distance normalisation complete.");

