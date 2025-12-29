process SPACEREXTRACTOR_COMBINERESULTS {
    tag "combined"
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/29/2900c330cd8dd25094b4cd86e4a32a576ddb340f412ac17f6715ac4136cf495c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-f4b63d63859b49f0_1?_gl=1*1gn5au*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    path(tsv_gzs)

    output:
    path("combined.spacerextractor.tsv.gz") , emit: tsv_gz

    script:
    """
    ### Concatenate TSVs ###
    for table in ${tsv_gzs[0]}; do
        zcat \${table} | head -n 1 > combined.spacerextractor.tsv
    done

    for table in ${tsv_gzs}; do
        zcat \${table} | tail -n +2 >> combined.spacerextractor.tsv
    done

    ### Compress output ###
    pigz combined.spacerextractor.tsv
    """
}
