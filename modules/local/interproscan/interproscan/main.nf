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
    ### Run InterProScan ###
    export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

    gunzip -c -f ${faa} > ${faa.getBaseName()}
    # replace all '*' characters to avoid InterProScan errors
    sed -i 's/*//g' ${faa.getBaseName()}

    bash ./${db}/interproscan.sh \\
        -cpu ${task.cpus} \\
        -dp \\
        --goterms \\
        --input ${faa.getBaseName()} \\
        --output-file-base ${meta.id}.interproscan

    ### Compress outputs ###
    gzip ${meta.id}.interproscan.tsv
    # TODO: Replace with pigz

    ### Cleanup ###
    rm -rf ${meta.id}.interproscan.xml ${meta.id}.interproscan.json ${meta.id}.interproscan.gff3 \\
        ${faa.getBaseName()} temp
    """
}
