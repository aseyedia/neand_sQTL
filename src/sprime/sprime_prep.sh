#!/bin/bash
#SBATCH --job-name=sprime_prep
#SBATCH --time=24:0:0
#SBATCH --partition=shared
#SBATCH --nodes=1
# number of tasks (processes) per node
#SBATCH --ntasks-per-node=4
#SBATCH --array=1-23%23

### 00-sprime-prep.sh ###

if [ ${SLURM_ARRAY_TASK_ID} -eq 23 ]
then
    i="X"
else
    i=${SLURM_ARRAY_TASK_ID}
fi

ml bcftools
ml vcftools
ml htslib
ml java

# gtex-sprime directory
wrkdir=/scratch/groups/rmccoy22/aseyedi2/sQTLv8/sprime
# 1kg project direcotry (1kg-hs37d5/)
kg_dir=/work-zfs/rmccoy22/resources/1kg-GRCh38
# original gtex vcf (prefilter) GTEx_Analysis_2016-01-15_v7_WholeGenomeSeq_635Ind_PASS_AB02_GQ20_HETX_MISS15_PLINKQC.vcf.gz
gtex_vcf=/scratch/groups/rmccoy22/aseyedi2/sQTLv8/data/vcf/GTEx_Analysis_2017-06-05_v8_WholeGenomeSeq_838Indiv_Analysis_Freeze.vcf.gz

cd ${wrkdir}

mkdir -p gtex_vcf

# split the GTEx VCF by chromosome
tabix -h ${gtex_vcf} chr${i} > gtex_vcf/gtex_chr${i}.vcf

mkdir -p kg_vcf

# select only SNPs, YRI samples from 1kg VCFs
bcftools view \
  --force-samples \
  -S yri.txt \
  -V indels \
  -O z \
  -o kg_vcf/1kg_yri_chr${i}.vcf.gz \
  ${kg_dir}/ALL.chr${i}.shapeit2_integrated_v1a.GRCh38.20181129.phased.vcf.gz

# select only SNPs from GTEx VCFs
vcftools \
  --vcf gtex_vcf/gtex_chr${i}.vcf \
  --remove-indels \
  --recode \
  --out gtex_vcf/gtex_chr${i}.snps

# bgzip and tabix index
bgzip gtex_vcf/gtex_chr${i}.snps.recode.vcf
tabix -p vcf gtex_vcf/gtex_chr${i}.snps.recode.vcf.gz

tabix -p vcf kg_vcf/1kg_yri_chr${i}.vcf.gz

# merge 1kg_YRI and GTEx
# allow SNPs that absent from in one VCF
# to be assumed as heterozygous reference
mkdir -p merged

bcftools merge \
  -0 \
  -O z \
  -o merged/merged_chr${i}.vcf.gz \
  kg_vcf/1kg_yri_chr${i}.vcf.gz  \
  gtex_vcf/gtex_chr${i}.snps.recode.vcf.gz

mkdir -p filtered_vcf
# exclude SNPs with missing genotypes and exclude SNPs with AC=0 (no ALT genotypes)
bcftools filter \
  --include 'AN=1890 && AC > 0' \
  --threads 4 \
  -O z \
  -o filtered_vcf/merged_filtered_chr${i}.vcf.gz \
  merged/merged_chr${i}.vcf.gz