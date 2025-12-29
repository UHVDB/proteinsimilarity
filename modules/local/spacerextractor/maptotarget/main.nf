process SPACEREXTRACTOR_MAPTOTARGET {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/29/2900c330cd8dd25094b4cd86e4a32a576ddb340f412ac17f6715ac4136cf495c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-f4b63d63859b49f0_1?_gl=1*1gn5au*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(fna_gz)
    path(target_db)

    output:
    tuple val(meta), path("${meta.id}.spacerextractor_map.tsv.gz")  , emit: tsv_gz

    script:
    """
    ### run spacerextractor map_to_target ###
    # modified script so that upstream and downstream seqs are not retrieved
    # dramatically speeds up mapping process
    SE_map_get_hits.py \\
        map_to_target \\
            -i ${fna_gz} \\
            -d ${target_db} \\
            -o ${meta.id}_map_results \\
            -t ${task.cpus}

    ### compress output ###
    mv ${meta.id}_map_results/${meta.id}_vs_virus_targets_db_all_hits.tsv ${meta.id}.spacerextractor_map.tsv
    gzip ${meta.id}.spacerextractor_map.tsv

    ### clean up ###
    rm -rf ${meta.id}_map_results/
    """
}
