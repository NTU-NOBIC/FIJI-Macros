// Macro to extract spectra from .czi stacks in a selected folder
// extracted spectra are saved in an ASCII table, information from metadata is saved in a separate file
// allows thresholding, to extract spectra only from pixels with maximum intensity (across the stack) in a selected range
// Radek Machan and Marie Olsinova, IMCF, NOBIC radek.machan@nu.edu.sg, marie.olsinova@natur.cuni.cz, www.nobic.sg, https://www.biocev.eu/en/services/imaging-methods.8

macro SpectraExtract_CZI {
	// set thresholds
	Dialog.create("SpectraExtract - set thresholds spectrum maximum");
	Dialog.addNumber("Lower limit",0);
	Dialog.addNumber("Upper limit",65535);
	Dialog.addCheckbox("Apply thresholds", false);
	Dialog.show();
	
	maxiL = Dialog.getNumber; //lower threshold for maximum intensity
	maxiH = Dialog.getNumber; //upper threshold for maximum intensity
	doThreshold = Dialog.getCheckbox;	// Boolean to determine whether to apply thresholds - the program is faster without them
	
	// select folder and open files
	folder = getDirectory("Choose Images Directory"); 
	list = getFileList(folder); 
	run("Clear Results");
	setBatchMode(true); 
	
	for (i=0; i < list.length; i++) { 
		if (endsWith(list[i], ".czi")) {	
			path = folder+list[i]; 	
			run("Bio-Formats Importer", "open=path open_all_series view=Hyperstack stack_order=XYCZT");
			title = getTitle();
			selectImage(title);
			getDimensions(wx, hy, LambNum, dummy, dummy);
	
			// if thresholding selected determine the valid pixels (according to thresholds) and their number
			if (doThreshold) pixCount = ThresholdPix(title);
	
			selectImage(title);
	
			// determine metadata for the stack
			q = 0;
			Mname = "PinholeSize";
			Meta = getTag("Information|Image|Channel|VirtualPinholeSize #01");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
	   		Mname = "PixelTime";
			Meta = getTag("Information|Image|Channel|LaserScanInfo|PixelTime #01");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
	   		Mname = "DigitalGain";
			Meta = getTag("Information|Image|Channel|DigitalGain #01");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
			Mname = "Gain";
			Meta = getTag("Information|Image|Channel|Gain #01");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
			Mname = "Averaging";
			Meta = getTag("Information|Image|Channel|LaserScanInfo|Averaging #01");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
			Mname = "PixelDimX";
			Meta = getTag("Scaling|Distance|Value #1");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
			Mname = "PixelDimY";
			Meta = getTag("Scaling|Distance|Value #2");
			setResult("lambda_"+title, q, Mname);
	   		setResult(title, q, Meta);
	   		q++;
			
			
			for (c = 0; c < LambNum; c++) {		// loop over all frames to determine the averages and wavelength
				setSlice(c + 1);
				
				if (doThreshold) {
					spectVal = 0;					// determine the average value over all valid pixels in given frame
					for (x = 0; x < wx; x++) {
						for (y = 0; y < hy; y++) {
							val = getPixel(x,y);
							spectVal = spectVal + val;
						}
					}
					spectVal = spectVal/pixCount;
				} else {
					getStatistics(dummy,spectVal);			// or over all pixels if no threshoding is done
				}
	
				// determine the wavelength corresponding to the given frame from image metadata
				if (c < 9) {
					spectLamb = getTag("Information|Image|Channel|Name #0"+ c + 1);
	   			} else {
	   				spectLamb = getTag("Information|Image|Channel|Name #"+ c + 1);
	   			}
	
	   			// write the spectra point into Results
	   			setResult("lambda_"+title, c + q, spectLamb);
	   			setResult(title, c + q, spectVal);
			}
		}
	}
	saveAs("Results", folder+"Spectra.xls");
	print("\\Clear");
	selectWindow("Log");
	run ("Close");
	
	// function to extract value of a particular parameter from the image metadata
	function getTag(tag) {
		info = getImageInfo();
		index0 = indexOf(info, tag);
		if (index0==-1) return "";
		index1 = indexOf(info, "=", index0);
		if (index1==-1) return "";
		index2 = indexOf(info, "\n", index1);
		value = substring(info, index1+1, index2);
		return value;
	}           
	
	// function to threshold pixels and count valid pixels
	function ThresholdPix(title) {
		selectImage(title);
		run("Z Project...", "start=1 stop="+LambNum+" projection=[Max Intensity]");
		
		selectImage("MAX_"+title);
			
		pixCount = 0;
		for (x = 0; x < wx; x++) {
			for (y = 0; y < hy; y++) {
				pixMax = getPixel(x,y);
				if ((pixMax > maxiL) && (pixMax < maxiH)) {
					pixMask = 1;
					pixCount++;
				}
				else pixMask = 0;
				setPixel(x,y,pixMask);
			}
		}
		
		imageCalculator("Multiply stack", title,"MAX_"+title);
		return pixCount;
	}
}







