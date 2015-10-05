FAANG geolocation
===

The two files provided in this directory automatically builds an interactive
map from a text file with the addresses of FAANG members:

* ```createFAANGmap.R``` is an executable **R** script (usable on Unix-like OS);

* ```createFAANGmap-sourcing.R``` has to be run from inside **R**.

See Section Usage for details.

# Basic description

The scripts proceed as follow:

1. They import the addresses and (optionally) the file which contains previously
processed data (as saved by a previous run of the script);

2. For the new institutes, they query Google (first by entire address, then by 
city and country and finally by country - this last step is performed with 
OpenStreetMap) to obtain city | country | latitude | longitude. This step can 
take a while if a large number of new members have to be searched: to avoid 
reject of the query by Google, the script includes a delay between each query 
and is run until all queries have been answered by Google. It is therefore 
essential that the current data are saved to avoid unnecessary queries. 
*Note*: The first file has been processed in about 10 minutes.

3. The old data are updated with new members (former members that do not exist
in the current file are removed) and exported as a text file;

4. The map is created with leaflet and saved as an HTML file.


# Arguments

The scripts have several arguments (which have to be directly modified in the
file for ```createFAANGmap-sourcing.R``` and are passed as arguments when 
running the script for ```createFAANGmap.R``` as described in section "Usage"):

* ```file``` or ```partner_file``` are the arguments for the name of the file 
with all the current partners;

* ```old``` or ```former_file``` (optional) are the arguments for the name of 
the file which contains previously processed data;

* ```res``` or ```res_file``` are the arguments for the name of the file where
to export (text format) the processed data with current partners;

* ```map``` or ```map_file``` are the arguments for the name of the file where
to save (html format) the interactive map.

# Usage

The file requires at least a proper [**R**](https://www.cran.r-project.org)
installation, as well as [pandoc](http://pandoc.org) and the following **R** 
packages: RJSONIO, leaflet, htmlwidgets, htmltools, optparse (optparse is not
needed for ```createFAANGmap-sourcing.R```).

On Linux Ubuntu **R** can be installed as described in the first two boxes of
[this page](http://tuxette.nathalievilla.org/?p=1380) and pandoc is simply 
installed with

```
sudo apt-get install pandoc
```

For every OS, the packages are installed by running the following command lines
within **R**:

```
install.packages(c("RJSONIO","leaflet","htmlwidgets", "htmltools", "optparse"))
```

### createFAANGmap.R

This script is a command line script which can be executed on Unix-like OS. It
is used with

```
./createFAANGmap.R -f "members_20151002.csv" -o "recordMembers.txt" -r "output.txt" -m "map.html"
```

Only the first argument is mandatory. If you have an error, you can alternatively try

```
Rscript createFAANGmap.R -f "members_20151002.csv" -o "recordMembers.txt" -r "output.txt" -m "map.html"
```

### createFAANGmap-sourcing.R

From inside **R** set the working directory (function ```setwd()```) to the 
folder in which the script is saved and, after having updated the initialization
part of the script, run:
```
source("createFAANGmap-sourcing.R")
```

This solution is prefered if you are using Windows (even though I do not know 
how certain parts of the script work on Windows, especially the parts related
to pandoc).

# Notes to improve the scripts

A few improvements could be obtained if:

* the original file contained the institution name (the popup could then 
contain the institution name);

* data were directly obtained from the database (**R** can query very easily
MySQL databases for instance). In particular, this would prevent some 
inconsistencies in the data (some rows did have four commas instead of three
because raw addresses themselves contained comma and where not delimited by
quotes).

I would adviced using a CRON task to automatically update the map. Its 
integration on the website can be made using ```<iframe>```.

---- 

*A question? Do not hesitate to contact [tuxette](mailto:tuxette[AT]nathalievilla.org).*