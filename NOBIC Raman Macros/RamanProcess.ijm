//Integrated cell Raman spectra processing pipeline containing rejection of spectra acquired outside of cells,
//spike removal, piece-wise polynomial baseline subtraction including water peak, normalisation to large non-specific biomass peak, averaging and export as ASCII files (if these options are seleccted)
//Works on files in a folder and saves processed files in a sub-folder,
//To deal with cases where each spectrum is saved in a separate folder, the macro looks into subfolders and if the subfolder contains a single image, it wil process it
// plots intensity vs. wavelength or Raman shift wavenumber (if shift = true)
// the pixel to wavelength/wavenumber calibration as well as peak positions in pixels are based on the calibration of NOBIC Raman confocal micro-spectrometer.
//After changing the calibration-specific and values and specific pixel numbers, can be used for data acquired with other devices
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

macro "RamanProcess" {

	Dialog.create("Settings");
	Dialog.addCheckbox("remove spikes", true);
	Dialog.addCheckbox("subtract baseline", true);
	Dialog.addCheckbox("normalise spectra", true);
	Dialog.addCheckbox("show advanced settings", false);
	Dialog.show();

	despike = Dialog.getCheckbox(); //remove spikes
	SubtBase = Dialog.getCheckbox(); //subtract baseline
	norm = Dialog.getCheckbox(); //normalise spectra
	Advanced = Dialog.getCheckbox(); //enter advanced settings

	//parameters of x-axis calibration
	slope = 0.1292;   
	offset = 577.35;  // specific values determined by spectrometer calibration using organic compounds of well-known Raman spectra
	pixNum = 1024;   // number of camera pixels
	laser = 561;   //laser wavelength in nm
	shift = true;  // display as Raman shift
	label = "Raman shift/cm^-1";

	//parameters of out-of-cell spectra rejection
	MinPeak = -100; //minimum offset of large peak over silent region
	
	//spike removal parameters
	SpikeWidth = 3; //maximum spike width in pixels, 3 or 5 recommended
	SpikeThreshold = -70; //Threshold in 2nd differential image to identify spikes
	SpikeThreshold2 = 40; //Threshold of neighbouring pixel in 2nd differential image to identify spikes

	//output settings
	individSpectra = true; //plot all individual spectra after normalisation
	PeakNorm = 1000; //normalisation of the large peak;
	average = true; //calculate average spectrum
	export = true; //export as ASCII
	baseline = false; //plot fitted baselines

	//baseline subtration settings
	SegNum = 3; //number of segments within signature region
	Points = 5; //number of baseline points/segment within fingerprint region
	BCurve = 6; //polynomial degree
	BCurveN = "6th Degree Polynomial"; //polynomial degree
	ignoreInit = false; //ignore the first initial empty region - outside of spectrum range
	Bckg = 95; //camera offset
	
	//definitions of significant spectral regions
	Water1StartS = 3050; //Start for water peak integration1
	Water1EndS = 3350; //Start for water peak integration1
	Water2StartS = 3250; //Start for water peak integration2
	Water2End = pixNum; //End for water peak integration2
	WaterDivS = 3100; //ending point for fitting silent region baseline

	SilentStartS = 1850; //Start for silent region integration
	SilentEndS = 2750; //End for silent region integration
	SilentDivS = 2700; //Starting point for fitting water peak baseline

	LargeStartS = 2900; //Start for large cell peak integration
	LargeEndS = 2975; //End for large cell peak integration

	PeakFootStartS = 2850; //start of the region at  the foot of the large peak
	PeakFootEndS = 2900; //end of the region at the foot of the large peak

	InitEnd = 30; //end of initial empty region; 20 - 30 px. 

	Water1Start = ShifToPix(Water1StartS);
	Water2Start = ShifToPix(Water2StartS);
	Water1End = ShifToPix(Water1EndS);
	WaterDiv = ShifToPix(WaterDivS);
	SilentStart = ShifToPix(SilentStartS); 
	SilentEnd = ShifToPix(SilentEndS);
	SilentDiv = ShifToPix(SilentDivS);
	LargeStart = ShifToPix(LargeStartS);
	LargeEnd = ShifToPix(LargeEndS);
	PeakFootStart = ShifToPix(PeakFootStartS);
	PeakFootEnd = ShifToPix(PeakFootEndS);

	if (Advanced) {
		Dialog.create("Advanced Settings");
		Dialog.addMessage("Output settings:");
		Dialog.addCheckbox("plot individual spectra", individSpectra);
		Dialog.addCheckbox("plot baselines", baseline);
		Dialog.addMessage("Out-of-cell spectra rejection settings:");
		Dialog.addNumber("minimum height of non-specific peak", MinPeak);
		Dialog.addMessage("Despiking settings:");
		Dialog.addNumber("max. spike width in px.", SpikeWidth);
		Dialog.addNumber("spike threshold in 2nd diff image", SpikeThreshold); 
		Dialog.addNumber("neighbouring pixels threshold in 2nd diff image", SpikeThreshold2); 
		Dialog.addMessage("Baseline subtraction settings:");
		Dialog.addCheckbox("ignore initial segment", ignoreInit);
		Dialog.addNumber("number of segments in signature region:", SegNum ); 
		Dialog.addNumber("number of points per segment:", Points ); 
		Dialog.addMessage("Normalisation settings:");
		Dialog.addNumber("non-specific peak norm", PeakNorm ); 
		Dialog.show();

		individSpectra = Dialog.getCheckbox();
		baseline = Dialog.getCheckbox();
		MinPeak = Dialog.getNumber();
		SpikeWidth = Dialog.getNumber();
		SpikeThreshold = Dialog.getNumber();
		SpikeThreshold2 = Dialog.getNumber();
		ignoreInit = Dialog.getCheckbox();
		SegNum = Dialog.getNumber();
		Points = Dialog.getNumber();
		PeakNorm = Dialog.getNumber();
	}

	//user input
	Dir = getDirectory("Folder");
	setBatchMode(true);
	run("Clear Results");
	Resdir = Dir + "Processed" + File.separator;
	File.makeDirectory(Resdir);

	//prepare arrays for plotting
	x=newArray(pixNum);
	y=newArray(pixNum);
	MeanS=newArray(pixNum);
	ErroH=newArray(pixNum);
	ErroL=newArray(pixNum);
	//arrays for baseline subtraction
	Basenum0 = InitEnd + SilentDiv - SilentStart + Points*SegNum;
	Basenum1 = SilentEnd - SilentStart + WaterDiv - Water1Start + Points*SegNum;
	Basenum2 = Water1End - Water1Start + SilentEnd - SilentDiv;
	Basenum3 = Water2End - Water2Start;
	DivDist0 = SilentStart - InitEnd;
	DivDist = WaterDiv-Water1Start;
	DivDistW = Water1End-Water2Start;
	Baseline=newArray(pixNum);
	Baseline0=newArray(pixNum);
	Baseline1=newArray(pixNum);
	Baseline2=newArray(pixNum);
	Baseline3=newArray(pixNum);
	BaseX0=newArray(Basenum0);
	BaseY0=newArray(Basenum0);
	BaseX1=newArray(Basenum1);
	BaseY1=newArray(Basenum1);
	BaseX2=newArray(Basenum2);
	BaseY2=newArray(Basenum2);
	BaseX3=newArray(Basenum3);
	BaseY3=newArray(Basenum3);

	
	Min = newArray(Points);
	//array for despiking
	Val = newArray(2*SpikeWidth-1);

	//prepare plots
	for (i = 0; i < pixNum; i++) {	
		x[i] = offset + i*slope;				
		if (shift = = true) x[i] = (1/laser - 1/x[i])*10000000;
	}	
	Plot.create("plot",label,"intensity");

	//prepare for looping through directory
	list = getFileList(Dir);
	M = list.length;
	ImCount = 0;

	//new image to average spectra
	if (average){
		newImage("Average", "32-bit black", pixNum, M, 1);
		Average = getImageID();
	}

	//loop through the directory
	for (m=0; m<M; m++) {
		ImOpened = false; //no image opened yet
       	if (endsWith(list[m], ".tif")){
       		path = Dir+list[m];
       		open(path);
			ImOpened = true;
			name = list[m];
       	}
		if (endsWith(list[m], "/") && indexOf(list[m], "Processed")<0){ //if it's a sub-folder, check whether it contains asingle image, avoid the Processed subfolder
			subdir = Dir + list[m];
			sublist = getFileList(subdir);
			ImCounter = 0;
			name = substring(list[m], 0, lengthOf(list[m])-1);
			for (k = 0; k < sublist.length; k++) {
				if (endsWith(sublist[k], ".tif")){
					ImCounter++;
					subpath = subdir + sublist[k];
				}
				if (endsWith(sublist[k], "/")){ //if it's a sub-folder, check whether it contains asingle image
					subsubdir = subdir + sublist[k];
					subsublist = getFileList(subsubdir);
					for (p = 0; p < subsublist.length; p++) {// one more level of sub-folders
						if (endsWith(subsublist[p], ".tif")){
							ImCounter++;
							subpath = subsubdir + subsublist[p];
						}
					}
				}
			}
			if (ImCounter == 1) {
				path = subpath;
				open(path);
				ImOpened = true;
			}	
		}
       		
       	if (ImOpened){ //do processing only if an image has been opened
       		Orig = getImageID();   
       		run("Select None");
       		run("Duplicate...", " ");    		
       		Spect = getImageID();
       		run("32-bit");
       		run("Subtract...", "value="+Bckg);
       		selectImage(Spect);

       		//screen for out-of-cell spectra
       		makeRectangle(LargeStart, 0, LargeEnd-LargeStart, 1);
			getStatistics(area, PeakIntS);
			run("Select None");

			makeRectangle(PeakFootStart, 0, PeakFootStart-PeakFootEnd, 1);
			getStatistics(area, PeakFootIntS);
			run("Select None");

			CellScr = PeakIntS - PeakFootIntS;
			if (CellScr > MinPeak) {

				//despike
				if (despike) {
					Diff1 = diffImage(Spect);
					Diff2 = diffImage(Diff1);
					getDimensions(W, H, dummy, dummy, dummy);
					run("Select None");
				
					//search 2nd differential image for spikes
					for (k=0; k<2*SpikeWidth-2; k++) {
						Val[k]=getPixel(k, 0);
					}
		
					for (i=SpikeWidth-1; i<W-(SpikeWidth-1); i++) {
						SFlag1 = false;
						SFlag2 = false;
						SFlag3 = false;
						Val[2*SpikeWidth-2] = getPixel(i+SpikeWidth-1, 0);
						if (Val[SpikeWidth-1] < SpikeThreshold) {
							SFlag1 = true;
							posSp = i+1;
							for (k=0; k<SpikeWidth-1; k++) {
								if (Val[k] > SpikeThreshold2){
									SFlag2 = true;
									loB = i-(SpikeWidth-2)+k;
							}
								}
							for (k=SpikeWidth; k<2*SpikeWidth-1; k++) {
								if (Val[k] > SpikeThreshold2){
									SFlag3 = true;
									hiB = i+2+k-SpikeWidth;
								}
							}
						}
								
						if (SFlag1 && SFlag2 && SFlag3) {
							selectImage(Spect);
							LoVal = getPixel(loB, 0);
							HiVal = getPixel(hiB, 0);
							dist = hiB - loB;
							Grad = (HiVal - LoVal)/dist;
							for (j=1; j<dist; j++) {
								setPixel(loB + j, 0, LoVal + Grad*j);
							}
						}
						
						selectImage(Diff2);
						for (k=0; k<2*SpikeWidth-2; k++) {
							Val[k]=Val[k+1];
						}
					}
		
				
					selectImage(Diff1);
					close();
					selectImage(Diff2);
					close();
					selectImage(Spect);
				}

				//subtract baseline
				if (SubtBase) {
					pc0 = 0;
					
					for	(j = 0; j < InitEnd; j++) {
						BaseX0[pc0] = j;
						if (ignoreInit) BaseY0[pc0] = getPixel(InitEnd, 0);
						else BaseY0[pc0] = getPixel(j, 0);
						pc0++;
					}
	
					for	(j = SilentStart; j < SilentDiv; j++) {
						BaseX0[pc0] = j;
						BaseY0[pc0] = getPixel(j, 0);
						pc0++;
					}
					
					pc1 = 0;
	
					for	(j = SilentStart; j < SilentEnd; j++) {
						BaseX1[pc1] = j;
						BaseY1[pc1] = getPixel(j, 0);
						pc1++;
					}
					for	(j = Water1Start; j < WaterDiv; j++) {
						BaseX1[pc1] = j;
						BaseY1[pc1] = getPixel(j, 0);
						pc1++;
					}
	
					TestMin = -1000;
					SegLength = round((SilentStart - InitEnd)/SegNum);
					for (s = 0; s < SegNum; s++) {
						for	(k = 0; k < Points; k++) {
							Min[k] = 1000;
							for	(j = InitEnd+s*SegLength; j < InitEnd+(s+1)*SegLength; j++) {
								val = getPixel(j, 0);
								if ((val < Min[k])&&(val>TestMin)) {
									Min[k] = val;
									BaseX1[pc1] = j;
									BaseY1[pc1] = Min[k];
									BaseX0[pc0] = j;
									BaseY0[pc0] = Min[k];
								}
							}
							pc0++;
							pc1++;
							TestMin = Min[k];
						}
					}
	
					pc2 = 0;
					for	(j = SilentDiv; j < SilentEnd; j++) {
						BaseX2[pc2] = j;
						BaseY2[pc2] = getPixel(j, 0);
						pc2++;
					}
					for	(j = Water1Start; j < Water1End; j++) {
						BaseX2[pc2] = j;
						BaseY2[pc2] = getPixel(j, 0);
						pc2++;
					}

					pc3 = 0;
					for	(j = Water2Start; j < Water2End; j++) {
						BaseX3[pc3] = j;
						BaseY3[pc3] = getPixel(j, 0);
						pc3++;
					}

	
					for (i = 0; i < Water2End; i++) {
						Baseline[i] = 0;
						Baseline0[i] = 0;
						Baseline1[i] = 0;
						Baseline2[i] = 0;
						Baseline3[i] = 0;
					}
	
					Fit.doFit(BCurveN, BaseX0, BaseY0);
	
					for (i = 0; i < SilentStart; i++) {
						for (j = 0; j < BCurve+1; j++) {
							Baseline0[i] = Baseline0[i] + Fit.p(j) * pow(i,j);
						}
					}
			
					Fit.doFit(BCurveN, BaseX1, BaseY1);
	
		
					for (i = InitEnd; i < WaterDiv; i++) {
						for (j = 0; j < BCurve+1; j++) {
							Baseline1[i] = Baseline1[i] + Fit.p(j) * pow(i,j);
						}
					}
	
					Fit.doFit(BCurveN, BaseX2, BaseY2);
	
					for (i = SilentDiv; i < Water1End; i++) {
						for (j = 0; j < BCurve+1; j++) {
							Baseline2[i] = Baseline2[i] + Fit.p(j) * pow(i,j);
						}
					}

					Fit.doFit(BCurveN, BaseX3, BaseY3);
	
					for (i = Water2Start; i < Water2End; i++) {
						for (j = 0; j < BCurve+1; j++) {
							Baseline3[i] = Baseline3[i] + Fit.p(j) * pow(i,j);
						}
					}

	
					for (i = 0; i < InitEnd; i++) {
						if (ignoreInit) {
							Baseline[i] = Baseline0[i];
							val = getPixel(InitEnd,0) - Baseline[i];
							setPixel(i, 0, val);
						} else {
							Baseline[i] = Baseline0[i];
							val = getPixel(i, 0) - Baseline[i];
							setPixel(i, 0, val);
						}
					}
	
					for (i = InitEnd; i < SilentStart; i++) {
						f = (i-InitEnd)/DivDist0;
						Baseline[i] = f*Baseline1[i] + (1-f)*Baseline0[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}
	
					for (i = SilentStart; i < Water1Start; i++) {
						Baseline[i] = Baseline1[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}
	
					for (i = Water1Start; i < WaterDiv; i++) {
						f = (i-Water1Start)/DivDist;
						Baseline[i] = f*Baseline2[i] + (1-f)*Baseline1[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}
	
					for (i = WaterDiv; i < Water2Start; i++) {
						Baseline[i] = Baseline2[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}

					for (i = Water2Start; i < Water1End; i++) {
						f = (i-Water2Start)/DivDistW;
						Baseline[i] = f*Baseline3[i] + (1-f)*Baseline2[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}

					for (i = Water1End; i < Water2End; i++) {
						Baseline[i] = Baseline3[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}

				}
				//secondary screening to avoid apparently high peaks caused by baseline
				makeRectangle(LargeStart, 0, LargeEnd-LargeStart, 1);
				getStatistics(area, PeakIntS);
				run("Select None");
	
				makeRectangle(PeakFootStart, 0, PeakFootStart-PeakFootEnd, 1);
				getStatistics(area, PeakFootIntS);
				run("Select None");
	
				CellScr = PeakIntS - PeakFootIntS;
				if (CellScr > MinPeak) {

					//normalise
					if(norm) {
						makeRectangle(LargeStart, 0, LargeEnd-LargeStart, 1);
						getStatistics(area, PeakInt);
						run("Select None");
						
						run("Multiply...", "value="+PeakNorm/PeakInt);
					}
	
					//collect values for plotting, averaging and export
					for (i = 0; i < pixNum; i++) {
						selectImage(Spect);	
						y[i] = getPixel(i, 0);
						if (average) {
							selectImage(Average);
							setPixel(i, ImCount, y[i]);	
						}
						setResult(label, i, x[i]);
						setResult("value", i, y[i]);
						setResult("baseline", i, Baseline[i]);
					}
		
					if (individSpectra) {
						Plot.setColor("gray");
						Plot.add("line",x,y);
						if (baseline){	
							Plot.setColor("black");
							Plot.add("line",x,Baseline);
						}
					}
				
					selectImage(Spect);
					Stack.setXUnit("px");
					run("Properties...", "channels=1 slices=1 frames=1 pixel_width=1 pixel_height=1 voxel_depth=1.0000000 frame=[0.00 sec]");
					saveAs("Tif", Resdir+name);
					close();
					ImCount++;
					
					if (export) saveAs("Results", Resdir+name+".csv");
					run("Clear Results");
					
				} else {
					selectImage(Spect);
					close();
				}
			} else {
				selectImage(Spect);
				close();
			}
			selectImage(Orig);
       		close();
       	}
       	showProgress(m+1, M+1);
	}

	//calculate average spectrum and standard deviations
	if(average) {
		
		for (i = 0; i < pixNum; i++) {
			selectImage(Average);	
			makeRectangle(i, 0, 1, ImCount);
			getStatistics(area, MeanS[i], min, max, Std);
			setResult(label, i, x[i]);
			setResult("Mean", i, MeanS[i]);
			setResult("Std", i, Std);
			ErroH[i] = MeanS[i] + Std;
			ErroL[i] = MeanS[i] - Std;
		}	
		
		Plot.setColor("blue");
		Plot.add("line",x,MeanS);
		Plot.add("dots",x,ErroH);
		Plot.add("dots",x,ErroL);
	
		selectImage(Average);
		close();
		saveAs("Results", Resdir+"Averaged.csv");
	}

	//write settings to Log and save as text
	print("\\Clear"); //clear the Log
	print("parameters of out-of-cell spectra rejection:");
	print("MinPeak = "+ MinPeak +" //minimum offset of large peak over silent region"); 
	print(" ");
	print("spike removal parameters:");
	print("despike = " + despike +" //remove spikes");
	if (despike) {
		print("SpikeWidth = "+ SpikeWidth +" //maximum spike width in pixels, 3 or 5 recommended");
		print("SpikeThreshold = " + SpikeThreshold +" //Threshold in 2nd differential image to identify spikes");
		print("SpikeThreshold2 = " + SpikeThreshold2 +" //Threshold of neighbouring pixel in 2nd differential image to identify spikes");
	}
	
	print(" ");
	print("processing settings:");
	print("Bckg = " + Bckg +" //camera offset");
	print("norm = " + norm +" //normalise spectra");
	if (norm) print("PeakNorm = " + PeakNorm +" //normalisation of the large peak");
	print ("SubtBase =" + SubtBase +" //subtract baseline");
	if (SubtBase) {
		print("SegNum = " + SegNum +" //number of segments within signature region");
		print("Points = " + Points +" //number of baseline points/segment within fingerprint region");
		print("BCurveN = " + BCurveN +" //polynomial degree");
		print("ignoreInit = " + ignoreInit +"//ignore the first initial empty region - outside of spectrum range");
		print(" ");
		print("definitions of significant spectral regions:");
		print("Water1Start = " + Water1Start +" //Start for water peak integration 1");
		print("Water2Start = " + Water2Start +" //Start for water peak integration 2");
		print("Water1End = " + Water1End + " //End for water peak integration 1");
		print("Water2End = " + Water2End + " //End for water peak integration 2");
		print("WaterDiv = " + WaterDiv +" //ending point for fitting silent region baseline");
	
		print("SilentStart = " + SilentStart +" //Start for silent region integration");
		print("SilentEnd = " + SilentEnd +" //End for silent region integration");

		print("InitEnd = " + InitEnd +" //end of initial empty region");
	}
		
	print("PeakFootStart = " + PeakFootStart +" //start of the region at  the foot of the large peak");
	print("PeakFootEnd = " + PeakFootEnd +" //end of the region at the foot of the large peak");

	print("LargeStart = " + LargeStart +" //Start for large cell peak integration");
	print("LargeEnd = " + LargeEnd +" //End for large cell peak integration");
	print(" ");
	print("parameters of x-axis calibration - specific values determined by spectrometer calibration:");
	print("slope = " + slope);   
	print("offset = " + offset);
	print("pixNum = " + pixNum +"  // number of camera pixels");
	print("laser = " + laser +"  //laser wavelength in nm");

	selectWindow("Log");
	saveAs("Text", Resdir + "Settings.txt");
	run("Close");
	
	setBatchMode("exit and display");
	Plot.setLimits(x[0], x[pixNum-1], NaN, NaN);
	
	//differential image function used for de-spiking
	function diffImage(Im) {
		getDimensions(w, h, dummy, dummy, dummy);
		makeRectangle(0, 0, w-1, h);
		run("Duplicate...", "title=Spect1");
		selectImage(Im);
		makeRectangle(1, 0, w, h);
		run("Duplicate...", "title=Spect2");
		imageCalculator("Subtract create 32-bit", "Spect2","Spect1");
		Diff = getImageID();
		close("Spect1");
		close("Spect2");
		return (Diff);
	}

	//conversion of shifts in /cm to pixels using known calibration
	function ShifToPix (K) {
		Val = (1/(1/laser - K/10000000) - offset)/slope;
		return round(Val);
	}

}