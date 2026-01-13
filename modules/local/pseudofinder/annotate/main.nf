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
    ### Decompress
    gunzip -f -c ${gbk} > ${gbk.getBaseName()}
    gunzip -f -c ${tsv} > ${tsv.getBaseName()}

    ### Extract nohit proteins
    if [ \$(wc -l < ${tsv.getBaseName()}) -gt 0 ]; then
        extract_nohit_proteins2.py \\
                --input_gbk ${gbk.getBaseName()} \\
                --input_tsv ${tsv.getBaseName()} \\
                --output ${meta.id}_nohit2.gbk
        gbk_new=${meta.id}_nohit2.gbk
    else
        gbk_new=${gbk.getBaseName()}
    fi

    ### Run pseudofinder
    python ${mod}/pseudofinder.py annotate \\
        -g \$gbk_new \\
        -db ${db} \\
        -t ${task.cpus} \\
        --diamond \\
        --sensitivity="--very-sensitive" \\
        -op ${meta.id}

    ### Compress
    mv ${meta.id}_pseudos.gff ${meta.id}.pseudofinder.gff
    gzip ${meta.id}.pseudofinder.gff

    ### Cleanup
    rm -rf ${meta.id}_pseudos* ${meta.id}_intact* ${tsv.getBaseName()} ${gbk.getBaseName()} \\
        ${meta.id}_nohit2.gbk ${meta.id}_*.fasta ${meta.id}_*.html ${meta.id}_*.tsv \\
        ${meta.id}_*.txt ${meta.id}_*.pdf ${meta.id}_*.faa 
    """
}
