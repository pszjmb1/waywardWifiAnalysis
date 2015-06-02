# -*- coding: utf-8 -*-
"""
Wayward analysis
Generate timeseries of unique ids from apid patterns from possiblelocs
"""
import MySQLdb

# Class for letterChords: which outputs sequentially values from aaa - zzz 
class LetterChord:
    def __init__(self):
        self.first=ord('z')
        self.second=ord('z')
        self.third=ord('z')
    def next(self):
        self.third = self.third + 1
        if self.third > ord('z'):
            self.third = ord('a')
            self.second = self.second + 1
            if self.second > ord('z'):
                self.second = ord('a')
                self.first = self.first + 1                
                if self.first > ord('z'):
                    self.first = ord('a')
        return chr(self.first)+chr(self.second)+chr(self.third)

def calculateJaccard(set1, set2):
   '''Given two sets of chords this outputs the Jaccard index for them
       See http://en.wikipedia.org/wiki/Jaccard_index '''
   x = [set1, set2] 
   jabn = set.intersection(*x)
   jabd = set.union(*x)  
   return float(len(jabn))/len(jabd)
   
uniqueApIds = {}
letterChord = LetterChord()
   
def getWordsFromApids(apids):
    ''' Given comma seperated apids, output corresponding letterchords
    '''
    tempApIds = str(apids).split(",")
    words = set()
    for item in tempApIds :
        if not (item in uniqueApIds):
            uniqueApIds[item] = letterChord.next()
        words.add(uniqueApIds[item])
    return words

def writeApChords1(recordset):
    '''Write to file a time series of access points represented as letterChods
    in the form of time value \t sentence of chords \t Jaccard index 
    between this and previous sentence.
       Parameters:
           recordset is a sql recordset with rows containing rtime and apids
    '''
    fo = open("foo.txt", "wb")
    lastSentence = set()
    for row in recordset :
        words = getWordsFromApids(row[1])
        ji = calculateJaccard(words, lastSentence)
        lastSentence = words
        out = str(row[0]) + '\t' + str(ji) + '\t' + ' '.join(sorted(words))
        fo.write(out + "\n" )
        print out
    fo.close()
    print letterChord.next()
    

clusters = []    # This is global to allow multiple passes to build up a common list against different shifts
def writeApChords2(recordset):
    '''Write to file a time series of cluster labels in the form of:
        time value \t cluster label \t sentence 
       Parameters:
           recordset is a sql recordset with rows containing rtime and apids
    '''
    THRESHOLD=0.5
    OUTPUTFILENAME = "foo2.txt"
    print 'calculating clusters'
    ignore = True   # used to ignore the first record (which is garbage)
    for row in recordset :
        if ignore:
            ignore = False
            continue
        topJiVal=None
        topJiClusterInc = -1
        currentSentence = getWordsFromApids(row[1])
        clusterInc = 0
        for cluster in clusters:
            for previousSentence in cluster:
                ji = calculateJaccard(currentSentence, 
                                      previousSentence[1]
                                      )
                if ji > THRESHOLD and ji > topJiVal:
                    topJiVal=ji
                    topJiClusterInc = clusterInc
            clusterInc = clusterInc + 1   
        if -1 >= topJiClusterInc:
            clusters.append([[row,currentSentence]])
        else:
            clusters[topJiClusterInc].append([row,currentSentence])
    
    fo = open(OUTPUTFILENAME, "wb") 
    print 'writing data ...'
    incr = 0
    out = ''
    for cluster in clusters:
        for item in cluster:
            out = out + str(item[0][2]) + '\t'+ str(item[0][3]) + '\t' + str(incr) + '\n'#str(item[1]) + '\n'
        incr = incr + 1
        fo.write(out)
    fo.close()
    print letterChord.next()

# Retrieve data from database
db = MySQLdb.connect(host="localhost",
                     user="root",
                      passwd="Anz5Ur8TUPVuh",
                      db="wayward")

cur = db.cursor() 
sql = "SELECT `rtime`, `apids`, `time`, `@doctorIMEI` FROM possiblelocs;"
print sql
cur.execute(sql)
recordset = cur.fetchall()
writeApChords2(recordset)