#######################################################################################
# Author: Matt Watts, m.watts@uq.edu.au                                               #
# Date: November 2013                                                                 #
# Run Marxan, perform cluster analysis, display output graphs, maps and tables.       #
# This file, MarxanTutorial.R, contains the commands you need to run Marxan with      #
# R Studio Server on marxan.net                                                       #
# It includes commands for the "MPA_Activity" and "Tas_Activity" datasets.            #
#######################################################################################

# 

# With the web browser, go to marxan.net, and click "Login to R studio Server console".
# Log into R Studio Server with the password and username you have been given

# The necessary files (MPA_Activity, Tas_Activity, and Marxan.R) must already be in your "home" directory.

# Type these commands to use Marxan with R Studio Server on marxan.net
# (or copy/paste them, or highlight them and push the "->Run" button)

# Getting started with Marxan.
# NOTE: ## replace "ubuntu" with your user name. ##
# We can do all these things with the Tas_Activity dataset too.
# In that case, we just replace "MPA_Activity" with "Tas_Activity".
sHome <- "/mnt/users/ubuntu/"
#sWorkingDir <- paste0(sHome,"MPA_Activity/")
sWorkingDir <- paste0(sHome,"Tas_Activity/")
source(paste0(sHome,"Marxan.R"))
setwd(sWorkingDir)
system(paste0("chmod +x ",paste(sWorkingDir,"MarOpt_v243_Linux64")))

# Running Marxan.
system(paste(sWorkingDir,"MarOpt_v243_Linux64 -s",sep=""))

# Import the outputs to the shape file so we can display maps. Note: replace "ubuntu" with your user name
ImportOutputsCsvToShpDbf(paste(sWorkingDir,"pulayer/pulayer.dbf",sep=""),
                         sWorkingDir, 10,"PUID")
# Note: if your PUID field is not called "PUID", change the parameter here.


# Displaying maps.
pulayer <- readShapePoly(paste(sWorkingDir,"pulayer/pulayer.shp",sep=""))
pupolygons <- SpatialPolygons2PolySet(pulayer)
putable <- read.dbf(paste(sWorkingDir,"/pulayer/pulayer.dbf",sep=""))
DisplaySsolnMap(pulayer,1,TRUE) # available zone
DisplaySsolnMap(pulayer,2,TRUE) # reserved zone
DisplayMap(pulayer,0,TRUE) # best solution
DisplayMap(pulayer,1,TRUE) # solution 1
DisplayMap(pulayer,2,TRUE) # solution 2
DisplayMap(pulayer,3,TRUE) # solution 3
DisplayMap(pulayer,4,TRUE) # solution 4
DisplayMap(pulayer,5,TRUE) # solution 5
DisplayMap(pulayer,6,TRUE) # solution 6
DisplayMap(pulayer,7,TRUE) # solution 7
DisplayMap(pulayer,8,TRUE) # solution 8
DisplayMap(pulayer,9,TRUE) # solution 9
DisplayMap(pulayer,10,TRUE) # solution 10
# Alternate versions of the functions use plotPolys from PBSmapping package.
# They render abour 100 times as fast.
# Colours will be ramped between white and the colour specified
DisplaySsolnMapPBSm(pupolygons,putable,1,100,"blue",TRUE) # available zone
DisplaySsolnMapPBSm(pupolygons,putable,2,100,"orange",TRUE) # reserved zone
DisplaySsolnMapPBSm(pupolygons,putable,1,100,"yellow",FALSE) # available zone
DisplaySsolnMapPBSm(pupolygons,putable,2,100,"black",FALSE) # reserved zone
# If displaying multiple zone maps, we simply pass in a set of colours,
# one colour for each zone we're displaying.
# ie. If you have 4 zones, pass in 4 colours.
# eg. Here we have 2 zones: Available and Reserved.
# Available will be white and Reserved will be green.
DisplayMapPBSm(pupolygons,putable,0,c("white","green"),TRUE) # best solution in green
DisplayMapPBSm(pupolygons,putable,1,c("white","red"),TRUE) # solution 1 in red
# You can pass in hexadecimal code for colours if you like.
# An interactive website that shows you hex colour codes:
# http://www.colorpicker.com/
DisplayMapPBSm(pupolygons,putable,2,c("white","#0000FF"),TRUE) # solution 2 in blue
DisplayMapPBSm(pupolygons,putable,3,c("white","#8C00FF"),FALSE) # solution 3 in purple

# Display the output tables. Note: we show you two ways to view these tables.
View(read.csv(paste(sWorkingDir,"output/output_sum.csv",sep="")))
View(read.csv(paste(sWorkingDir,"output/output_mvbest.csv",sep="")))
View(read.csv(paste(sWorkingDir,"output/output_mv00001.csv",sep="")))
View(read.csv(paste(sWorkingDir,"output/output_mv00010.csv",sep="")))
DisplaySumTable(sWorkingDir)
DisplayMVTable(sWorkingDir,0)
DisplayMVTable(sWorkingDir,1)
DisplayMVTable(sWorkingDir,10)

# cluster analysis.
solutions <- ClusterUniqueSolutions(paste(sWorkingDir,"output/output_solutionsmatrix.csv",sep=""))
ClusterPlotNMDS(solutions)
ClusterPlotDendogram(solutions)

##################################################################################
# To edit the input.dat (for changing BLM and/or NUMREPS):                       #
# - click the "Files" tab on the window in the bottom right hand side,           #
# - browse to "MPA_Activity" or "Tas_Activity",                                  #
# - click "input.dat" to open and edit it in a window in the top left hand side, #
# - edit the parameter you want to change,                                       #
# - save and close the edit window for "input.dat".                              #
# When you've changed the parameter, you'll need to run Marxan again.            #
##################################################################################

