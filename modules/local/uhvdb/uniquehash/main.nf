process UHVDB_UNIQUEHASH {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/91/9135081f5bb2f0326f82ec97887978bd9a7c4dec6b44fce4c15709e064b96cdc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b9f1532f49256bb0_1?_gl=1*18xqofg*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta), path(tsv_gzs)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.unique.tsv.gz")   , emit: tsv_gz
    tuple val(meta), path("${meta.id}.unique.fna.gz")   , emit: fna_gz

    script:
    """
    ### Concatenate TSVs
    for file in ${tsv_gzs}; do
        cat \${file} >> ${meta.id}.combined_seqhasher.tsv.gz
    done

    ### Identify unique hashes
    csvtk \\
        uniq \\
        ${meta.id}.combined_seqhasher.tsv.gz \\
        --no-header-row \\
        --fields 2 \\
        --num-cpus ${task.cpus} \\
        --tabs \\
        --out-file ${meta.id}.unique_hashes.tsv.gz

    ### Write out tsv
    csvtk cut \\
        ${meta.id}.unique_hashes.tsv.gz \\
        --fields 1,2 \\
        --tabs \\
        --no-header-row \\
        --out-file ${meta.id}.unique.tsv.gz

    ### Write out fasta
    csvtk cut \\
        ${meta.id}.unique_hashes.tsv.gz \\
        --fields 1,3 \\
        --tabs \\
        --no-header-row \\
        --out-file ${meta.id}.unique.seqs.tsv.gz

    seqkit tab2fx \\
        ${meta.id}.unique.seqs.tsv.gz \\
        --out-file ${meta.id}.unique.fna.gz \\
        --threads ${task.cpus}

    ### Cleanup
    rm -rf ${meta.id}.combined_seqhasher.tsv.gz ${meta.id}.unique_hashes.tsv.gz ${meta.id}.unique.seqs.tsv.gz
    """
}
