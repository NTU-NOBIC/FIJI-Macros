//Recursively lists files in selected directory and sub-directories, opens CZI images and saves them as TIFF
//Resaved files do not contain metadata saved by ZEN software,
//by Radek Machan, NOBIC, NTU, https://www.nobic.sg/index.html

dir = getDirectory("Resave");
resaveFiles(dir);
setBatchMode("true");

function resaveFiles(dir) {
	list = getFileList(dir);
    for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) resaveFiles(dir+list[i]);
       	if (endsWith(list[i], ".czi")){
       		path = dir+list[i];
       		run("Bio-Formats Macro Extensions");
       		Ext.setId(path);
			Ext.getSeriesCount(seriesCount);
			for (j=0; j<seriesCount; j++){
		   		run("Bio-Formats Importer", "open=path view=Hyperstack stack_order=XYCZT series_"+d2s(j,0));
		   		if (seriesCount>1) nlist = d2s(j+1,0)+"_"+list[i];
		   		else nlist = list[i];
		 		saveAs("Tiff", dir+nlist);
				close();
       		}
     	}
	}
}
run("Close All");
if (isOpen("Log")) {
     selectWindow("Log");
     run("Close" );
}	
