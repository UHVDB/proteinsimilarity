process UHVDB_PRUNE {
    tag "$meta.id"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/20/20246727909eb49ec44fa645f8185ad4b39f2a41a519da236304ea6d805d71d7/data"

    input:
    tuple val(meta) , path(tsv_gz), path(mcl_gz)
    val(similarity_threshold)

    output:
    tuple val(meta) , path("${meta.id}.pruned.tsv.gz")  , emit: tsv_gz

    script:
    """
    ### Prune graph
    uhvdb_prune.py \\
        --graph ${tsv_gz} \\
        --clusters ${mcl_gz} \\
        --threshold ${similarity_threshold} \\
        --output ${meta.id}.pruned.tsv

    ### Compress
    gzip -f ${meta.id}.pruned.tsv
    """
}
