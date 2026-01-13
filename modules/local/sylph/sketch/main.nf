process SYLPH_SKETCH {
    tag "sylph_db"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cd/cd318dddb3190ddd52618f2007a19adc2c54b0ab57c770d6f641feb77a6adc27/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-70d0310de62c2d55_1?_gl=1*7sbclu*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTU1NzczMTA4LjE3NjYxNzI5NzguMTc2NjE3Mjk3OA..
    storeDir "${params.db_dir}/sylph"
    

    input:
    path(fna)

    output:
    path("${fna}.c200.syldb")   , emit: syldb

    script:
    """
    # Create sylph sketch from reference fasta
    sylph sketch \\
        --genomes ${fna} \\
        -t ${task.cpus} \\
        --individual-records \\
        --out-name-db ${fna}.c200 \\
        -c 200
    """
}
