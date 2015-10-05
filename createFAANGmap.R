#!/usr/bin/env Rscript

###############################################################################
##### This part loads useful packages
# if the packages are not already install, you can do it with:
# install.packages(c("RJSONIO","leaflet","htmlwidgets", "htmltools", "optparse"))
library(RJSONIO)
library(leaflet)
library(htmlwidgets)
library(htmltools)
library(optparse)
###############################################################################

###############################################################################
##### This part manages the variables passed to the script
library("optparse")

option_list = list(
  make_option(c("-f", "--file"), type="character", default=NULL, 
              help="name for new partners file", metavar="character"),
  make_option(c("-o", "--old"), type="character", default=NULL, 
              help="name for old file", metavar="character"),
  make_option(c("-r", "--res"), type="character", default="res.txt", 
              help="name for result (txt) file [default= %default]",
              metavar="character"),
  make_option(c("-m", "--map"), type="character", default="map.html", 
              help="name for map html file [default= %default]",
              metavar="character")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);
if (is.null(opt$file)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).\n", call.=FALSE)
}
partners_file <- opt$file
former_file <- opt$old
res_file <- opt$res
map_file <- opt$map
###############################################################################

###############################################################################
##### This part processes the data: search new entries, then search for
##### latitude and longitude

# load new list
partners = read.table(partners_file, sep="\t", header=TRUE, quote="",
                      stringsAsFactor=FALSE, fileEncoding="latin1")[ ,1]
partners = gsub("N/A", " ", partners)
saved_partners = NULL

# load former data if any
if (!is.null(former_file)) {
  saved_partners = read.table(former_file, sep="\t", stringsAsFactor=FALSE,
                              header=TRUE)
  new_notin_old = is.na(match(partners, saved_partners$desc))
  # old partners that have changed or have been removed are deleted
  to_delete = is.na(match(saved_partners$desc, partners))
  saved_partners = saved_partners[!to_delete, ]
  # now keep only new partners
  partners = partners[new_notin_old]
}

if (length(partners) > 0) {
  # use google to find latitude and longitude from loose description
  ##### Function that searches for latitude and longitude from address
  ##### it uses google
  getGeoCode <- function(gcStr)  {
    Sys.sleep(1) # used to suspend execution during one second 
                 # to prevent google from rejecting the query
    gcStr <- gsub(' ', '%20', as.character(gcStr)) # encode URL parameters
    # query google
    connectStr <- paste('http://maps.google.com/maps/api/geocode/json?sensor=false&address=',
                        gcStr, sep="") 
    con <- url(connectStr)
    data.json <- fromJSON(paste(readLines(con), collapse=""))
    close(con)
    
    if(data.json["status"]=="OK") {
      elements <- lapply(data.json$results[[1]]$address_components,
                         function(res) res$types)
      if (length(grep("country",elements))>0) {
        country <- data.json$results[[1]]$address_components[[grep("country",elements)[1]]]$long_name
      } else country <- NA
      if (length(grep("locality",elements))>0) {
        city <- data.json$results[[1]]$address_components[[grep("locality",elements)[1]]]$long_name
      } else city <- NA
      
      address <- c(data.json$results[[1]]$geometry$location, city, country)
      names(address) <- c("lat","lon","city","country")
    } else if (data.json["status"]=="OVER_QUERY_LIMIT") {
      address <- rep("quota", 4)
    } else {
      address <- rep(NA, 4)
    }
    return (address)
  }
  ##### End Function
  # use the function (repeat until google has answers to all queries
  # itwaits for one minute between each new attempt)
  in_quota = 1:length(partners)
  all_locations = matrix(ncol=4, nrow=length(partners))
  while (length(in_quota)>0) {
    partner_loc = sapply(partners[in_quota], getGeoCode)
    all_locations[in_quota,] = matrix(unlist(partner_loc), ncol=4, byrow=TRUE)
    in_quota = which(partner_loc[1,]=="quota")
    if (length(in_quota)>0) Sys.sleep(60)
  }
  # save this
  # save(partner_loc, file="rawMembers.rda")
  partner_loc = all_locations
  # look for rows that googles has not found
  missings = is.na(partner_loc[,1])
  
  if (sum(missings)>0) {
    # for missing rows, try to obtain city and country from the two last terms
    # and use google again
    partners2 = partners[missings]
    # use google to find latitude and longitude from loose description
    split_partners = strsplit(partners2, ",")
    partners2 = unlist(lapply(split_partners, function(alist) {
      paste(alist[1], alist[length(alist)])
    }))
    partner2_loc = sapply(partners2, getGeoCode)
    # save(partner2_loc, file="rawMembers2.rda")
    partner2_loc = matrix(unlist(partner2_loc), ncol=4, byrow=TRUE)
    partner_loc[missings, ] = partner2_loc
    missings = is.na(partner_loc[,1])
  }
  
  if (sum(missings)>0) {
    # this part searches for countries with OpenStreetMap if locations are still
    # missing - has not been tested!
    # if still missing, try to country and use OSM
    partners2 = partners[missings]
    split_partners = strsplit(partners2, ",")
    partners2 = unlist(lapply(split_partners, function(alist) alist[length(alist)]))
    ##### Function
    locateCountry = function(nameCountry) {
      nameCountry = gsub(" ", "%20", nameCountry)
      url = paste(
        "http://nominatim.openstreetmap.org/search?country="
        , nameCountry
        , "&limit=9&format=json"
        , sep="")
      resOSM = fromJSON(url)
      if(length(resOSM) > 0) {
        ## TODO: improve by adding city search
        return(c(resOSM[[1]]$lat, resOSM[[1]]$lon, NA, nameCountry))
      } else return(rep(NA,4)) 
    }
    ##### End Function
    partner3_loc = sapply(partners2, locateCountry)
    # save(partner3_loc, file="rawLoc3.rda")
    partner3_loc = matrix(unlist(partner3_loc), ncol=4, byrow=TRUE)
    partner_loc[missings, ] = partner3_loc
    missings = is.na(partner_loc[,1])
  }
  
  # cleaned up a bit the output
  partner_loc = partner_loc[!missings,]
  partner_loc = as.data.frame(partner_loc)
  names(partner_loc) = c("lat", "lon", "city", "country")
  partner_loc$lat = as.numeric(as.character(partner_loc$lat))
  partner_loc$lon = as.numeric(as.character(partner_loc$lon))
  partner_loc$city = as.character(partner_loc$city)
  partner_loc$country = as.character(partner_loc$country)
  partner_loc$desc = partners[!missings]
  
  if (sum(missings)>0) {
    # print missing partners
    cat("Missing partners are:\n")
    cat(partners[missings], sep="\n")
  }
  
  # concatenate with existing data (if any)
  if (!is.null(saved_partners)) {
    partner_loc = rbind(saved_partners, partner_loc)
  }
  write.table(partner_loc, file=res_file, sep="\t", row.names=FALSE)
} else { # if new and former files are the same
  partner_loc = saved_partners
  cat("No new data to add to previous map...\n")
}

###############################################################################

###############################################################################
##### This part creates the map

# choose your icon
leafIcons <- icons(
  iconUrl = "http://leafletjs.com/docs/images/leaf-red.png",
  iconWidth = 15, iconHeight = 40,
  iconAnchorY = 40
)

# create text for popup
popup_text <- paste(partner_loc$city, partner_loc$country, sep=", ")
popup_text[is.na(partner_loc$city)] <- partner_loc$country[is.na(partner_loc$city)]

# create the map (tiles can be chosen from https://leaflet-extras.github.io/leaflet-providers/preview)
m <- leaflet() %>% 
  addProviderTiles("MapQuestOpen.OSM",
                   options = providerTileOptions(attribution=htmlEscape("Tiles Courtesy of <a href=\"http://www.mapquest.com\">MapQuest</a> &mdash; Map data &copy; <a href=\"http://www.openstreetmap.org/copyright\">OpenStreetMap</a> | map kindly provided by <a href=\"http://tuxette.nathalievilla.org\">tuxette</a>"))) %>%
  addMarkers(lng=partner_loc$lon, lat=partner_loc$lat, icon=leafIcons, 
             popup=htmlEscape(popup_text))
# m  # print the map

saveWidget(m, file=map_file)
###############################################################################