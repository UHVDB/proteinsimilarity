process INSTRAIN_COMPARE {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f0/f0ebc08c18c3c418569f8c4144009aaf14b5707445a7285286b79865ecd1328e/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-1bbbd3106c00b318_1?_gl=1*175s9vi*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(profiles)
    path(fna)

    output:
    tuple val(meta) , path("${meta.id}.instrain_compare/")  , emit: compare

    script:
    """
    # create stb file
    awk '/^>/{id=\$0; sub(/^>[[:space:]]*/, "", id); split(id,a," "); print a[1] "\\t" a[1]}' ${fna} > ${meta.id}.genomes.stb

    # run instrain compare
    inStrain compare \\
        --input ${profiles} \\
        --stb ${meta.id}.genomes.stb \\
        --output ${meta.id}.instrain_compare \\
        --processes ${task.cpus} \\
        --ani_threshold 0.995 \\
        --skip_plot_generation \\
    """
}
