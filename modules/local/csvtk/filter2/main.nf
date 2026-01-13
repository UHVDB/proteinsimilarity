process CSVTK_FILTER2 {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/91/9135081f5bb2f0326f82ec97887978bd9a7c4dec6b44fce4c15709e064b96cdc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b9f1532f49256bb0_1?_gl=1*18xqofg*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.
    
    input:
    tuple val(meta) , path(tsv_gz)
    val(similarity_threshold)

    output:
    tuple val(meta) , path("${meta.id}.pruned.tsv.gz")  , emit: tsv_gz

    script:
    """
    ### Filter matrix
    csvtk filter2 \\
        ${tsv_gz} \\
        --tabs \\
        --filter '( \$3 >= ${similarity_threshold} )' \\
        --num-cpus ${task.cpus} \\
        --out-file ${meta.id}.pruned.tsv.gz
    """
}
