process SEQKIT_CONCAT {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/85/85b40b925e4d4a62f9b833bbb0646d7ea6cf53d8a875e3055f90da757d7ccd27/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ec0d76090cceee7c_1?_gl=1*d6zgjg*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(fasta)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.fna.gz") , emit: fna_gz

    script:
    def fasta_list   = fasta.collect { fasta_files -> fasta_files.toString() }.join(',')
    """
    ### Create TSV with input files
    IFS=',' read -r -a fasta_array <<< "${fasta_list}"
    printf '%s\\n' "\${fasta_array[@]}" > input_file.txt

    ### Concatenate with seqkit
    seqkit \\
        concat \\
            --full \\
            --infile-list input_file.txt \\
            --threads ${task.cpus} \\
            --out-file ${meta.id}.fna.gz
    """
}
