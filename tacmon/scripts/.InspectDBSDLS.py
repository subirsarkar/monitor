
#!/usr/bin/env python

#
import dbsCgiApi
from dbsException import DbsException
#
import dlsClient
from dlsDataObjects import *
#
import os,sys,getopt

#   //
#  // Get DBS instance to use
# //
usage="\n Usage: python GetLFNfromDBSDLS.py <options> \n Options: \n --datasetPath=/primarydataset/datatier/procdataset \t\t dataset path \n --DBSAddress=<MCLocal/Writer> \t\t DBS database instance \n --DBSURL=<URL> \t\t DBS URL \n --DLSAddress=<lfc-cms-test.cern.ch/grid/cms/DLS/MCLocal_Test>\t\t DLS instance \n --DLSType=<DLS_TYPE_LFC> \t\t DLS type \n --SE=<SEname> \t\t option to trigger writing of LFN lists at that SE \n --help \t\t\t\t print this help \n"
valid = ['DBSAddress=','DBSURL=','DLSAddress=','DLSType=','datasetPath=','SE=','help']
try:
    opts, args = getopt.getopt(sys.argv[1:], "", valid)
except getopt.GetoptError, ex:
    print usage
    print str(ex)
    sys.exit(1)

url = "http://cmsdbs.cern.ch/cms/prod/comp/DBS/CGIServer/prodquery"
dbinstance = None
dlsendpoint = None
dlstype = None
datasetPath = None
sename = None

for opt, arg in opts:
    if opt == "--DBSAddress":
        dbinstance = arg
    if opt == "--DBSURL":
        url = arg
    if opt == "--DLSAddress":
        dlsendpoint = arg
    if opt == "--DLSType":
        dlstype = arg
    if opt == "--datasetPath":
        datasetPath = arg
    if opt == "--SE":
        sename = arg
    if opt == "--help":
        print usage
        sys.exit(1)

if datasetPath == None:
    print "--datasetPath option not provided. For example : --datasetPath /primarydataset/datatier/processeddataset"
    print usage
    sys.exit(1)
#if  sename == None:
#    print "--SE option not provided. For example : --SE=srm.cern.ch"
#    print usage
#    sys.exit(1)

if dbinstance == None:
    print "--DBSAddress option not provided. For example : --DBSAddress MCLocal/Writer"
    print usage
    sys.exit(1)
if dlstype == None:
   print "--DLSType option not provided. For example : --DLSType DLS_TYPE_LFC "
   print usage
   sys.exit(1)
if dlsendpoint == None:
    print "--DLSAddress option not provided. For example : --DLSAddress lfc-cms-test.cern.ch/grid/cms/DLS/MCLocal_Test"
    print usage
    sys.exit(1)


print ">>>>> DBS URL : %s DBS Address : %s"%(url,dbinstance)
print ">>>>> DLS instance : %s"%dlsendpoint

#  //
# // Get API to DBS
#//
## database instance 
args = {'instance' : dbinstance}
dbsapi = dbsCgiApi.DbsCgiApi(url, args)

#  //
# // Get API to DLS
#//
try:
  dlsapi = dlsClient.getDlsApi(dls_type=dlstype,dls_endpoint=dlsendpoint)
except dlsApi.DlsApiError, inst:
  msg = "Error when binding the DLS interface: " + str(inst)
  print msg
  sys.exit(1)



#  //
# // Get list of datasets
#//
try:
   if datasetPath:
     datasets = dbsapi.listProcessedDatasets(datasetPath)
   else:
     datasets = dbsapi.listProcessedDatasets("/*/*/*")
except dbsCgiApi.DbsCgiToolError , ex:
  print "%s: %s " %(ex.getClassName(),ex.getErrorMessage())
  print "exiting..."
  sys.exit(1)


for dataset in datasets:
#  //
# // Get list of blocks for the dataset and their location
#//
 dataset=dataset.get('datasetPathName')
 print "===== dataset %s"%dataset
 try:
  fileBlockList = dbsapi.getDatasetFileBlocks(dataset)
 except DbsException, ex:
  print "DbsException for DBS API getDatasetFileBlocks(%s): %s %s" %(dataset,ex.getClassName(), ex.getErrorMessage())
  sys.exit(1)

 if sename != None:
  primdataset=dataset.split('/')[1]
  fileName="%s_SE%s.lfns"%(primdataset,sename)
  LFNsatSEfile = open(fileName, 'w')
  SEblocks=[]

 for fileBlock in fileBlockList:
        entryList=[]
        try:
         entryList=dlsapi.getLocations(fileBlock.get('blockName'))
        except dlsApi.DlsApiError, inst:
          msg = "Error in the DLS query: %s." % str(inst)
          ##print msg
          print "== File block %s has no location found in DLS"%fileBlock.get('blockName')
          if "DLS Server don't respond" in msg:
            print msg
            sys.exit(1)
            raise RuntimeError, msg
        SEList=[]
        for entry in entryList:
         for loc in entry.locations:
          SEList.append(str(loc.host))
         print "== File block %s is located at: %s"%(fileBlock.get('blockName'),SEList)
         print "File block name: ", fileBlock.get('blockName')
         print "File block status: ", fileBlock.get('blockStatus')
         print "Number of files: ", fileBlock.get('numberOfFiles')
         print "Number of Bytes: ", fileBlock.get('numberOfBytes')

         if sename != None: 
          if SEList.count(sename)>0:
            print " Writing LFN list at SE %s "%sename 
            for file in fileBlock.get('fileList'):
                LFNsatSEfile.write("%s\n"%file.get('logicalFileName'))
            SEblocks.append(fileBlock.get('blockName'))

 ## get total number of events
 nevttot=0
 for block in dbsapi.getDatasetContents(dataset):
   for evc in block.get('eventCollectionList'):
     nevttot = nevttot + evc.get('numberOfEvents')

 if sename != None:
  LFNsatSEfile.close()
 ## get number of events at the given SE
  nevtsatSE=0
  for block in dbsapi.getDatasetContents(dataset):
         try:
          #hack the block name to cope with DBS API inconsistency
          blockname="/%s/%s"%(block.get('blockName').split('/')[1],block.get('blockName').split('/')[3])
         except:
           blockname=block.get('blockName')
           pass
         if SEblocks.count(blockname)>0:
          for evc in block.get('eventCollectionList'):
            nevtsatSE = nevtsatSE + evc.get('numberOfEvents')

  print "\n File %s written : contains LFNs at SE %s - for a total of %s events "%(fileName,sename,nevtsatSE)                                                                                                  
 print "\n total events: %s in dataset: %s\n"%(nevttot,dataset)




