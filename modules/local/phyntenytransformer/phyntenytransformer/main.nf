process PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER {
    tag "${meta.id}"
    label 'process_gpu'
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(gbk)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.phynteny.tsv.gz") , emit: tsv_gz

    script:
    """
    gunzip -f ${gbk}

    phynteny_transformer \\
        ${gbk.getBaseName()} \\
        --out ${meta.id}_phynteny \\
        --models ${db}/models

    rm -rf ${gbk.getBaseName()}

    mv ${meta.id}_phynteny/phynteny.tsv ${meta.id}.phynteny.tsv
    gzip ${meta.id}.phynteny.tsv

    rm -rf *_phynteny/
    """
}
