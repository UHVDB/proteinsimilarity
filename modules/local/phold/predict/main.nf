process PHOLD_PREDICT {
    tag "${meta.id}"
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(gbk)
    path(db)

    output:
    tuple val(meta), path("${meta.id}_phold_predict")   , emit: predict

    script:
    """
    gunzip -f ${gbk}
    # run phold on all fasta files
    phold predict \\
        --input ${gbk.getBaseName()} \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold_predict \\
        --hyps
    
    rm -rf ${gbk.getBaseName()}
    """
}
