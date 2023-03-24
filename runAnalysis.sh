#!/bin/bash
export HOME=$(pwd)
nthd=2
nevt_Gen=$2
seed=$1
export SCRAM_ARCH=slc7_amd64_gcc820
exit_on_error() {
    result=$1
    code=$2
    message=$3

    if [ $1 != 0 ]; then
        echo $3
        exit $2
    fi
} 

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_20/src ] ; then
  echo release CMSSW_10_6_20 already exists
else
  scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
eval $(scram runtime -sh)

mkdir -p Config/GEN/python
mv ../../fragment.py Config/GEN/python/.
scram b ||exit_on_error $? 159 "Failed to build fragment--ErrorPattern"

#Gen
cmsDriver.py Config/GEN/python/fragment.py --fileout file:GEN.root --mc --eventcontent RAWSIM --datatier GEN --conditions 106X_upgrade2018_realistic_v15_L1v1 --beamspot Realistic25ns13TeVEarly2018Collision --step LHE,GEN --geometry DB:Extended --era Run2_2018 --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${seed})" --python_filename GEN_2018_cfg.py -n ${nevt_Gen} --no_exec --nThreads $nthd|| exit_on_error $? 159 "Failed to run Gen config--ErrorPattern"

cmsRun -e -j report0.xml GEN_2018_cfg.py || exit_on_error $? 159 "Failed to run Gen cmsRun--ErrorPattern"
nevt0=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report0.xml | tail -n 1)

#SIM
cmsDriver.py step2 --filein file:GEN.root --fileout file:SIM.root --mc --eventcontent RAWSIM --runUnscheduled --datatier GEN-SIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --beamspot Realistic25ns13TeVEarly2018Collision --step SIM --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename SIM_2018_cfg.py -n $nevt0 --no_exec|| exit_on_error $? 159 "Failed to run SIM config--ErrorPattern"

cmsRun -e -j report1.xml SIM_2018_cfg.py || exit_on_error $? 159 "Failed to run SIM cmsRun--ErrorPattern"
nevt1=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report1.xml | tail -n 1)

#DIGI
cmsDriver.py step3 --filein file:SIM.root --fileout file:DIGIPremix.root  --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL18_106X_upgrade2018_realistic_v11_L1v1-v2/PREMIX" --mc --eventcontent PREMIXRAW --runUnscheduled --datatier GEN-SIM-DIGI --conditions 106X_upgrade2018_realistic_v15_L1v1 --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 --nThreads $nthd --geometry DB:Extended --datamix PreMix --era Run2_2018 --python_filename DIGIPremix_2018_cfg.py -n $nevt1 --no_exec > /dev/null || exit_on_error $? 159 "Failed to run DIGI config--ErrorPattern"

cmsRun -e -j report2.xml DIGIPremix_2018_cfg.py || exit_on_error $? 159 "Failed to run DIGI cmsRun--ErrorPattern"
nevt2=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report2.xml | tail -n 1)

pushd ../..
if [ -r CMSSW_10_2_16_UL/src ] ; then
  echo release CMSSW_10_2_16_UL already exists
else
  scram p CMSSW CMSSW_10_2_16_UL
fi
cd CMSSW_10_2_16_UL/src
eval $(scram runtime -sh)
popd

#HLT
cmsDriver.py step4 --filein file:DIGIPremix.root --fileout file:HLT.root --mc --eventcontent RAWSIM --datatier GEN-SIM-RAW --conditions 102X_upgrade2018_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2018v32 --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename HLT_2018_cfg.py -n $nevt2 --no_exec || exit_on_error $? 159 "Failed to run HLT config--ErrorPattern"

cmsRun -e -j report3.xml HLT_2018_cfg.py || exit_on_error $? 159 "Failed to run HLT cmsRun--ErrorPattern"
nevt3=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report3.xml | tail -n 1)

pushd ../..
if [ -r CMSSW_10_6_20/src ] ; then
  echo release CMSSW_10_6_20 already exists
else
  scram p CMSSW CMSSW_10_6_20
fi
cd CMSSW_10_6_20/src
eval $(scram runtime -sh)
popd

#RECO
cmsDriver.py step5 --filein file:HLT.root --fileout file:RECO.root --mc --eventcontent AODSIM --runUnscheduled --datatier AODSIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename RECO_2018_cfg.py -n $nevt3 --no_exec || exit_on_error $? 159 "Failed to run RECO config--ErrorPattern"

cmsRun -e -j report4.xml RECO_2018_cfg.py || exit_on_error $? 159 "Failed to run RECO cmsRun--ErrorPattern"
nevt4=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report4.xml | tail -n 1)

#miniAOD
cmsDriver.py step6 --filein file:RECO.root --fileout file:MiniAOD.root --mc --eventcontent MINIAODSIM --runUnscheduled --datatier MINIAODSIM --conditions 106X_upgrade2018_realistic_v15_L1v1 --step PAT --nThreads $nthd --geometry DB:Extended --era Run2_2018 --python_filename MINIAOD_2018_cfg.py -n $nevt4 --no_exec|| exit_on_error $? 159 "Failed to run miniAOD config--ErrorPattern"

cmsRun -e -j report5.xml MINIAOD_2018_cfg.py || exit_on_error $? 159 "Failed to run miniAOD cmsRun--ErrorPattern"
nevt5=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" report5.xml | tail -n 1)

echo "Final Gen events: $nevt0"
echo "Final SIM events: $nevt1"
echo "Final DIGI events: $nevt2"
echo "Final HLT events: $nevt3"
echo "Final RECO events: $nevt4"
echo "Final miniAOD events: $nevt5"

eval `scram unsetenv -sh`
gfal-copy -p MiniAOD.root davs://cmsxrootd.hep.wisc.edu:1094/store/user/mondal6/MC_files/tmpHome/Generation_Large/ZTZ0/${seed}_miniAOD.root 
