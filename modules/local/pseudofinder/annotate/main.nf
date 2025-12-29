process PSEUDOFINDER_ANNOTATE {
    tag "${meta.id}"
    label "process_high"
    container 'quay.io/microbiome-informatics/pseudofinder:1.1.0'

    input:
    tuple val(meta) , path(gbk) , path(tsv)
    path(db)
    path(mod)

    output:
    tuple val(meta), path("${meta.id}.pseudofinder.gff.gz") , emit: gff_gz

    script:
    """
    gunzip -f ${gbk}
    gunzip -f ${tsv}

    # extract proteins without Bakta or Foldseek hits
    # if tsv is not empty
    if [ \$(wc -l < ${tsv.getBaseName()}) -gt 0 ]; then
        extract_nohit_proteins2.py \\
                --input_gbk ${gbk.getBaseName()} \\
                --input_tsv ${tsv.getBaseName()} \\
                --output ${meta.id}_nohit2.gbk
        gbk_new=${meta.id}_nohit2.gbk
    else
        gbk_new=${gbk.getBaseName()}
    fi

    # run pseudofiner on proteins still without hits
    python ${mod}/pseudofinder.py annotate \\
        -g \$gbk_new \\
        -db ${db} \\
        -t ${task.cpus} \\
        --diamond \\
        --sensitivity="--very-sensitive" \\
        -op ${meta.id}

    mv ${meta.id}_pseudos.gff ${meta.id}.pseudofinder.gff
    gzip ${meta.id}.pseudofinder.gff

    rm -rf ${meta.id}_pseudos* ${meta.id}_intact* ${tsv.getBaseName()} ${gbk.getBaseName()}
    """
}
