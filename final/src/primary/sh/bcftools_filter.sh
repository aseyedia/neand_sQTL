#!/bin/bash
#SBATCH --job-name=bialleliconly
#SBATCH --time=16:0:0
#SBATCH --partition=shared
#SBATCH --nodes=1
# number of tasks (processes) per node
#SBATCH --ntasks-per-node=24

echo "Filtering non-biallelic sites from genotype file ucing bcftools..."
ml bcftools
# filters all non-biallelic sites
bcftools view -m2 -M2 -v snps --threads 23 -O z -o GTExWGSGenotypeMatrixBiallelicOnly.vcf.gz \
  ${vcf}