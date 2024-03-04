//Stitches tile scans acquired with Micro-manager using Image Stitching plugin by Stephan Preibish
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

macro "MM-stitch...[g]" {

	Dialog.create("Tile Overlap");
	Dialog.addNumber("Tile overlap [%]", 10);
	Dialog.show();
	overlap = Dialog.getNumber();	//overlap in %
	dir = getDirectory("Stitch");
	Resdir = dir + "Stitched" + File.separator;
	File.makeDirectory(Resdir);
	setBatchMode("true");
	
	list = getFileList(dir);
	
	//loop through the directory to determine the raster size
	Xmax = 0; //largest x coordinate
	Ymax = 0; //largest y coordinate
	for (i=0; i<list.length; i++) {//read file name and retrieve coordinates
		if (endsWith(list[i], ".ome.tif")){	
			dashpos = indexOf(list[i], "-Pos");
			Basename = substring(list[i], 0, dashpos);
			Xs = substring(list[i], dashpos + 4, dashpos + 7);
			X = parseInt(Xs);
			if (X > Xmax) Xmax = X;
			Ys = substring(list[i], dashpos + 9, dashpos + 12);
			Y = parseInt(Ys);
			if (Y > Ymax) Ymax = Y;
			
			//print (Xs+","+Ys);
			//print(Basename);
			
		}
	}
	
	for (i=0; i<list.length; i++) {
		
	   	if (endsWith(list[i], ".ome.tif")){
	   		path = dir+list[i];
	   		open(path);
	   		Xs = substring(list[i], dashpos + 4, dashpos + 7);
			X = parseInt(Xs);
			Xn = (X-Xmax)*(-1);
			Ys = substring(list[i], dashpos + 9, dashpos + 12);
			Y = parseInt(Ys);
			Yn = (Y-Ymax)*(-1);
			Xns = IJ.pad(Xn, 3);
			Yns = IJ.pad(Yn, 3);
			//print(Xns+","+Yns);
			newname = Basename+"-Pos"+Xns+"_"+Yns+".tif";
		 	saveAs("Tiff", Resdir+newname);
			close();
	   		}
	 	}
	
	run("Close All");
	
	Xgrid = Xmax+1;
	Ygrid = Ymax+1;
	
	run("Grid/Collection stitching", "type=[Filename defined position] order=[Defined by filename         ] grid_size_x="+Xgrid+" grid_size_y="+Ygrid+" tile_overlap="+overlap+" first_file_index_x=0 first_file_index_y=0 directory=["+Resdir+"] file_names="+Basename+"-Pos{xxx}_{yyy}.tif output_textfile_name=TileConfiguration.txt fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 compute_overlap computation_parameters=[Save memory (but be slower)] image_output=[Fuse and display]");
	saveAs("Tiff", Resdir+Basename+"_stitched.tif");
	if (isOpen("Log")) {
	     selectWindow("Log");
	     run("Close" );
	}	
}