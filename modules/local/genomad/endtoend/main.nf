process GENOMAD_ENDTOEND {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/bb/bbaadac0c5d49bb7c664d9d3651521aa638b795cdbab7eb9493ec66350508f97/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-4eb739aab45fd5c9_1?_gl=1*1w9htsp*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(fasta)
    path(genomad_db)

    output:
    tuple val(meta), path("${meta.id}_virus.fna.gz")            , emit: fna_gz
    tuple val(meta), path("${meta.id}_virus_summary.tsv.gz")    , emit: summary_tsv_gz
    tuple val(meta), path("${meta.id}_virus_genes.tsv.gz")      , emit: genes_tsv_gz

    script:
    """
    genomad \\
        end-to-end \\
        ${fasta} \\
        ${meta.id}_genomad \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        ${params.classify_genomad_args}

    # save virus outputs
    gzip -c ${meta.id}_genomad/*_summary/*_virus.fna > ${meta.id}_virus.fna.gz
    gzip -c ${meta.id}_genomad/*_summary/*_virus_summary.tsv > ${meta.id}_virus_summary.tsv.gz
    gzip -c ${meta.id}_genomad/*_summary/*_virus_genes.tsv > ${meta.id}_virus_genes.tsv.gz

    # clean output directories
    rm -rf ${meta.id}_genomad
    """
}
