//a macro to evaulate the total leaf area of seedlings on plates in colour photographs
//all photographs in the set are expected to be taken from the same distance, thus the scaling is the same for all and has been determined from one of the photographs
//can be run on a folder or on the active image (testing mode), selection in the initial dialogue; if folder is selected, the masks are saved for reference as well as a result table with leaf areas
//written for Omkar Kulkarni, SCELSE, NUS by Radek Machan, NOBIC, www.nobic.sg

macro "LeafSize3" {

ReScale = true; // define scaling for the image
PROI = true;
Blur = false; //do not apply Gaussian blur before thresholding
BlurSize = 0.02; //default blur size in cm
Mclose = true; //run morphological closure on masks;
M = 1;
ImOpen = true;
Alg0 = false;
Cleanup = false;

Dialog.create("Settings");
Dialog.addMessage("If not loaded from folder, the active image will be used");
Dialog.addCheckbox("Load images from folder", true);
Dialog.addMessage("Gaussian Blur smoothes the image, may help segmentation of seedlings in soil");
Dialog.addCheckbox("Apply Gaussian blur", false);
Dialog.addNumber("Gaussian Blur diameter [cm]", BlurSize);
Dialog.addMessage("The 'old' segmentation algorithm is less robust under unfavourable conditions, e.g. very small seedlings or presence of condenstaion; for larger seedlings it is less prone to false positives");
Dialog.addCheckbox("Use 'old' algorithm", false);
Dialog.addMessage("Manual cleanup allows you to manually remove false positive features; works onlyonindividual images, selecting this feature disables running on folder");
Dialog.addCheckbox("Apply manual cleanup", false);
Dialog.show();

folder = Dialog.getCheckbox(); //inport images from a folder
Blur = Dialog.getCheckbox(); //apply Gaussian blur 
BlurSize = Dialog.getNumber(); //Gaussian blur diameter
Alg0 = Dialog.getCheckbox(); //use old algorithm
Cleanup = Dialog.getCheckbox(); //do manual cleanup

if (Cleanup) folder = false;

//select ROI of seedlings
setTool("rectangle");
waitForUser("Seedlings ROI","Open an image, if not opened yet, and draw an ROI to be evaluated. If no image is opened or ROI is drawn, the whole image will be used");
if (nImages < 1) PROI = false;
else getSelectionBounds(PRectX, PRectY, PRectW, PRectH);

//define scale
setTool("line");
waitForUser("Scaling","Draw a line of 5 cm length in the image. If no line is drawn, the original scaling of the image will be retained.");
if (nImages > 0 && selectionType == 5) {
	getLine(x1, y1, x2, y2, dummy);
	Llength = sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1));
	pixelsPercm = Llength/5;
}
else ReScale = false;

//choose image directory
if (folder) {
	Dir = getDirectory("Choose Image Directory");
	list = getFileList(Dir);
	M = list.length;
	MaskDir = Dir + "Masks" + File.separator;
	File.makeDirectory(MaskDir);
}

//setting running environment
run("Clear Results");
setBatchMode(true); 
print("\\Clear"); //clear Results
run("Conversions...", " ");

//looping through all images in the directory

for (m=0; m < M; m++) { 
		if (folder) {
			ImOpen = false;
			if (endsWith(list[m], ".jpg") || endsWith(list[m], ".JPG")) { //check for correct image format
				path = Dir+list[m];
				//open new image
				open(path);
				ImOpen = true;
			}
		}

		if (ImOpen) {

			Original = getImageID();
			Name = getTitle();
			if (!ReScale) {
				getPixelSize(unit, pixelWidth, pixelHeight);
				if (unit == "cm") pixelsPercm = 1/pixelWidth;
				else if (unit == "mm") pixelsPercm = 10/pixelWidth;
				else pixelsPercm = NaN;
			}
			//calibrate pixels
			if (ReScale) run("Set Scale...", "distance="+pixelsPercm+" known=1 pixel=1 unit=cm");
			
			//select ROI containing the seedlings
			if (PROI) makeRectangle(PRectX, PRectY, PRectW, PRectH);
			run("Duplicate...", "title=plants");
			run("Duplicate...", "title=plantsL");
			
			//convert to CIELAB colour space
			selectWindow("plantsL");
			run("Lab Stack");

			//run thresholding on all channels
			if (Alg0) {
				Stack.setChannel(1);
				run("Duplicate...", "title=L");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
				setAutoThreshold("Otsu dark no-reset");
				run("Convert to Mask");
				if (Mclose) run("Close-");
				selectWindow("plantsL");
				Stack.setChannel(2);
				run("Duplicate...", "title=a");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
				setAutoThreshold("Otsu no-reset");
				run("Convert to Mask");
				if (Mclose) run("Close-");
				selectWindow("plantsL");
				Stack.setChannel(3);
				run("Duplicate...", "title=b");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
				setAutoThreshold("Li dark no-reset");
				run("Convert to Mask");
				if (Mclose) run("Close-");
				imageCalculator("Multiply", "L","a");
				imageCalculator("Multiply", "L","b");
				run("Open");
				
			} else {
				
				Stack.setChannel(1);
				run("Duplicate...", "title=L");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
				selectWindow("plantsL");
				Stack.setChannel(2);
				run("Duplicate...", "title=a");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
				selectWindow("plantsL");
				Stack.setChannel(3);
				run("Duplicate...", "title=b");
				if (Blur) run("Gaussian Blur...", "sigma="+BlurSize+" scaled slice");
				run("Enhance Contrast", "saturated=0.35");
	
				imageCalculator("Add", "b","L");
				imageCalculator("Subtract", "b","a");
				imageCalculator("Multiply", "L","a");
	
				selectWindow("b");
				setAutoThreshold("MaxEntropy dark no-reset");
				run("Convert to Mask");
				run("Open");
				if (Mclose) run("Close-");
	
				selectWindow("L");
				setAutoThreshold("MaxEntropy no-reset");
				run("Convert to Mask");
				run("Open");
				if (Mclose) run("Close-");
				
				imageCalculator("Multiply", "L","b");
				run("Open");
			}

			//close windows
			selectWindow("plantsL");
			close();
			selectWindow("a");
			close();
			selectWindow("b");
			close();
			selectImage(Original);
			close();

			selectWindow("L");

			if (Cleanup) {
				setBatchMode("exit and display");
				setTool("rectangle");
				waitForUser("Mask Cleanup","Select ROI(s) with the features to be removed from the mask. Select multiple ROIs by holding Shift key");
				run("Clear", "slice");
				run("Select None");
			}

			//measure the average value - corresponds to leaf area
			getStatistics(Area, mean);
			LeafArea = Area*mean/255;
			
			//output results
			setResult("Name", m, Name);
			setResult("Leaf Area/cm^2", m, LeafArea);
			setResult("Pixels/cm", m, pixelsPercm);

			//save mask
			if (folder) {
				selectWindow("L");
				saveAs("Tiff", MaskDir+list[m]);
				close();
				selectWindow("plants");
				close();
				showProgress(m+1, M+1);
			}
						
		}
	}
	//save results
	if (folder) {
		saveAs("Results", Dir+"Results.xls");
		close("*");
	}
	
	selectWindow("Log");
	run ("Close");
	if (!Cleanup) setBatchMode("exit and display");
	
}