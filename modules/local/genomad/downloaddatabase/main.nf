process GENOMAD_DOWNLOADDATABASE {
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/bb/bbaadac0c5d49bb7c664d9d3651521aa638b795cdbab7eb9493ec66350508f97/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-4eb739aab45fd5c9_1?_gl=1*1w9htsp*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    storeDir "${params.db_dir}/genomad/"

    output:
    path "genomad_db/"  , emit: genomad_db

    script:
    """
    genomad \\
        download-database .
    """
}
