process PHYNTENYTRANSFORMER_INSTALLMODELS {
    tag "phynteny_db"
    label 'process_gpu'
    container null
    conda "${moduleDir}/environment.yml"
    storeDir "${params.db_dir}/phynteny"

    output:
    path("phynteny_db/")    , emit: db

    script:
    """
    # download phynteny models
    install_models -o phynteny_db

    # install pytorch with cuda support
    micromamba install -c conda-forge pytorch=*=cuda* -y
    """
}
