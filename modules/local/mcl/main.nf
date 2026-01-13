process MCL {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://depot.galaxyproject.org/singularity/mcl%3A22.282--pl5321h7b50bb2_4"
    storeDir "${publish_dir}"

    input:
    tuple val(meta), path(tsv_gz)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.mcl.gz")  , emit: mcl_gz

    script:
    """
    ### Decompress
    gunzip -c ${tsv_gz} > ${meta.id}.distances.tsv

    ### Run MCL
    mcl \\
        ${meta.id}.distances.tsv \\
        --abc \\
        -sort revsize \\
        -te ${task.cpus} \\
        -o ${meta.id}.mcl

    ### Compress
    gzip ${meta.id}.mcl

    ### Cleanup
    rm ${meta.id}.distances.tsv
    """
}
