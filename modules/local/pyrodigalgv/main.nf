process PYRODIGALGV {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4a/4aed8a8d4e4e001842b449a6590736e0ce9cb72a889e3103ddd8afb24b6928d4/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-abfbf0a1651aa31f_1?_gl=1*wm9bjn*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(fna)

    output:
    tuple val(meta), path("${meta.id}.pyrodigalgv.faa.gz")  , emit: faa_gz

    script:
    """
    # predict genes from FNA
    pyrodigal-gv \\
        -i ${fna} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        --jobs ${task.cpus}

    gzip ${meta.id}.pyrodigalgv.faa
    """
}
