process GENOMAD_ENDTOEND {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/dc/dce9fcea87c93a5f667db6f56c102d21def6ba27d1370edb326f348f8b1a36fc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-2af08b3c6c2a1dc3_1?_gl=1*d9pf3r*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    input:
    tuple val(meta) , path(fasta)
    path(genomad_db)

    output:
    tuple val(meta), path("${meta.id}_virus.fna.gz")            , emit: fna_gz
    tuple val(meta), path("${meta.id}_virus_summary.tsv.gz")    , emit: summary_tsv_gz
    tuple val(meta), path("${meta.id}_virus_genes.tsv.gz")      , emit: genes_tsv_gz

    script:
    """
    ### Length filter with seqkit ###
    seqkit \\
        seq \\
        --threads ${task.cpus} \\
        --min-len ${params.classify_min_length} \\
        ${fasta} \\
        --out-file ${meta.id}_filtered.fasta.gz

    ### Run genomad ###
    genomad \\
        end-to-end \\
        ${meta.id}_filtered.fasta.gz \\
        ${meta.id}_genomad \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        ${params.classify_genomad_args}

    ### Compress outputs ###
    gzip -c ${meta.id}_genomad/*_summary/*_virus.fna > ${meta.id}_virus.fna.gz
    gzip -c ${meta.id}_genomad/*_summary/*_virus_summary.tsv > ${meta.id}_virus_summary.tsv.gz
    gzip -c ${meta.id}_genomad/*_summary/*_virus_genes.tsv > ${meta.id}_virus_genes.tsv.gz

    ### Cleanup ###
    rm -rf ${meta.id}_genomad
    """
}
