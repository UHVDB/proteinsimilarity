process INTERPROSCAN_INTERPROSCAN {
    tag "${meta.id}"
    label 'process_super_high'
    container "quay.io/microbiome-informatics/interproscan:5.74-105.0"
    containerOptions "--bind ${db}/data:/opt/interproscan/data"

    input:
    tuple val(meta) , path(faa)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.interproscan.tsv.gz") , emit: tsv_gz

    script:
    """
    # Enforce encoding to prevent errors from non-ASCII characters in FASTA headers
    export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

    gunzip -f ${faa}

    # run interproscan
    bash ./${db}/interproscan.sh \\
        -cpu ${task.cpus} \\
        -dp \\
        --goterms \\
        -pa \\
        --input ${faa.getBaseName()} \\
        --output-file-base ${meta.id}.interproscan

    gzip ${meta.id}.interproscan.tsv

    rm -rf ${meta.id}.interproscan.xml ${meta.id}.interproscan.json ${meta.id}.interproscan.gff3 ${faa.getBaseName()}
    """
}
