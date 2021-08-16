//Integrated cell Raman spectra processing pipeline containing rejection of spectra acquired outside of cells,
//spike removal, piece-wise polynomial baseline subtraction including water peak, normalisation to large non-specific biomass peak, averaging and export as ASCII files (if these options are seleccted)
//Works on files in a folder and saves processed files in a sub-folder,
// plots intensity vs. wavelength or Raman shift wavenumber (if shift = true)
// the pixel to wavelength/wavenumber calibration as well as peak positions in pixels are based on the calibration of NOBIC Raman confocal micro-spectrometer.
//After changing the calibration-specific and values and specific pixel numbers, can be used for data acquired with other devices
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

macro "RamanProcess" {

	//parameters of out-of-cell spectra rejection
	MinPeak = 200; //minimum offset of large peak over silent region
	
	//spike removal parameters
	SpikeWidth = 3; //maximum spike width in pixels, 3 or 5 recommended
	SpikeThreshold = -70; //Threshold in 2nd differential image to identify spikes
	SpikeThreshold2 = 40; //Threshold of neighbouring pixel in 2nd differential image to identify spikes

	//output settings
	individSpectra = true; //plot all individual spectra after normalisation
	baseline = false; //plot fitted baselines
	norm = true; //normalise spectra
	average = true; //calculate average spectrum
	export = true; //export as ASCII
	Points = 6; //number of baseline points within fingerprint region
	BCurve = 6; //polynomial degree
	BCurveN = "6th Degree Polynomial" //polynomial degree

	Bckg = 95; //camera offset
	PeakNorm = 1000; //normalisation of the large peak;
	
	//definitions of significant spectral regions
	WaterStart = 780; //Start for water peak integration
	WaterEnd = 1024; //End for water peak integration
	WaterDiv = 800; //ending point for fitting silent region baseline

	SilentStart = 400; //Start for silent region integration
	SilentEnd = 630; //End for silent region integration
	SilentDiv = 600; //Starting point for fitting water peak baseline

	InitEnd = 20; //end of initial empty region;
	Init2Start = 50;//start of second empty initial regio;
	SignStart = 80; //Start for signature region integration
	SignEnd = 350; //End for ssignature region integration

	PeakFootStart = 695; //start of the region at  the foot of the large peak
	PeakFootEnd = 720; //end of the region at the foot of the large peak

	LargeStart = 720; //Start for large cell peak integration
	LargeEnd = 740; //End for large cell peak integration

	//parameters of x-axis calibration
	slope = 0.1292;   
	offset = 577.35;  // specifi values determined by specttrometer calibration using organic compounds of well-known Raman spectra
	pixNum = 1024;   // number of camera pixels
	refRate = 100;  //plot resfresh rate in ms
	laser = 561;   //laser wavelength in nm
	shift = true;  // display as Raman shift
	label = "wavelenght/nm";
	if (shift = = true) label = "Raman shift/cm^-1";

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
	Basenum1 = InitEnd + SignStart - Init2Start + SilentEnd - SilentStart + WaterDiv - WaterStart + Points;
	Basenum2 = WaterEnd - WaterStart + SilentEnd - SilentDiv;
	DivDist = WaterDiv-SilentDiv;
	Baseline=newArray(pixNum);
	Baseline1=newArray(pixNum);
	Baseline2=newArray(pixNum);
	BaseX1=newArray(Basenum1);
	BaseY1=newArray(Basenum1);
	BaseX2=newArray(Basenum2);
	BaseY2=newArray(Basenum2);
	Min = newArray(Points);
	//array for despiking
	Val = newArray(2*SpikeWidth-1);

	//prepare plots
	for (i = 0; i < pixNum; i++) {	
		x[i] = offset + i*slope;				
		if (shift = = true) x[i] = (1/laser - 1/x[i])*10000000;
	}	
	Plot.create("plot",label,"instensity");

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
       	if (endsWith(list[m], ".ome.tif")){

       		//open file and create a working duplicate of the image
       		path = Dir+list[m];
       		open(path);
       		name = getTitle();
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

				//subtract baseline
				pc = 0;
				for	(j = 0; j < InitEnd; j++) {
					BaseX1[pc] = j;
					BaseY1[pc] = getPixel(j, 0);
					pc++;
				}
				for	(j = Init2Start; j < SignStart; j++) {
					BaseX1[pc] = j;
					BaseY1[pc] = getPixel(j, 0);
					pc++;
				}
				for	(j = SilentStart; j < SilentEnd; j++) {
					BaseX1[pc] = j;
					BaseY1[pc] = getPixel(j, 0);
					pc++;
				}
				for	(j = WaterStart; j < WaterDiv; j++) {
					BaseX1[pc] = j;
					BaseY1[pc] = getPixel(j, 0);
					pc++;
				}

				TestMin = -1000;
				for	(k = 0; k < Points; k++) {
					Min[k] = 1000;
					for	(j = SignStart; j < SignEnd; j++) {
						val = getPixel(j, 0);
						if ((val < Min[k])&&(val>TestMin)) {
							Min[k] = val;
							BaseX1[pc] = j;
							BaseY1[pc] = Min[k];
						}
					}
					pc++;
					TestMin = Min[k];
				}

				pc = 0;
				for	(j = SilentDiv; j < SilentEnd; j++) {
					BaseX2[pc] = j;
					BaseY2[pc] = getPixel(j, 0);
					pc++;
				}
				for	(j = WaterStart; j < WaterEnd; j++) {
					BaseX2[pc] = j;
					BaseY2[pc] = getPixel(j, 0);
					pc++;
				}								
		
				Fit.doFit(BCurveN, BaseX1, BaseY1);

				for (i = 0; i < WaterEnd; i++) {
					Baseline[i] = 0;
					Baseline1[i] = 0;
					Baseline2[i] = 0;
				}
	
				for (i = 0; i < WaterDiv; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline1[i] = Baseline1[i] + Fit.p(j) * pow(i,j);
					}
				}

				Fit.doFit(BCurveN, BaseX2, BaseY2);

				for (i = SilentDiv; i < WaterEnd; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline2[i] = Baseline2[i] + Fit.p(j) * pow(i,j);
					}
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = 0; i < SilentDiv; i++) {
					Baseline[i] = Baseline1[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = SilentDiv; i < WaterDiv; i++) {
					f = (i-SilentDiv)/DivDist;
					Baseline[i] = f*Baseline2[i] + (1-f)*Baseline1[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = WaterDiv; i < WaterEnd; i++) {
					Baseline[i] = Baseline2[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
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

	Plot.setLimitsToFit();
	setBatchMode("exit and display");
	
	//differential image function used for de-spiking
	function diffImage(Image) {
		getDimensions(w, h, dummy, dummy, dummy);
		makeRectangle(0, 0, w-1, h);
		run("Duplicate...", "title=Spect1");
		selectImage(Image);
		makeRectangle(1, 0, w, h);
		run("Duplicate...", "title=Spect2");
		imageCalculator("Subtract create 32-bit", "Spect2","Spect1");
		Diff = getImageID();
		close("Spect1");
		close("Spect2");
		return (Diff);
	}

}