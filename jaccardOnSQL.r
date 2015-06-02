library("sets")
similarityMatrix <- function(data, numRows=50) {
  # Given data from the possiblelocs table cols(`rtime`, `apids`, `time`, `@doctorIMEI`) and a number of rows; 
  # the function creates a matrix of apid set similarities for each combination of apids (except the cases of self with self).
  # For the number of rows (k), the matrix will be of length 1/2 (k^2-k). Each row is of the form apids for timepoint Alpha, 
  # apids for timepoint Beta, similarity. To view the output (A) do: View(t(A)); plot(t(A)[,3])
  #
  # Args:
  #   data: The resulting dataset from a query of the form: "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;".
  #         See analysis5ShiftAndDoctorSpecific.sql for how to compose possiblelocs.
  #   numRows: The number of rows of data to do the combinations on (defaults to 50 -- therefore output matrix will be of length 1225).
  #
  # Returns:
  #   A matrix of set_similarity for all combinations of apids except self vs self.
  
  # Generate a matrix of set_similarity for all combinations of apids 
  combn(head(data$apids,numRows), 2, function(x) {
    split <- strsplit(x, ' ')
    c(split[[1]], split[[2]], set_similarity(as.set(unlist(strsplit(split[[1]], ','))), as.set(unlist(strsplit(split[[2]], ',')))))
  })
}

apidSetSimilarity <- function(data, x,y) {
  # Given a data frame of the possiblelocs table cols(`rtime`, `apids`, `time`, `@doctorIMEI`), and
  # two rown to check similarity of, 
  # returns the corresponding time and similarity scores
  #
  # Args:
  #   data: The resulting dataset from a query of the form: "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;".
  #         See analysis5ShiftAndDoctorSpecific.sql for how to compose possiblelocs.
  #   x:    The first row to use for similarity comparison
  #   y:    The second row to use for similarity comparison
  #
  # Returns:
  #   c(time[x],time[y],similarity)
  c(as.integer(data$time[x]),as.integer(data$time[y]),set_similarity(as.set(unlist(strsplit(data$apids[x], ','))), as.set(unlist(strsplit(data$apids[y], ',')))))
}

apidSetDissimilarity <- function(data, x,y) {
  # Given a data frame of the possiblelocs table cols(`rtime`, `apids`, `time`, `@doctorIMEI`), and
  # two rown to check dissimilarity of, 
  # returns the corresponding time and dissimilarity scores
  #
  # Args:
  #   data: The resulting dataset from a query of the form: "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;".
  #         See analysis5ShiftAndDoctorSpecific.sql for how to compose possiblelocs.
  #   x:    The first row to use for similarity comparison
  #   y:    The second row to use for similarity comparison
  #
  # Returns:
  #   c(time[x],time[y],dissimilarity)
  c(as.integer(data$time[x]),as.integer(data$time[y]),set_dissimilarity(as.set(unlist(strsplit(data$apids[x], ','))), as.set(unlist(strsplit(data$apids[y], ','))), "Jaccard"))
}

fetchPossibleLocsFromSql <- function(userIn = 'root', passwordIn, hostIn = 'localhost', dbnameIn ='wayward') {
  # Given connetion info, connect to a Wayward database with a populated possiblelocs table
  # and select all rows and necessary columns for running a similarityMatrix or other operations.
  #
  # Args:
  #   userIn: the db user name (default = 'root'), 
  #   passwordIn: the db user's password, 
  #   hostIn = the db host (defauilt: 'localhost')
  #   dbnameIn = the datadabse name (default: 'wayward')
  #
  # Returns:
  #   Selected data
  
  library(RMySQL)
  sql <- "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;"
  con <- dbConnect(MySQL(), user = userIn, password = passwordIn,  host = hostIn, dbname = dbnameIn)
  data <- dbGetQuery(con, sql)
  dbDisconnect(con)
  data
}

buildFullSimilarityMatrix <- function(n,data){
  # Given the number of rows to check (n), and a data frame (data) this creates a new data.frame with 
  # the similarity scores for 1:n rows of data for the timepoints from the rows
  #
  # Args:
  #   n: number of rows of data to check
  #   data: The resulting dataset from a query of the form: "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;".
  #         See analysis5ShiftAndDoctorSpecific.sql for how to compose possiblelocs.
  #
  # Returns:
  #   data.frame(time[x]s,time[y]s,similarities)
  
  counter <- 1
  matSize = n*n
  xs <- numeric(matSize)
  ys <- numeric(matSize)
  zs <- numeric(matSize)
  for(x in 1:n){ 
    for(y in 1:n){ 
      out <- apidSetSimilarity(data,x,y) 
      xs[counter]<- out[1]
      ys[counter]<- out[2]
      zs[counter]<- out[3]
      counter <- counter + 1}
  }
  data.frame(xs, ys, zs)
}

buildFullMatrix <- function(n,data,f){
  # Given the number of rows to check (n), and a data frame (data) this creates a new data.frame with 
  # function (f) scores for 1:n rows of data for the timepoints from the rows
  #
  # Args:
  #   n: number of rows of data to check
  #   data: The resulting dataset from a query of the form: "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs WHERE time IS NOT NULL ORDER BY time;".
  #         See analysis5ShiftAndDoctorSpecific.sql for how to compose possiblelocs.
  #   f: a function that takes (data, x,y) as arguments
  #
  # Returns:
  #   data.frame(time[x]s,time[y]s,scores)
  
  counter <- 1
  matSize = n*n
  xs <- numeric(matSize)
  ys <- numeric(matSize)
  zs <- numeric(matSize)
  for(x in 1:n){ 
    for(y in 1:n){ 
      out <- f(data,x,y) 
      xs[counter]<- out[1]
      ys[counter]<- out[2]
      zs[counter]<- out[3]
      counter <- counter + 1}
  }
  data.frame(xs, ys, zs)
}

castFullMatrix <- function(sm){
  # Given a full (dis)similarity matrix (see buildFullSimilarityMatrix) (sm) in the form of 
  # time[x]s,time[y]s,similarities,
  # returns a matrix of the form 
  #           time1        time 2       time3....
  # time1   similarity1  similarity2   similarity3
  # time 2  similarity4  similarity5   similarity6
  # time3   similarity7  similarity8   similarity9
  #....
  #
  # Args:
  #   sm: Matrix in the form time[x]s,time[y]s,scores
  #
  # Returns:
  #   full similarity matrix
  
  library(reshape2)
  acast(sm, xs~ys, value.var="zs")
}

testSimilarityMatrix<- function(){
  # Test routine to demonstrate usage of similarityMatrix
  
  data <- fetchPossibleLocsFromSql(passwordIn="Anz5Ur8TUPVuh")
  comb <- similarityMatrix(data)
  View(t(comb))
  plot(t(comb)[,3])
}

testCastFullSimilarityMatrix<- function(){
  # Test routine to demonstrate usage of similarityMatrix
  
  data <- fetchPossibleLocsFromSql(passwordIn="Anz5Ur8TUPVuh")
  cfsm <- castFullMatrix(buildFullSimilarityMatrix(20,data))
  #View(t(cfsm))
}

testBuildFullMatrix<- function(rows=50,f=apidSetDissimilarity){
  # Test routine to demonstrate usage of BuildFullMatrix
  
  data <- fetchPossibleLocsFromSql(passwordIn="Anz5Ur8TUPVuh")
  cfsm <- buildFullMatrix(rows,data,f)
  cfsm
  #View(t(cfsm))
}


testCastFullMatrix<- function(rows=50,f=apidSetDissimilarity){
  # Test routine to demonstrate usage of similarityMatrix
  
  data <- fetchPossibleLocsFromSql(passwordIn="Anz5Ur8TUPVuh")
  cfsm <- castFullMatrix(buildFullMatrix(rows,data,f))
  cfsm
  #View(t(cfsm))
}

testMultidimensionalScalingOfDissimilarityMatrix <- function(rows=50){
  # Test routine to demonstrate Multidimensional Scaling Of Dissimilarity Matrix
  dissimMatrix <- testCastFullMatrix(rows)
  mds <- cmdscale(dissimMatrix)
  x <- mds[, 1]
  y <- -mds[, 2]
  plot(x, y, type = "n", xlab = "", ylab = "", asp = 1, axes = FALSE,
       main = "cmdscale(dissimilarities)")
  text(x, y, rownames(mds), cex = 0.6)
}

testkMeans <-function(rows=50){
  # Test routine to demonstrate kmeans on dissimilarity matrix
  dissimMatrix <- testCastFullMatrix(rows)
  cl <- kmeans(dissimMatrix, 4)  # looks like 4 is the rignt number of ks
  plot(dissimMatrix, col = cl$cluster)
  points(cl$centers, col = 1:4, pch = 8, cex = 2)  
  dissimMatrix
}

testDBScan<-function(rows=50,f=apidSetDissimilarity, eps=0.2){
  library("fpc")
  x <- testCastFullMatrix(rows, f)
  ds <- dbscan(x, eps)
}