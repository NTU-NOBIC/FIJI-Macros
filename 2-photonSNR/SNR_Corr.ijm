macro SNR_Corr {
	//definition of constants
	maxCorrelDist = 10;

	shiftX = newArray(1,-1);
	shiftY = newArray(1,-1);
	
	setBatchMode("hide");
	
	getDimensions(wX, hY, ChanNum, NumZ, NumF);
	if (NumF > NumZ) {
		NumZ = NumF;
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	}
	
	ImgId = getImageID();

	name = getTitle();
	Dir = getDirectory("image");
	Resdir = Dir+"Results"+ File.separator;
	if (! File.isDirectory(Resdir)) File.makeDirectory(Resdir);

	TestWidth = wX - 2*maxCorrelDist;
	TestHeight = hY - 2*maxCorrelDist;

	Corrdist=newArray(maxCorrelDist + 1);
	CorrX=newArray(maxCorrelDist + 1);
	CorrY=newArray(maxCorrelDist + 1);
	ErCorrX=newArray(maxCorrelDist + 1);
	ErCorrY=newArray(maxCorrelDist + 1);

	//setting correlations for 0 shift
	
	Corrdist[0] = 0;
	CorrX[0] = 1;
	CorrY[0] = 1;
	ErCorrX[0] = 0;
	ErCorrY[0] = 0;
	setResult("CorrX", 0, CorrX[0]);
	setResult("CorrY", 0, CorrY[0]);
	setResult("ErrCorrX", 0, ErCorrX[0]);
	setResult("ErrCorrY", 0, ErCorrY[0]);
	
	for(i=1;i<maxCorrelDist+1;i++) {
		Corrdist[i] = i;
		CorrX[i] = 0;
		CorrY[i] = 0;
		ErCorrX[i] = 0;
		ErCorrY[i] = 0;
	}
	
	//itterate through all frames and calculate correlations
	
	for (n = 0; n < NumZ; n++) {
		
		selectImage(ImgId);
		Stack.setSlice(n);
		run("Duplicate...", "ignore use");
		orig=getImageID();
		makeRectangle(maxCorrelDist, maxCorrelDist, TestWidth, TestHeight);
		run("Crop");
		subtMean(orig);
	
		imageCalculator("Multiply create 32-bit stack", orig, orig);
		mso = calcMean();
		close();
		
		//cropping shifted images and calculating respective correlations
	
		for(i=1;i<maxCorrelDist+1;i++) {
	
			CX = 0;
			CY = 0;
	
			for(j=0;j<1;j++) {
	
				selectImage(ImgId);
				Stack.setSlice(n);
				run("Duplicate...", "ignore use");
				ShiftX=getImageID();
				makeRectangle(maxCorrelDist + i*shiftX[j], maxCorrelDist, TestWidth, TestHeight);
				run("Crop");
				subtMean(ShiftX);
				imageCalculator("Multiply create 32-bit stack", ShiftX, ShiftX);
				mssX = calcMean();
				close();
				
				selectImage(ImgId);
				Stack.setSlice(n);
				run("Duplicate...", "ignore use");
				ShiftY=getImageID();
				makeRectangle(maxCorrelDist, maxCorrelDist + i*shiftY[j], TestWidth, TestHeight);
				run("Crop");
				subtMean(ShiftY);
				imageCalculator("Multiply create 32-bit stack", ShiftY, ShiftY);
				mssY = calcMean();
				close();
		
				imageCalculator("Multiply create 32-bit stack", orig, ShiftX);
				aCX = calcMean();
				close();
				imageCalculator("Multiply create 32-bit stack", orig, ShiftY);
				aCY = calcMean();
				close();
				
				CX = CX + aCX / sqrt(mso * mssX);
				CY = CY + aCY / sqrt(mso * mssY);
				
				selectImage(ShiftX);
				close();
				selectImage(ShiftY);
				close();
			}
			
			CorrX[i] = CorrX[i] + CX;
			CorrY[i] = CorrY[i] + CY;	
			ErCorrX[i] = ErCorrX[i] + pow(CX,2);
			ErCorrY[i] = ErCorrY[i] + pow(CY,2);
		}

		selectImage(orig);
		close();
		showProgress(n+1, NumZ-1);
	}
	
	for(i=1;i<maxCorrelDist+1;i++) {
		ErCorrX[i] = sqrt((ErCorrX[i]/NumZ - pow((CorrX[i]/NumZ),2))*NumZ/(NumZ-1));
		CorrX[i] =CorrX[i]/NumZ;
		ErCorrY[i] = sqrt((ErCorrY[i]/NumZ - pow((CorrY[i]/NumZ),2))*NumZ/(NumZ-1));
		CorrY[i] =CorrY[i]/NumZ;
		setResult("CorrX", i, CorrX[i]);
		setResult("CorrY", i, CorrY[i]);
		setResult("ErrCorrX", i, ErCorrX[i]);
		setResult("ErrCorrY", i, ErCorrY[i]);
	}

	Plot.create("plot","dist/pix","corr");
	Plot.setColor("green");
	Plot.add("line",Corrdist,CorrX);
	Plot.setColor("red");
	Plot.add("line",Corrdist,CorrY);
	Plot.setLimits(NaN, NaN, NaN, 1);
	Plot.show();
	saveAs("Tiff", Resdir + "CorrProfiles_" + name);
	
	saveAs("results", Resdir + name + "_CorrResults");
	
	setBatchMode("exit and display");
	
	SNR = sqrt(CorrY[1]/(1-CorrY[1]));
	ErSNR = ErCorrY[1]/sqrt(2*sqrt(CorrY[1]*pow(1-CorrY[1],3)));
	print("SNRcorrY(1) = " + SNR + " +/- " + ErSNR);

	// function to subtract the mean from a frame
	function subtMean(stackID) {
		selectImage(stackID);
		run("32-bit");
		getStatistics(dummy, Mean);
		run("Subtract...", "value=" + Mean);
	}

	// function to get mean of an image
	function calcMean() {
		getStatistics(dummy, mean);
		return mean;
	}
}
