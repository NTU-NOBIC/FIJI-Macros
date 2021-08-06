//Recursively searches through a selected folder and sub-folders and exports Raman spectra as text files
//uses code of RamanSpectLive, Refer to RamanSpectLive for comments on spectrometer calibration
//resaves the spectrum image file (if libe 45 uncommented) and in this way can vastly reduce the file size by shedding excessive mmetadata or other ballast often present when saving an acquired image
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

slope = 0.1292;
offset = 577.35;
pixNum = 1024;
laser = 561;
shift = true;
label = "wavelenght/nm;
if (shift = = true) label = "Raman shift/cm^-1";

Dir = getDirectory("Folder");
ExportSpectRa(Dir);
run("Clear Results");
setBatchMode(true); 
print("\\Clear"); //clear Results

function ExportSpectRa(dir) {
	list = getFileList(dir);
    for (j=0; j<list.length; j++) {
    	print (list[j]);
		if (endsWith(list[j], "/")) ExportSpectRa(dir+list[j]);
       	if (endsWith(list[j], ".ome.tif")){
       		path = dir+list[j];
       		open(path);
       		name = getTitle();
       		run("Clear Results");
       		x=newArray(pixNum);
			y=newArray(pixNum);
		
				for (i = 0; i < pixNum; i++) {	
					x[i] = offset + i*slope;				
					if (shift = = true) x[i] = (1/laser - 1/x[i])*10000000;
					y[i] = getPixel(i,0);

					setResult(label, i, x[i]);
					setResult("value", i, y[i]);

				} 
				
		 		saveAs("Results", Dir+name+".txt");
		 		selectWindow(name);
		 		//saveAs("Tif", Dir+name);
		 		//print (dir+name);
				close();
       		}
     	}
	}
	
