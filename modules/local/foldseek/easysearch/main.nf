process FOLDSEEK_EASYSEARCH {
    tag "${meta.id}"
    label "process_super_high"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa4194388365921de870bac23d8693e92bfb16ca165c0344a5d9e13cd5b2e6af/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-12803fde2c4845e0_1?_gl=1*9efwsl*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(query_db)
    path(ref_db)

    output:
    tuple val(meta), path("${meta.id}_nohit_v_refDB.tsv.gz")    , emit: tsv_gz

    script:
    """
    ### Run foldseek
    foldseek easy-search \\
        ${meta.id}_3di_db \\
        viral_ref_db \\
        ${meta.id}_nohit_v_refDB.tsv \\
        tmp \\
        --threads ${task.cpus} \\
        -e 1e-3 \\
        -s 9.5 \\
        -c 0.9 \\
        --max-seqs 1000

    ### Compress
    gzip ${meta.id}_nohit_v_refDB.tsv

    ### Cleanup
    rm -rf tmp
    """
}
