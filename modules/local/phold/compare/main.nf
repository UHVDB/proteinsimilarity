process PHOLD_COMPARE {
    tag "${meta.id}"
    label "process_super_high"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(gbk), path(predict)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.phold.gbk.gz")    , emit: gbk_gz
    tuple val(meta), path("${meta.id}.phold.tsv.gz")    , emit: tsv_gz

    script:
    """
    gunzip -f ${gbk}

    # run phold on all fasta files
    phold compare \\
        --input ${gbk.getBaseName()} \\
        --predictions_dir ${predict} \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold

    rm -rf ${gbk.getBaseName()}

    # clean intermediate files
    rm -rf ${meta.id}_phold/logs ${meta.id}_phold/sub_db_tophits \\
        ${meta.id}_phold/phold_3di.fasta ${meta.id}_phold/phold_aa.fasta \\
        ${meta.id}_phold/phold_all_cds_functions.tsv \\
        ${meta.id}_phold/phold_run*.log

    # move desired output files to appropriate location
    mv ${meta.id}_phold/phold_per_cds_predictions.tsv ${meta.id}.phold.tsv
    mv ${meta.id}_phold/phold.gbk ${meta.id}.phold.gbk

    gzip ${meta.id}.phold.tsv
    gzip ${meta.id}.phold.gbk
    """
}
