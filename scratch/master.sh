#!/bin/bash

# This is the master script that prepares and submits all jobs for LeafCutter
# At the highest directory, it is assumed that the files are arranged as such:
# ncbi/		leafcutter/		Ne-sQTL/		master.sh
# It is also assumed that the GTEx VCF file for the whole genome has already been downloaded and resides in ncbi/files/ 
# 	(see Documentation for details)
# Finally, please make sure that you have also downloaded the SRA files in ncbi/sra
# 	(again, please see Documentation for details)

# load modules
ml samtools
ml sra-tools
ml python/2.7-anaconda
ml bcftools
ml htslib
ml R
# ml qtltools - once MARCC guys install it
ml
# the directory of master.sh
homeDir = $(pwd -P)
# convert .sra to .bam files
cd ncbi/sra
# store all .sra names into text file for job array
ls *.sra >> sralist.txt
# submit batch job, return stdout in $RES
#jid1=$(sbatch --wait ${homeDir}/Ne-sQTL/src/12-14-2018/sra2bam.sh)
jid1=$(sbatch --wait ${homeDir}/Ne-sQTL/src/12-14-2018/sra2bam.sh)
# list of bams to be filtered 
ls *.bam >> bamlist.txt
# bring bed file to current directory
cp ${homeDir}/Ne-sQTL/data/12-07-2018/GRCh37.bed $PWD
# filter unplaced contigs
jid2=$(sbatch --wait --dependency=afterok:${jid1##* } ${homeDir}/Ne-sQTL/src/12-14-2018/filter_bam.sh)
ls *.filt >> filtlist.txt


# No longer renaming SRAs until after leafcutter

# maybe inclue an if-statement after each sbatch that would catch any non-zero exit codes and abort the program
# sbatch --wait $(homeDir)/Ne-sQTL/src/12-14-2018/rename_gtex.sh
# ls GTEX* >> gtexlist.txt
# mkdir juncfiles
sbatch --wait --dependency=afterok:${jid2##* } ${homeDir}/Ne-sQTL/src/12-10-2018/bam2junccall.sh
mv *.junc juncfiles/
cd juncfiles/
# strip junc files
for junc in $PWD/*; do mv ${junc} ${junc%.*}; echo ${junc%.*}; done
# put all of the renamed junc files in a text
ls GTEX* >> test_juncfiles.txt
# intron clustering
mkdir intronclustering/
python $homeDir/leafcutter/clustering/leafcutter_cluster.py -j test_juncfiles.txt -r intronclustering/ -m 50 -o testNE_sQTL -l 500000
#PCA calculation
python $homeDir/leafcutter/scripts/prepare_phenotype_table.py testNE_sQTL_perind.counts.gz -p 10 # works fine; there's no option for parallelization
# indexing and bedding
ml htslib; sh testNE_sQTL_perind.counts.gz_prepare.sh
# about the above line: you need to remove all of the index files and generate new ones once you convert the beds to a QTLtools compatible format
# filter the non-biallelic sites from genotype file using bcftools
sbatch --wait ${homeDir}/Ne-sQTL/src/12-18-2018/bcf_tools.sh $homeDir
# index our friend with tabix
tabix -p vcf GTExWGSGenotypeMatrixBiallelicOnly.vcf.gz
# prepare files for QTLtools
ls *qqnorm*.gz >> leafcutterphenotypes.txt 
# important: render these files compatible with QTLtools
sbatch --wait ${homeDir}/Ne-sQTL/src/12-18-2018/QTLtools-Filter.sh
ls *.qtltools >> qtltools-input.txt
# generate the corresponding tbi files
rm test*tbi
for i in {1..22}; do tabix -p bed testNE_sQTL_perind.counts.gz.qqnorm_chr${i}.gz.qtltools; echo "Bedding chromosome $i"; done
# download genotype covariates
wget https://storage.googleapis.com/gtex_analysis_v7/single_tissue_eqtl_data/GTEx_Analysis_v7_eQTL_covariates.tar.gz
tar -xzf GTEx_Analysis_v7_eQTL_covariates.tar.gz
# at this point, you want to pass each tissue PC file and the leafcutter PC file as command-line arguments into an R script that concatenates the PCs by GTEX ID
for tissue in GTEx_Analysis_v7_eQTL_covariates/*; do Rscript --vanilla $homeDir/src/12-21-2018/mergePCs.R testNE_sQTL_perind.counts.gz.PCs ${tissue}; echo "Concatenating ${tissue}"; done
mkdir covariates
mv *covariates_* covariates/
# call QTLtools
sbatch --wait ${homeDir}/Ne-sQTL/src/12-31-2018/QTLtools-nompass.sh



