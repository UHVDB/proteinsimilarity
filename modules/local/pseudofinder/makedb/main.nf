process PSEUDOFINDER_MAKEDB {
    container 'quay.io/microbiome-informatics/pseudofinder:1.1.0'
    storeDir "${params.db_dir}/pseudofinder/${new java.util.Date().format('yyyy_MM')}"
    tag "swissprot v${new java.util.Date().format('yyyy_MM')}"

    input:
    path(fasta)

    output:
    path("*.dmnd")  , emit: dmnd

    script:
    """
    # create diamond db
    diamond \\
        makedb \\
        --in ${fasta} \\
        --db ${fasta.getBaseName()}.dmnd

    rm -rf uniprot_sprot.fasta
    """
}
