# Fills in missing possiblelocs apGroupIds based on Jaccard similarity

fetchDataFromSql <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward', sql) {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # and select all rows and necessary columns for running a similarityMatrix or other operations.
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #   sql = the sql string to execute
  #
  # Returns:
  #   Selected data
  
  library(RMySQL)
  con <- dbConnect(MySQL(), user = userIn, password = passwordIn,  host = hostIn, dbname = dbnameIn)
  data <- dbGetQuery(con, sql)
  dbDisconnect(con)
  data
}

fetchPossibleLocsMissingApGroupIdsFromSql <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward') {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # select all rows and necessary columns missing data
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  sql <- "SELECT `doctor`, `rdate`, `rtime`, `time`, `wards`, `apids`  FROM possiblelocs WHERE time IS NOT NULL AND `apGroupId` IS NULL ORDER BY `doctor`, `time`;"
  data <- fetchDataFromSql(userIn, passwordIn, hostIn, dbnameIn, sql)
  data
}

fetchPossibleLocsCompletedApGroupIdsFromSql <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward') {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # select all rows and necessary columns without missing data
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  sql <- "SELECT `doctor`, `rdate`, `rtime`, `time`, `apGroupId`, `apids` FROM possiblelocs WHERE time IS NOT NULL AND `apGroupId` IS NOT NULL ORDER BY `doctor`, `time`;"
  data <- fetchDataFromSql(userIn, passwordIn, hostIn, dbnameIn, sql)
  data
}

fetchPossibleLocsMatchingGivenOneFromSql <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward', apidsIn) {
  # Given connetion info and an apids string, connect to a Wayward database with a populated possiblelocs table
  # select all rows exactly matching the apidsIn.
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  sql <- paste("SELECT `doctor`, `time` FROM possiblelocs WHERE `apids`='",apidsIn,"';",sep="")
  print(sql)
  data <- fetchDataFromSql(userIn, passwordIn, hostIn, dbnameIn, sql)
  data
}


updatePossibleLocs <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward', groupIdIn, apGroupIdSimilarityIn, doctor1, aTime) {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # select all rows and necessary columns without missing data
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  sql <- paste ("UPDATE possiblelocs SET apGroupId='",groupIdIn,"', apGroupIdSimilarity=",format(apGroupIdSimilarityIn,digits=2)," WHERE `doctor`='",doctor1,"' AND `time`='",aTime,"';",sep="")
  write(sql, file = "./updates.txt", append = TRUE)
  print(sql)
  data <- fetchDataFromSql(userIn, passwordIn, hostIn, dbnameIn, sql)
  data
}

updateApGroupIdsDatasetFromSimilarAps <- function(userIn = 'root', hostIn = 'localhost', dbnameIn ='wayward') {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # Fill in missing ApGroupIds based on similar completed ones
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  library("sets")
  # Select datasets for missing data and complete data
  missingApGroupIdsDataset <- fetchPossibleLocsMissingApGroupIdsFromSql(passwordIn="Anz5Ur8TUPVuh")
  completeApGroupIdsDataset <- fetchPossibleLocsCompletedApGroupIdsFromSql(passwordIn="Anz5Ur8TUPVuh")
  bestSim <- 0
  bestRow <- -1
  bestSimRow <- -1
  
  setwd('D:\\Dropbox\\projects and teaching\\horizon\\wayward\\phoneData\\waywardWifiAnalysis')
  
  # For each missing data row, and add update the corresponding SQL table with the most similar apGroup above a given threshold
  for(missingRow in 1:nrow(missingApGroupIdsDataset)){
    print(paste(Sys.time(),"> missingRow: ", missingRow))
    for(row in 1:nrow(completeApGroupIdsDataset)){   
      #print(row)
      apidsForMissingGroup <- missingApGroupIdsDataset$apids[missingRow]
      apidsForCompleteGroup <- completeApGroupIdsDataset$apids[row]
      sim <- set_similarity(as.set(unlist(strsplit(apidsForMissingGroup, ','))), as.set(unlist(strsplit(apidsForCompleteGroup, ','))))
      if(sim > bestSim){
        bestSim <- sim
        bestRow <- row
        bestSimRow <- completeApGroupIdsDataset[row,]   
      }
    }
    
    if(bestSim > 0){
      outputMsg <- paste(Sys.time(), "bestSim: ", bestSim, "bestRow: ", bestRow, "bestSimRowDoc:", bestSimRow$doctor, "bestSimRowTime", bestSimRow$time)
      print(outputMsg)
      write(outputMsg, file = "./updates.txt", append = TRUE)
      
      #Update records with accesspoints matching the given doctor/time
      mathcingRows <- fetchPossibleLocsMatchingGivenOneFromSql(passwordIn="Anz5Ur8TUPVuh", apidsIn=apidsForMissingGroup)  
      for(mathcingRow in 1:nrow(mathcingRows)){
        data <- updatePossibleLocs(passwordIn="Anz5Ur8TUPVuh", groupIdIn=bestSimRow$apGroupId, apGroupIdSimilarityIn=bestSim, 
        doctor1=mathcingRows$doctor[mathcingRow], aTime=mathcingRows$time[mathcingRow])
      }
    } else{
      print(paste(Sys.time(),'> No update'))
    }
    bestSim <- 0
    bestRow <- -1
    bestSimRow <- -1
  }
}