# module load python/3.7
# python -m venv ./venv
# source ./venv/bin/activate
# pip install snakemake
# snakemake --version

# snakemake --dag -n | dot -Tsvg > dag.svg

configfile: "config.yaml"

# subworkflow sprime_prep:
#     workdir:
#            "."
#     snakefile:
#             "sprime_Snakefile"
#     configfile:
#             "config.yaml"

include: "sprime_Snakefile"

rule all:
    input:
        "GTEx_Analysis_v8_sQTL/",
        "GTEx_Analysis_v8_sQTL_phenotype_matrices/",
        sprime_prep((expand("kg_vcf/1kg_yri_chr{q}.vcf.gz", q=range(1,23)))),
        sprime_prep("kg_vcf/1kg_yri_chrX.vcf.gz"),
        sprime_prep(expand("{kg_dir}/ALL.chr{q}.shapeit2_integrated_v1a.GRCh38.20181129.phased.vcf.gz", kg_dir=config["kg_dir"], q=range(1,23))),
        sprime_prep(expand("gtex_vcf/gtex_chr{v}.snps.recode.vcf.gz", v=range(1,23))),
        sprime_prep("gtex_vcf/gtex_chrX.snps.recode.vcf.gz.tbi")


rule dl_files:
    params:
        sqtl="https://storage.googleapis.com/gtex_analysis_v8/single_tissue_qtl_data/GTEx_Analysis_v8_sQTL.tar",
        phen="https://storage.googleapis.com/gtex_analysis_v8/single_tissue_qtl_data/GTEx_Analysis_v8_sQTL_phenotype_matrices.tar"
    output:
        "GTEx_Analysis_v8_sQTL.tar",
        "GTEx_Analysis_v8_sQTL_phenotype_matrices.tar"
    shell:
        "wget {params.sqtl}; wget {params.phen}"

rule decomp:
    input:
        sqtl="GTEx_Analysis_v8_sQTL.tar",
        phen="GTEx_Analysis_v8_sQTL_phenotype_matrices.tar"
    output:
        "GTEx_Analysis_v8_sQTL/",
        "GTEx_Analysis_v8_sQTL_phenotype_matrices/"
    shell:
        "tar -xvf {input.sqtl}; tar -xvf {input.phen};"
        "rm {input.sqtl}; rm {input.phen}"

### Consider making a sub workflow

# rule mkdir_vcf:
#     output:
#         directory("gtex_vcf/"),
#         directory("kg_vcf/"),
#         touch(".mkdir_vcf.chkpnt")
#     shell:
#         "mkdir -p {output}"


