#!/bin/bash
#
# Compute specific mate scores for EPD's changed from ChestUCI_23102018.epd to matetrack.epd
#

# exit on errors
set -e

echo "started at: " `date`

sf7=dd9cf305816c84c2acfa11cae09a31c4d77cc5a5
firstrev=$sf7
lastrev=54ad986768eec524aeab721713ea2009931b51b3  # last commit with old .epd
exclude=exclude_commits.sha

# the repo uses 1M nodes for each position
nodes=1000000

# clone SF as needed, download an old, non-embedded master net as well
if [[ ! -e Stockfish ]]; then
   git clone https://github.com/official-stockfish/Stockfish.git
   wget https://tests.stockfishchess.org/api/nn/nn-82215d0fd0df.nnue
fi

# update SF, get a sorted revision list and all the release tags
cd Stockfish/src
git checkout master >& checkout.log
git fetch origin  >& fetch.log
git pull >& pull.log
revs=`git rev-list --reverse $firstrev^..$lastrev`
tags=`git ls-remote --quiet --tags | grep -E "sf_[0-9]+(\.[0-9]+)?"`
cd ../..

csv=matecorrect$nodes.csv  # list of previously computed results
new=newcorrect$nodes.csv   # temporary list of newly computed results
out=out.tmp                # file for output from matereport.py

# if necessary, create a new csv file with the correct header
if [[ ! -f $csv ]]; then
   echo "Commit Date,Commit SHA,Removed EPDs 1,2,3,4,5,New bm EPD,Release tag" > $csv
fi

# if necessary, merge results from a previous (interrupted) run of this script
if [[ -f $new ]]; then
   cat $new >> $csv && rm $new
   python3 plotdata.py $csv
fi

# go over the revision list and obtain missing results if necessary
for rev in $revs
do
   if ! grep -q "$rev" "$csv"; then
      cd Stockfish/src
      git checkout $rev >& checkout2.log
      epoch=`git show --pretty=fuller --date=iso-strict $rev | grep 'CommitDate' | awk '{print $NF}'`
      tag=`echo "$tags" | grep $rev | sed 's/.*\///'`
      if ! grep -q "$rev" "../../$exclude"; then
         echo "running matereport on revision $rev "

         # compile revision and get binary
         make clean >& clean.log
         arch=x86-64-avx2
         # for very old revisions, we need to fall back to x86-64-modern
         if ! grep -q "$arch" Makefile; then
            arch=x86-64-modern
         fi
         CXXFLAGS='-march=native' make -j ARCH=$arch profile-build >& make.log
         mv stockfish ../..
         cd ../..

         nice python3 matereport.py --engine ./stockfish --nodes $nodes --epdFile difference.epd >& $out

         # collect results for this revision
         total=`grep "Reported mates:" $out | awk '{print $NF}'`
      else
         echo "skipping non-compiling revision $rev "
         cd ../..
         total= 
      fi
      echo "$epoch,$rev,$total,$tag" >> $new
   fi
done

if [[ -f $new ]]; then
   cat $new >> $csv && rm $new
fi

echo "ended at: " `date`
