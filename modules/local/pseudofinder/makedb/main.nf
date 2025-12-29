process PSEUDOFINDER_MAKEDB {
    tag "pseudofinder_db"
    container 'quay.io/microbiome-informatics/pseudofinder:1.1.0'
    storeDir "${params.db_dir}/pseudofinder"

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
