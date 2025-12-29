process SYLPH_PROFILE {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cd/cd318dddb3190ddd52618f2007a19adc2c54b0ab57c770d6f641feb77a6adc27/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-70d0310de62c2d55_1?_gl=1*7sbclu*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTU1NzczMTA4LjE3NjYxNzI5NzguMTc2NjE3Mjk3OA..


    input:
    tuple val(meta) , path(spring)
    tuple val(meta2), path(virus_db)
    tuple val(meta3), path(bac_db)

    output:
    tuple val(meta), path("${meta.id}.profile.tsv.gz") , emit: tsv_gz

    script:
    def spring_out  = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    def sylph_reads = meta.single_end ? "-r ${meta.id}.fastq.gz" : "-1 ${meta.id}_R1.fastq.gz -2 ${meta.id}_R2.fastq.gz"
    """
    # decompress spring
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped_fastq \\
        --num-threads ${task.cpus}

    # run sylph profile
    sylph profile \\
        ${virus_db} \\
        ${bac_db} \\
        ${sylph_reads} \\
        --output-file ${meta.id}.profile.tsv \\
        -t ${task.cpus} \\
        --min-number-kmers 3 \\
        --estimate-unknown

    gzip ${meta.id}.profile.tsv
    rm -rf *.fastq.gz
    """
}
