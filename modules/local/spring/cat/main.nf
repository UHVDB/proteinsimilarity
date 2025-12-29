process SPRING_CAT {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f6/f67f27c8cb2d1a149564f1a10f5f2b7a6acfa87ef3d3d27d2d8752dbe95e6acf/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ad27dd6990039308_1?_gl=1*17injuu*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.

    input:
    tuple val(meta), path(springs)

    output:
    tuple val(meta), path("${meta.id}.spring")  , emit: spring

    script:
    """
    ### Extract spring archive ###
    for spring in \${springs[@]}; do
        spring \\
            --decompress \\
            --input-file \$spring \\
            --output-file \${spring}.fastq \\
            --gzipped_fastq \\
            --num-threads ${task.cpus}
    done

    ### Concatenate fastqs ###
    cat *.fastq.gz.1 > all_R1.fastq.gz
    if ls *.fastq.gz.2 1> /dev/null 2>&1; then
        cat *.fastq.gz.2 > all_R2.fastq.gz

    ### Convert to spring ###
    if ls all_R2.fastq.gz 1> /dev/null 2>&1; then
        spring \\
            --compress \\
            --input-file all_R1.fastq.gz all_R2.fastq.gz \\
            --output-file ${meta.id}.spring \\
            --gzipped_fastq \\
            --num-threads ${task.cpus}
    else
        spring \\
            --compress \\
            --input-file all_R1.fastq.gz \\
            --output-file ${meta.id}.spring \\
            --gzipped_fastq \\
            --num-threads ${task.cpus}
    fi

    ### Cleanup ###
    rm *.fastq.gz*
    """
}
