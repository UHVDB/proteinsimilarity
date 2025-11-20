# UHVDB/proteinsimilarity
A Nextflow wrapper for calculating the protein similarity between a query set of viruses and ICTV genomes.

### Overview
This wrapper performs the following steps:

*If `--vmr_dmnd` is specified and the DIAMOND database exists, skips to step 4*

1. Download latest ICTV VMR specified with `--vmr_url` (`--email <your-email@email.com` needs to be specified for Entrez)
2. Download ICTV genomes
3. Call genes with pyrodigal-gv and create DIAMOND database of ICTV genomes
4. Split query viruses into chunks of size `--chunk_size`
5. Call genes for query chunks and align to ICTV database
6. Perform self alignment of query genomes
7. Calculate self score
8. Calculate normalized score
9. Combine normalized scores across chunks
10. Clean up intermediate files (OPTIONAL: `--remove_tmp true`)

### Quick start
In addition to automated downloads and cleanup (limiting disk requirements), this wrapper also makes setup very easy.

First, install Conda/Mamba/Micromamba/Pixi
*Example Micromamba installation*
```
"${SHELL}" <(curl -L micro.mamba.pm/install.sh)
```

Then create a Nextflow environment
```
micromamba create -n nextflow -c conda-forge -c bioconda nextflow -y
```

Activate the Nextflow environemtn
```
micromamba activate nextflow
```

Then just run the pipeline!
```
nextflow run UHVDB/proteinsimilarity -profile test,<docker/singularity/conda/mamba>
```

### Usage
The only arguments for this tool are:

`--query_fna`: Path (or URL) to a FNA file of query virus genomes.

`--vmr_dmnd`: Path (or URL) to a DMND database created from ICTV genomes (or any set of genomes).

`--vmr_url`: Path (or URL) to an ICTV VMR Excel file.

`--email`: Email address to use for Entrez downloads.

`--chunk_size`: Number (Integer) of host sequences contained in each chunk (default: 10,000)

`--diamond_args`: CLI arguments to use when running DIAMOND query-v-ictv (default: `--masking none -k 1000 -e 1e-3 --very-sensitive`)

`--min_score`: Minimum protein similarity values to output (default: 5.5, decreasing this to 0 will dramatically increase the output file size)

`--output`: Path to output TSV file containing protein similarity values for all queries vs ICTV viruses.

### Output
The only output of this wrapper is a protein similarity TSV file with 3 columns (`query`,`reference`,`protein_similarity`)
```tsv
NC_024375.1	Cinqassovirus_ah1--MG250483.1	0.49
NC_024375.1	Krischvirus_jse--EU863408.1	0.73
NC_024375.1	Krischvirus_georgiaone--EF437941.1	0.25
```

### Credits
This wrapper was made by @CarsonJM. However, primary credit of course goes to the UHGV-classifier developers (https://github.com/snayfach/UHGV-classifier), and their work should be cited if this wrapper is used (https://doi.org/10.1101/2025.11.01.686033).