//Recursively lists files in selected directory and sub-directories, opens TIF images and applies pixel scaling
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

macro "PixelScale [q]" {
	Dialog.create("Acquisition parameters");
		Dialog.addNumber("Objective magnification",63);
		Dialog.addNumber("Tube lens magnification",1.6);
		Dialog.addNumber("C-mount adapter magnification",0.63);
		Dialog.addNumber("Camera pixel/um",3.45);
		Dialog.addNumber("Binning",1);
		Dialog.show();
		Mag = Dialog.getNumber;
		Tube = Dialog.getNumber;
		Mount = Dialog.getNumber;
		CPix = Dialog.getNumber;
		Bin = Dialog.getNumber;
	
		Pix = (CPix/(Mag*Tube*Mount))*Bin;
		
	dir = getDirectory("Resave");
	setBatchMode("true");
	sepind = lastIndexOf(dir, File.separator);
	Dir = substring(dir, 0, sepind);
	Resdir = Dir + "-Scaled" + File.separator;
	File.makeDirectory(Resdir);
	
	scaleFiles(dir);
	
	function scaleFiles(dir) {
		list = getFileList(dir);
	    for (i=0; i<list.length; i++) {
			if (endsWith(list[i], "/")) scaleFiles(dir+list[i]);
	       	if (endsWith(list[i], ".tif") || endsWith(list[i], ".tiff")){
	       		path = dir+list[i];
	       		open(dir+list[i]);
	       		setVoxelSize(Pix, Pix, 1, "um");
				saveAs("Tiff", Resdir+list[i]);
				close();
	     	}
		}
	}
	run("Close All");
	if (isOpen("Log")) {
	     selectWindow("Log");
	     run("Close" );
	}
}
		
