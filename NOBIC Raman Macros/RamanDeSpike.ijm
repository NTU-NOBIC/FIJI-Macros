//Removes cosmic ray spikes from Raman spectra (intended to be usedd for spectra acquired with NOBIC Raman microscope)
//Works on files in a folder and its subfolders and saves processed files in a sub-folder of the primary folder,
//the maximum spike width can be set, recommended 3 or 5.
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

macro "RamanDespike" {

	SpikeWidth = 3; //maximum spike width in pixels
	SpikeThreshold = -70; //Threshold in 2nd differential image to identify spikes
	SpikeThreshold2 = 40; //Threshold of neighbouring pixel in 2nd differential image to identify spikes
	
	Dir = getDirectory("Folder");
	setBatchMode(true);
	Despdir = Dir + "Despiked" + File.separator;
	File.makeDirectory(Despdir);
	DeSpike(Dir);

	function DeSpike (dir) {
		list = getFileList(dir);
	    for (m=0; m<list.length; m++) {
	    	if (endsWith(list[m], "/")) DeSpike(dir+list[m]);
	      	if (endsWith(list[m], ".tif")){
	      		Val = newArray(2*SpikeWidth-1);
	       		path = dir+list[m];
	       		open(path); 
	       		name = getTitle();      		
	       		Orig = getImageID();
	       		run("Select None");
				run("Duplicate...", " ");
				Dup = getImageID();
	       		
				Diff1 = diffImage(Dup);
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
						selectImage(Dup);
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
				selectImage(Orig);
				close();
			
				selectImage(Dup);
				saveAs("Tif", Despdir+name);
				close();
		       	
	       	}
	    }
	}	
	
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

}