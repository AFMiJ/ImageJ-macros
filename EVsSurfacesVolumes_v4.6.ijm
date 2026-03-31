/* Copyright 2024 Lorenzo Lunelli

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License. */

ver="4.6";
requires ("1.52u"); // Math functions, additional Roi manager functions
// ================== default values ============================
base=0;  // default level of fixed background (for volume computation)
localback=false;  // switch for using a locally computed background
basemark=false;   // switch to mark the pixels used for local base computation - not in the GUI, to be changed here
negheights=false; // switch for allowing heights below the reference surface // do not change this parameter
cleartable=false;  // switch for clearing tables at beginning
restoreROI=false;  // switch for clearing tables at beginning
addOverlay=true;  // switch for adding ROIs to the Overlay if detection method is "Threshold"
Howtoidentify=newArray("Threshold","Use Overlay","Use ROIs");
identify="Threshold";    // default identification of particles
partmin=8.1;
mindiam=35.7;
maxdiam=10000;
mincirc=0.3;
minpix=true; // consider only particles at least 4 pixels area
exclude=true; // switch for excluding particles on edges
idbil=true;  // try to identify bilayers
bilmin=3;
bilmax=7;
bilstd=1.3;
bilave=5;
bilavetol=1;
bilmindiam=90;
bilcorrection=true;
Npoints=5; // number of highest point for statistics evaluation
Tableitems=newArray("do not clear","clear","clear&save","clear&save&save image");
tableaction="clear&save&save image";
backlevelitems=newArray("use the fixed background level","compute local background for every particle");
if (localback) {
	backlevelitem=backlevelitems[1];
} else {
	backlevelitem=backlevelitems[0];
}

sh=screenHeight;
sw=screenWidth;

windowList=getList("image.titles");
if (windowList.length==0) {
	exit("No image open!");
}

Dialog.create("EVs characterization v."+ver);
Dialog.setInsets(0,0,0);
Dialog.addMessage("------- Z units must be nm ------\n", 14, "blue");
Dialog.setInsets(0,0,0);
Dialog.addMessage("Parameters for particle identification", 14, "blue");
Dialog.addNumber("height threshold", partmin, 1, 6, "nm");
Dialog.addNumber("min. projected diameter", mindiam, 1, 6, "nm");
Dialog.addNumber("max. projected diameter", maxdiam, 1, 6, "nm");
Dialog.addNumber("min. circularity", mincirc, 2, 6, "");
Dialog.addCheckbox("only use particles with area>=4 pixels", minpix);
Dialog.addCheckbox("exclude particles on edges", exclude);
Dialog.addRadioButtonGroup("Particle identification", Howtoidentify, 1, 3, identify);

Dialog.addMessage("---------------------------", 14, "blue");
Dialog.addCheckbox("identify bilayers", idbil);
Dialog.addNumber("low. bilayer height thr.", bilmin, 1, 6, "nm");
Dialog.addNumber("upp. bilayer height thr.", bilmax, 1, 6, "nm");
Dialog.addNumber("average. bilayer height", bilave, 1, 6, "nm");
Dialog.addNumber("ave. bilayer height tolerance", bilavetol, 1, 6, "nm");
Dialog.addNumber("max. bilayer height std", bilstd, 1, 6, "nm");
Dialog.addNumber("min. bilayer proj. diameter", bilmindiam, 1, 6, "nm");
Dialog.addCheckbox("bilayer surface correction", bilcorrection);

Dialog.setInsets(20,0,0);
Dialog.addMessage("Parameters for Top height computation", 14, "blue");
Dialog.setInsets(10,0,0);
Dialog.addNumber("number of top height points", Npoints, 0, 4, "");

Dialog.setInsets(20,0,0);
Dialog.addMessage("Parameters for height and volume computation", 14, "blue");
Dialog.setInsets(10,0,0);
Dialog.addNumber("fixed background level", base, 1, 6, "nm");
Dialog.addToSameRow(); //Dialog.addCheckbox("allow negative heights (holes)", negheights); // check line 108 if uncomment this
Dialog.addRadioButtonGroup("background level", backlevelitems, 2, 1, backlevelitem);

Dialog.setInsets(20,0,0);
Dialog.addMessage("Misc options", 14, "blue");
Dialog.addRadioButtonGroup("Tables", Tableitems, 2, 2, tableaction);
Dialog.addCheckbox("restore ROI manager", restoreROI);
Dialog.addCheckbox("if Threshold add ROIs to overlay", addOverlay);

Dialog.show();

// ===================== get user inputs ===============================
partmin=Dialog.getNumber();
mindiam=Dialog.getNumber();
maxdiam=Dialog.getNumber();
mincirc=Dialog.getNumber();
minpix=Dialog.getCheckbox();
exclude=Dialog.getCheckbox();
identify=Dialog.getRadioButton();

idbil=Dialog.getCheckbox();
bilmin=Dialog.getNumber();
bilmax=Dialog.getNumber();
bilave=Dialog.getNumber();
bilavetol=Dialog.getNumber();
bilstd=Dialog.getNumber();
bilmindiam=Dialog.getNumber();
bilcorrection=Dialog.getCheckbox();

Npoints=Math.floor(Dialog.getNumber());

base=Dialog.getNumber();
//negheights=Dialog.getCheckbox(); // check line 81 if uncomment this
typeback=Dialog.getRadioButton();
if (typeback==backlevelitems[1]) {
	localback=true;
} else  {
	localback=false;
}

tableaction=Dialog.getRadioButton();
if (tableaction=="clear") {
	cleartable=true;
	savetables=false;
	saveimage=false;
} else if (tableaction=="clear&save") {
	cleartable=true;
	savetables=true;
	saveimage=false;
} else if (tableaction=="clear&save&save image") {
	cleartable=true;
	savetables=true;
	saveimage=true;
} else {
	cleartable=false;
	savetables=false;
	saveimage=false;
}
restoreROI=Dialog.getCheckbox();
addOverlay=Dialog.getCheckbox();
// ======================================================================

minarea=PI*Math.sqr(mindiam/2);
maxarea=PI*Math.sqr(maxdiam/2);
getPixelSize(unit, pixelWidth, pixelHeight);
if (unit=="nm") {
	areaconversion=pixelWidth*pixelHeight;
	xlengthconversion=pixelWidth;
	ylengthconversion=pixelHeight;
} else if (unit==getInfo("micrometer.abbreviation")) {
	areaconversion=pixelWidth*pixelHeight*1.0e6;
	xlengthconversion=pixelWidth*1.0e3;
	ylengthconversion=pixelHeight*1.0e3;
} else {
	exit("unknown units!");
}

fourpixelsarea=4*areaconversion;
if (fourpixelsarea>minarea && minpix) {
	minarea=fourpixelsarea;
}

myTable="EVs_analysis";
if (cleartable || !isOpen(myTable)) {
	Table.create(myTable);
}
Table.setLocationAndSize(sw*0.2, sh*0.1+430, 800, 300);

ROIfilepath=getDir("temp")+File.separator +"EVsTempROI.zip";
numberbeforeROIs=roiManager("size");
if (numberbeforeROIs>0 && restoreROI && identify!="Use ROIs") {
	roiManager("save", ROIfilepath);
}

id=getImageID();
imagename=getInfo("image.title");
imagedir=getInfo("image.directory");

// ===========================================================================================
lowT="-";
uppT="-";
run("Select None");

if (identify=="Use ROIs") { // if we want to use ROIs in ROI manager
	if (RoiManager.size>0){
		ROIscanning(0,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,false);
	} else {
		exit("ERROR! - NO ROIs!");
	}
}

if (identify=="Use Overlay") { // if we want to use overlay embedded in image
	if (Overlay.size>0){
		roiManager("reset");
		run("To ROI Manager"); // put overlay to the ROI manager
		ROIscanning(0,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,false);
		run("From ROI Manager"); // restore the overlay
	} else {
		exit("ERROR! - Overlay required!");
	}
}

if (identify=="Threshold") {  // if we want to compute new ROIs
	setThreshold(partmin, 1.0e30);
	roiManager("reset");
	getThreshold(lowT,uppT);
	if (lowT==-1 && uppT==-1) {exit("Image with threshold required");};
	if (!idbil) { // no bilayers separate identification
		if (exclude) {
			run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 exclude add");
		} else {
			run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 add");	
		}
		ROIscanning(0,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,addOverlay);
	} else { // identify bilayers and put them at the end of the table
		// first particles
		templowT=Math.max(lowT,bilmax+0.5); // increase bilayer theshold by 0.5 nm
		setThreshold(templowT, uppT);
		if (exclude) {
			run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 exclude add");
		} else {
			run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 add");	
		}
		ROIscanning(0,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,addOverlay);
		ROInextsparticle=RoiManager.size;
		// then bilayers
		bilminarea=Math.max(PI*Math.sqr(bilmindiam/2),fourpixelsarea);
		run("Select None");
		setThreshold(bilmin, bilmax);
		if (exclude) {
			run("Analyze Particles...", "size=&bilminarea-&maxarea circularity=&mincirc-1.00 exclude add");
		} else {
			run("Analyze Particles...", "size=&bilminarea-&maxarea circularity=&mincirc-1.00 add");	
		}
		ROIscanning(ROInextsparticle,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,addOverlay);
	}
	resetThreshold;
}

// ================= parameters Table ======================
paramTable="Parameters for EVs analysis";
Table.create(paramTable);
Table.setLocationAndSize(sw*0.2, sh*0.1, 600, 430);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "macro version",paramTable);
Table.set("value", rowIndex, ver,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "Image name",paramTable);
Table.set("value", rowIndex, imagename,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "lower Threshold",paramTable);
Table.set("value", rowIndex, lowT,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "upper Threshold",paramTable);
Table.set("value", rowIndex, uppT,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. diam.",paramTable);
Table.set("value", rowIndex, mindiam,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "max. diam",paramTable);
Table.set("value", rowIndex, maxdiam,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. circ.",paramTable);
Table.set("value", rowIndex, mincirc,paramTable);
rowIndex=Table.size(paramTable);
if (minpix) {
	Table.set("parameter", rowIndex, ">=4 pixels area: YES",paramTable);
	Table.set("value", rowIndex, fourpixelsarea,paramTable);
} else {
	Table.set("parameter", rowIndex, ">4 pixels area: NO",paramTable);
	Table.set("value", rowIndex, "-",paramTable);
}
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "exclude particles on edges:",paramTable);
if (exclude) {
	Table.set("value", rowIndex, "YES",paramTable);
} else {
	Table.set("value", rowIndex, "NO",paramTable);	
};

rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "low. bilayer height threshold",paramTable);
if (idbil) {Table.set("value", rowIndex, bilmin,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "upp. bilayer height threshold",paramTable);
if (idbil) {Table.set("value", rowIndex, bilmax,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "average bilayer height",paramTable);
if (idbil) {Table.set("value", rowIndex, bilave,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "average bilayer height tolerance",paramTable);
if (idbil) {Table.set("value", rowIndex, bilavetol,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "bilayer height std",paramTable);
if (idbil) {Table.set("value", rowIndex, bilstd,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. bilayer diameter",paramTable);
if (idbil) {Table.set("value", rowIndex, bilmindiam,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};


rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "bilayer area correction",paramTable);
if (idbil && bilcorrection) {
	Table.set("value", rowIndex, "YES",paramTable);
} else if (idbil && !bilcorrection) {
	Table.set("value", rowIndex, "NO",paramTable);
} else {
	Table.set("value", rowIndex, "-",paramTable);
};

rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "number of top points",paramTable);
Table.set("value", rowIndex, Npoints,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "base level",paramTable);
if (localback) {
	Table.set("value", rowIndex, "local",paramTable);
} else  {
	Table.set("value", rowIndex,"fixed="+base,paramTable);
}
/*rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "allow negative heights (holes)",paramTable);
if (negheights) {
	Table.set("value", rowIndex, "YES",paramTable);
} else  {
	Table.set("value", rowIndex,"NO",paramTable);
}*/
Table.update;
// =================================================
// get date and time of analysis
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
if (savetables) {
	datetime4table=toString(year)+"-"+toString(month+1)+"-"+toString(dayOfMonth)+"_"+toString(hour)+"."+toString(minute)+"."+toString(second);
	date="_"+datetime4table;
	if (imagedir=="") {
		imagedir=getDir("Choose a Directory");
	}
	Table.save(imagedir+imagename+date+"_"+myTable+".csv",myTable);
	Table.save(imagedir+imagename+date+"_"+myTable+"_parameters.csv",paramTable);
	showMessage("Tables saved.");
}

if (saveimage) {
	roiManager("show all with labels");
	datetime4table=toString(year)+"-"+toString(month+1)+"-"+toString(dayOfMonth)+"_"+toString(hour)+"."+toString(minute)+"."+toString(second);
	date="_"+datetime4table;
	if (imagedir=="") {
		imagedir=getDir("Choose a Directory");
	}
	saveAs("tiff", imagedir+imagename+date+"_particles.tif");
	rename(imagename);
	showMessage("Image saved.");
}

if (numberbeforeROIs>0 && restoreROI && identify!="Use ROIs") {
	roiManager("reset");
	roiManager("open", ROIfilepath);
}

// =====================================================================================
// ================================== functions below ==================================

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++ ROI scanning +++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
function ROIscanning(startROI,myTable,localback,base,basemark,areaconversion,xlengthconversion,ylengthconversion,negheights,Npoints,idbil,bilmin,bilmax,bilstd,bilcorrection,addOverlay) {
	numROIs=RoiManager.size;
	for (index=startROI;index<numROIs;index++) {
		rowIndex=Table.size(myTable);
		RoiManager.select(index);
		Roi.getContainedPoints(xpoints, ypoints);
		numb_allpoints=xpoints.length;
		getSelectionBounds(xs, ys, widths, heights);
		if (localback) { // if selected, compute a local base
			base=LocalBase(xs, ys, widths, heights,base,basemark,index); // index is only used if we want to mark the pixels used for base computation 
		}
		base_area=baseArea(numb_allpoints,areaconversion);
		triang_area=triangArea(xs, ys, widths, heights,xlengthconversion,ylengthconversion,base,negheights);
		surf_total=base_area+triang_area;
		volume=Volume(xs, ys, widths, heights,areaconversion,base,negheights);
		N_topstats=topNpoints(xs, ys, widths, heights,xpoints, ypoints,Npoints,base,negheights);
		allstats=topNpoints(xs, ys, widths, heights,xpoints, ypoints,numb_allpoints,base,negheights);
		mean=allstats[0]; std=allstats[1];
		if (idbil && mean>=bilmin && mean<=bilmax && std<=bilstd && bilcorrection) { // if is a bilayer and area correction is true
			surf_total=base_area; // use only the base surface area
		}
		surfRadius=Math.sqrt(surf_total/(4*PI));
		volRadius=Math.pow(volume*3/(4*PI),1/3);
		Table.set("index", rowIndex, index+1,myTable);
		Table.set("label", rowIndex, imagename,myTable);
		Table.set("radius from surface", rowIndex, surfRadius,myTable);
		Table.set("radius from volume", rowIndex, volRadius,myTable);	
		Table.set("Base Surface", rowIndex, base_area,myTable);
		Table.set("Total Surface", rowIndex, surf_total,myTable);
		Table.set("Volume", rowIndex, volume,myTable);
		Table.set("mean height", rowIndex, mean,myTable);
		Table.set("std dev.", rowIndex, std,myTable);
		Table.set("Top N points mean height", rowIndex, N_topstats[0],myTable);
		Table.set("Top N points std. dev.", rowIndex, N_topstats[1],myTable);
		Table.set("base level", rowIndex, base,myTable);
		//if (idbil && mean>=bilmin && mean<=bilmax && std<=bilstd) {
		if (idbil && Math.abs(mean-bilave)<=bilavetol && std<=bilstd) {
			Table.set("type", rowIndex, "bilayer",myTable);
			 roiManager("rename", IJ.pad(index+1, 4)+"_B");
			 if (addOverlay) {Overlay.addSelection("blue");}; // blue bilayers
		} else {
			Table.set("type", rowIndex, "particle",myTable);
			roiManager("rename", IJ.pad(index+1, 4)+"_P");
			if (addOverlay) {Overlay.addSelection("red");};	// red particles
		};
	}
	Table.update(myTable);
}
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


function topNpoints(xs, ys, widths, heights,xpoints, ypoints,N,base,negh) {
	ll=xpoints.length;
	heights=newArray();
	for (index=0;index<ll;index++) {
		heights[index]=MygetPixel(xpoints[index], ypoints[index],base,negh);
	}
	Array.sort(heights);
	Array.reverse(heights);
	Ntoppoints=Array.trim(heights, N);
	//Array.show(Ntoppoints);
	Array.getStatistics(Ntoppoints, min, max, mean, StDev);
	retValue=newArray(2);
	retValue[0]=mean; retValue[1]=StDev;
	return retValue;
}


function baseArea(ll,areaconversion) {
	result=ll*areaconversion;
	//print("base Area elements",ll);
	return result;
}


function triangArea(xs, ys, widths, heights,pw,ph,base,negh) {
	result=0;
	numelements=0;
	for (xi=xs;xi<xs+widths;xi++) {
		for (yi=ys;yi<ys+heights;yi++) {
			Z1=MygetPixel(xi, yi,base,negh); // P1
			Z2=MygetPixel(xi+1, yi,base,negh); // P2
			Z3=MygetPixel(xi, yi+1,base,negh); //P3
			Z4=MygetPixel(xi+1, yi+1,base,negh); // P4
			if (Roi.contains(xi, yi) || Roi.contains(xi+1, yi) || Roi.contains(xi, yi+1) || Roi.contains(xi+1, yi+1)) { 
				u1Len=Math.sqrt(Math.sqr(-ph*(Z2-Z1))+Math.sqr(pw*(Z3-Z1))+Math.sqr(pw*ph));
				u2Len=Math.sqrt(Math.sqr(ph*(Z3-Z4))+Math.sqr(-pw*(Z2-Z4))+Math.sqr(pw*ph));
				result=result+0.5*(u1Len+u2Len);
				numelements++;
			}	
		}
	}
//	print("Area elements",numelements);
	return result;
}


function Volume(xs, ys, widths, heights,areaconversion,base,negh) { // everything is assumed to be in nm here
	Roi.getContainedPoints(xpoints, ypoints);
	ll=xpoints.length;
	result=0;
	for (i=0;i<ll;i++) {
		result=result+areaconversion*MygetPixel(xpoints[i], ypoints[i],base,negh);
	}
	return result;
}


function LocalBase(xs, ys, widths, heights,base,basemark,index) {
	localbase=0;
	numelements=0;
	baseExtTol=4; baseIntTol=2; // number of pixels used to widening the base evaluation area 
	for (xi=xs-baseExtTol;xi<xs+widths+baseExtTol;xi++) {
		for (yi=ys-baseExtTol+1;yi<ys+heights+baseExtTol;yi++) {
				if (!Roi.contains(xi, yi) && !((yi>ys-baseIntTol && yi<ys+heights+baseIntTol && xi>=xs-baseIntTol && xi<xs+widths+baseIntTol ))) {
					value=getPixel(xi, yi);
					if (!isNaN(value)) {
						localbase=localbase+value;
						numelements++;
					}
					if (basemark) {makePoint(xi, yi, "small magenta dot add");RoiManager.select(index);};
				}
		}
	}
	if (numelements>0) {base=localbase/numelements;};
 	return base
}


function MygetPixel(x,y,base,negheights) {
	if (negheights) {
		Z=getPixel(x, y)-base;
	} else {
		Z=Math.max(getPixel(x, y)-base, 0);
	}
	return Z
}
